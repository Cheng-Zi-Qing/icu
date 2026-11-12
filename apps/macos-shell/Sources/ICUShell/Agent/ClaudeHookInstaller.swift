import Foundation

enum ClaudeHookInstallerError: Error, Equatable {
    /// settings.json 不是我们读得懂的 JSON（比如带注释）：不去碰它
    case unreadableSettings
    case missingHookBinary

    var userMessage: String {
        switch self {
        case .unreadableSettings:
            return TextCatalog.shared.text("errors.claude_settings_unreadable")
        case .missingHookBinary:
            return TextCatalog.shared.text("errors.claude_hook_missing")
        }
    }
}

/// 把 icu-hook 装进 / 卸出 Claude Code 的 `~/.claude/settings.json`。
///
/// - 先把 icu-hook 拷到 `<App Support>/ICU/bin/`（app 挪了位置也不会失效）
/// - 改设置前先备份；你自己的钩子和其他设置原样保留
/// - 每个事件只加一条，全部 `async`：在后台跑，Claude 不用等桌宠
/// - 卸载只删命令里带 `/bin/icu-hook` 的条目
struct ClaudeHookInstaller {
    static let events = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "PermissionRequest", "Notification", "Stop", "StopFailure", "SessionEnd",
    ]
    static let marker = "/bin/icu-hook"
    static let hookTimeoutSeconds = 10

    let settingsURL: URL
    let installedHookURL: URL

    init(settingsURL: URL, appPaths: AppPaths) {
        self.settingsURL = settingsURL
        installedHookURL = appPaths.rootURL.appendingPathComponent("bin/icu-hook", isDirectory: false)
    }

    /// 真实的 Claude Code 设置文件（尊重 CLAUDE_CONFIG_DIR）
    static func live(appPaths: AppPaths, environment: [String: String] = ProcessInfo.processInfo.environment) -> ClaudeHookInstaller {
        let configDirectory = environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude", isDirectory: true)
        return ClaudeHookInstaller(settingsURL: configDirectory.appendingPathComponent("settings.json"), appPaths: appPaths)
    }

    /// 和 app 本体放在一起的 icu-hook（.build/debug 或 .app/Contents/MacOS）
    static var bundledHookBinary: URL? {
        Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("icu-hook", isDirectory: false)
    }

    /// 钩子命令：路径加引号（Application Support 中间有空格）
    var command: String {
        "'\(installedHookURL.path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var isInstalled: Bool {
        guard let settings = try? readSettings(), let hooks = settings["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { entries in
            (entries as? [[String: Any]] ?? []).contains(where: Self.isOurs)
        }
    }

    func install(hookBinary: URL, now: Date) throws {
        let settings = try readSettings()
        guard FileManager.default.fileExists(atPath: hookBinary.path) else { throw ClaudeHookInstallerError.missingHookBinary }
        try copyHookBinary(from: hookBinary)
        try FileManager.default.createDirectory(
            at: installedHookURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("agents", isDirectory: true),
            withIntermediateDirectories: true
        )
        try write(Self.adding(command: command, to: settings), backupAt: now)
    }

    /// 已经接上时，把装好的 icu-hook 换成 app 自带的新版（app 更新后用）；不碰设置文件。
    /// - Returns: 真的换了返回 true；没接上、或者已经是新版返回 false
    @discardableResult
    func refreshHookBinary(from hookBinary: URL) throws -> Bool {
        guard isInstalled, FileManager.default.fileExists(atPath: hookBinary.path) else { return false }
        let installed = try? Data(contentsOf: installedHookURL)
        guard try installed != Data(contentsOf: hookBinary) else { return false }
        try copyHookBinary(from: hookBinary)
        return true
    }

    func uninstall(now: Date) throws {
        let settings = try readSettings()
        guard isInstalled else { return }
        try write(Self.removingOurs(from: settings), backupAt: now)
    }

    // MARK: - 纯函数：合并 / 删除

    static func adding(command: String, to settings: [String: Any]) -> [String: Any] {
        let cleaned = removingOurs(from: settings)
        let hooks = cleaned["hooks"] as? [String: Any] ?? [:]
        let entry: [String: Any] = [
            "hooks": [["type": "command", "command": command, "async": true, "timeout": hookTimeoutSeconds]],
        ]
        let added = events.reduce(into: hooks) { result, event in
            result[event] = (result[event] as? [[String: Any]] ?? []) + [entry]
        }
        return cleaned.merging(["hooks": added]) { _, new in new }
    }

    static func removingOurs(from settings: [String: Any]) -> [String: Any] {
        guard let hooks = settings["hooks"] as? [String: Any] else { return settings }
        let kept = hooks.reduce(into: [String: Any]()) { result, item in
            guard let entries = item.value as? [[String: Any]] else {
                result[item.key] = item.value
                return
            }
            let remaining = entries.filter { !isOurs($0) }
            if !remaining.isEmpty { result[item.key] = remaining }
        }
        var next = settings
        next["hooks"] = kept.isEmpty ? nil : kept
        return next
    }

    private static func isOurs(_ entry: [String: Any]) -> Bool {
        (entry["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
    }

    // MARK: - 文件

    private func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        guard
            let data = try? Data(contentsOf: settingsURL),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            object["hooks"] == nil || object["hooks"] is [String: Any]
        else {
            throw ClaudeHookInstallerError.unreadableSettings
        }
        return object
    }

    private func write(_ settings: [String: Any], backupAt now: Date) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: settingsURL.path) {
            let backup = settingsURL.deletingLastPathComponent().appendingPathComponent("settings.json.icu-backup-\(Self.stamp(now))")
            if !fileManager.fileExists(atPath: backup.path) {
                try fileManager.copyItem(at: settingsURL, to: backup)
            }
        }
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: settingsURL, options: .atomic)
    }

    private func copyHookBinary(from source: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: installedHookURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: installedHookURL.path) {
            try fileManager.removeItem(at: installedHookURL)
        }
        try fileManager.copyItem(at: source, to: installedHookURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedHookURL.path)
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
