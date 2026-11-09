import Foundation

// 读 agents/ 目录，以及把 icu-hook 装进 / 卸出 ~/.claude/settings.json（全在临时目录里）

private func scratchDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("icu-agent-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeJSON(_ object: Any, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: object).write(to: url)
}

// MARK: - 读目录

func testAgentDirectoryReaderLoadsSessionsAndForgetsLeftovers() throws {
    let directory = try scratchDirectory()
    try writeJSON(["v": 1, "session": "live", "event": "PermissionRequest", "at": 1_000.0], to: directory.appendingPathComponent("live.json"))
    try writeJSON(["v": 1, "session": "old", "event": "UserPromptSubmit", "at": 1_000.0 - AgentDirectoryReader.forgetAfter - 1], to: directory.appendingPathComponent("old.json"))
    try Data("{broken".utf8).write(to: directory.appendingPathComponent("broken.json"))
    try Data("ignore me".utf8).write(to: directory.appendingPathComponent("notes.txt"))

    let sessions = AgentDirectoryReader(directory: directory).readSessions(now: 1_000)
    try expect(sessions.map(\.id) == ["live"], "only the live session is read (got \(sessions.map(\.id)))")
    try expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("old.json").path), "a session silent for a day (crashed, never ended) is cleaned up")
    try expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("broken.json").path), "unreadable files are skipped, not deleted (the hook may be mid-write)")

    let missing = AgentDirectoryReader(directory: directory.appendingPathComponent("nope")).readSessions(now: 0)
    try expect(missing.isEmpty, "no agents directory yet means no sessions")
}

// MARK: - 安装钩子

private struct InstallerFixture {
    let root: URL
    let settings: URL
    let binary: URL
    let installer: ClaudeHookInstaller

    init() throws {
        root = try scratchDirectory()
        settings = root.appendingPathComponent("claude/settings.json")
        binary = root.appendingPathComponent("build/icu-hook")
        try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: binary)
        installer = ClaudeHookInstaller(settingsURL: settings, appPaths: AppPaths(rootURL: root.appendingPathComponent("ICU")))
    }

    func settingsObject() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any] ?? [:]
    }

    func entries(_ event: String) throws -> [[String: Any]] {
        let hooks = try settingsObject()["hooks"] as? [String: Any]
        return hooks?[event] as? [[String: Any]] ?? []
    }

    func commands(_ event: String) throws -> [String] {
        try entries(event).flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
    }
}

private let userHook: [String: Any] = ["matcher": "Bash", "hooks": [["type": "command", "command": "~/bin/my-own-hook.sh"]]]

func testClaudeHookInstallerAddsItsHookWithoutTouchingYours() throws {
    let fixture = try InstallerFixture()
    try writeJSON(["model": "opus", "hooks": ["PreToolUse": [userHook]]], to: fixture.settings)

    try expect(!fixture.installer.isInstalled, "not installed yet")
    try fixture.installer.install(hookBinary: fixture.binary, now: Date(timeIntervalSince1970: 0))
    try expect(fixture.installer.isInstalled, "installed")

    let settings = try fixture.settingsObject()
    try expect(settings["model"] as? String == "opus", "other settings are kept")
    let preToolCommands = try fixture.commands("PreToolUse")
    try expect(preToolCommands.contains("~/bin/my-own-hook.sh"), "your own hooks are kept")
    for event in ClaudeHookInstaller.events {
        let ours = try fixture.entries(event).flatMap { $0["hooks"] as? [[String: Any]] ?? [] }.filter { ($0["command"] as? String)?.contains("icu-hook") == true }
        try expect(ours.count == 1, "\(event) gets exactly one icu-hook entry")
        try expect(ours.first?["async"] as? Bool == true, "\(event): runs in the background so Claude never waits for the pet")
    }
    let installed = fixture.installer.installedHookURL
    try expect(FileManager.default.isExecutableFile(atPath: installed.path), "the hook binary is copied somewhere stable and executable")
    try expect(fixture.installer.command.hasPrefix("'") && fixture.installer.command.contains("Application Support") == installed.path.contains("Application Support"), "the command quotes the path (Application Support has a space)")

    let backups = try FileManager.default.contentsOfDirectory(atPath: fixture.settings.deletingLastPathComponent().path).filter { $0.hasPrefix("settings.json.icu-backup") }
    try expect(backups.count == 1, "the original settings are backed up first (got \(backups))")
}

func testClaudeHookInstallerIsIdempotentAndUninstallsOnlyItsOwn() throws {
    let fixture = try InstallerFixture()
    try writeJSON(["hooks": ["PreToolUse": [userHook]]], to: fixture.settings)
    try fixture.installer.install(hookBinary: fixture.binary, now: Date(timeIntervalSince1970: 0))
    try fixture.installer.install(hookBinary: fixture.binary, now: Date(timeIntervalSince1970: 60))
    let afterTwice = try fixture.commands("Stop")
    try expect(afterTwice.count == 1, "installing twice does not duplicate hooks (got \(afterTwice))")

    try fixture.installer.uninstall(now: Date(timeIntervalSince1970: 120))
    try expect(!fixture.installer.isInstalled, "uninstalled")
    let preToolCommands = try fixture.commands("PreToolUse")
    try expect(preToolCommands == ["~/bin/my-own-hook.sh"], "only icu-hook entries are removed (got \(preToolCommands))")
    let hooks = try fixture.settingsObject()["hooks"] as? [String: Any]
    try expect(hooks?["Stop"] == nil, "events left empty are removed instead of leaving [] behind")
}

func testClaudeHookInstallerCreatesSettingsAndRefusesBrokenOnes() throws {
    let fresh = try InstallerFixture()
    try fresh.installer.install(hookBinary: fresh.binary, now: Date())
    try expect(fresh.installer.isInstalled, "no settings.json yet: it is created")

    let broken = try InstallerFixture()
    try FileManager.default.createDirectory(at: broken.settings.deletingLastPathComponent(), withIntermediateDirectories: true)
    let original = Data("{ \"hooks\": // a comment Claude Code may not like\n }".utf8)
    try original.write(to: broken.settings)
    var refused = false
    do {
        try broken.installer.install(hookBinary: broken.binary, now: Date())
    } catch let error as ClaudeHookInstallerError {
        refused = true
        try expect(!error.userMessage.isEmpty, "the refusal explains itself")
    }
    try expect(refused, "a settings file we cannot parse is left alone")
    let after = try Data(contentsOf: broken.settings)
    try expect(after == original, "…byte for byte")
}

/// app 更新后，已经接上的钩子换成新版 icu-hook（设置文件不动）
func testClaudeHookInstallerRefreshesTheHookBinaryOnly() throws {
    let fixture = try InstallerFixture()
    try fixture.installer.install(hookBinary: fixture.binary, now: Date(timeIntervalSince1970: 0))
    let settingsBefore = try Data(contentsOf: fixture.settings)
    try Data("#!/bin/sh\necho new\nexit 0\n".utf8).write(to: fixture.binary)

    let refreshed = try fixture.installer.refreshHookBinary(from: fixture.binary)
    try expect(refreshed, "a changed binary is copied over")
    let installedData = try Data(contentsOf: fixture.installer.installedHookURL)
    let bundledData = try Data(contentsOf: fixture.binary)
    try expect(installedData == bundledData, "the installed hook is the new one")
    try expect(FileManager.default.isExecutableFile(atPath: fixture.installer.installedHookURL.path), "still executable")
    let settingsAfter = try Data(contentsOf: fixture.settings)
    try expect(settingsAfter == settingsBefore, "settings.json is not touched")
    let again = try fixture.installer.refreshHookBinary(from: fixture.binary)
    try expect(!again, "nothing to do when it is already current")

    let notInstalled = try InstallerFixture()
    let refreshedWithoutInstall = try notInstalled.installer.refreshHookBinary(from: notInstalled.binary)
    try expect(!refreshedWithoutInstall, "not connected: never installs on its own")
    try expect(!FileManager.default.fileExists(atPath: notInstalled.installer.installedHookURL.path), "…and copies nothing")
}

// MARK: - 监视器

@MainActor
func testAgentStatusMonitorReportsChangesAndBacksOffWhenYouAreThere() throws {
    let directory = try scratchDirectory()
    try writeJSON(["v": 1, "session": "s1", "event": "PermissionRequest", "tool": "Bash", "app": "io.appmakes.otty", "at": 1_000.0],
                  to: directory.appendingPathComponent("s1.json"))
    var frontmost: String? = "com.apple.Safari"
    var reported: [AgentSummary.Kind] = []
    let monitor = AgentStatusMonitor(
        reader: AgentDirectoryReader(directory: directory),
        now: { 1_010 },
        frontmostBundleID: { frontmost },
        startsWatching: false
    )
    monitor.onChange = { reported.append($0.kind) }

    monitor.reload()
    try expect(monitor.summary.kind == .waiting, "a permission request in a terminal you are not looking at needs you")
    monitor.reload()
    try expect(reported == [.waiting], "only changes are reported (got \(reported))")

    monitor.applicationActivated(bundleID: "io.appmakes.otty")
    try expect(monitor.summary.kind == .working, "once you switch to that terminal it is in your hands")
    try expect(reported == [.waiting, .working], "the hand-over is reported (got \(reported))")

    frontmost = "io.appmakes.otty"
    let watching = AgentStatusMonitor(reader: AgentDirectoryReader(directory: directory), now: { 1_010 }, frontmostBundleID: { frontmost }, startsWatching: false)
    watching.reload()
    try expect(watching.summary.kind == .working, "if you are already in that terminal you can see the prompt; no need to nag")
}
