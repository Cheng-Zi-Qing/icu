import Foundation

/// Claude Code 钩子发来的一次事件，只留桌宠要用的状态。
///
/// 不存对话内容：提示词、命令、工具参数、回答、对话记录路径一律不留；
/// 工作目录只留最后一段（项目文件夹名），用来在卡片上说「哪个项目在等你」。
struct AgentHookEvent: Equatable {
    static let schemaVersion = 1
    static let source = "claude"

    /// 装钩子时注册的事件；其他事件即使发来也不记
    static let trackedEvents: Set<String> = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "PermissionRequest", "Notification", "Stop", "StopFailure", "SessionEnd",
    ]

    /// 会改变桌宠表现的通知；登录成功、插件通知这类不记，免得盖掉「干完了」
    static let trackedNotifications: Set<String> = [
        "permission_prompt", "idle_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input",
    ]

    static let maxSessionIDLength = 128
    static let maxLabelLength = 64

    let sessionID: String
    let event: String
    /// Notification 的类型（permission_prompt、idle_prompt……）
    let kind: String?
    /// PermissionRequest 和 PreToolUse 留工具名（卡片上写「想用 Bash」、桌宠选小场景），不留参数
    let tool: String?
    /// StopFailure 的错误类型（rate_limit、overloaded……）
    let error: String?
    let project: String?
    /// 会话所在的 app（终端 / IDE），用来「跳过去」
    let appBundleID: String?
    let terminal: String?
    let at: TimeInterval

    init?(stdin: Data, environment: [String: String], now: Date) {
        guard
            let root = (try? JSONSerialization.jsonObject(with: stdin)) as? [String: Any],
            let session = root["session_id"] as? String,
            Self.isSafeSessionID(session),
            let event = root["hook_event_name"] as? String,
            Self.trackedEvents.contains(event)
        else {
            return nil
        }
        let kind = Self.label(root["notification_type"])
        if event == "Notification", !kind.map(Self.trackedNotifications.contains).orFalse {
            return nil
        }
        sessionID = session
        self.event = event
        self.kind = kind
        // 要权限时记是哪个工具；调用工具时记工具名，桌宠据此演翻书 / 吃饭等小场景。只记名字，不记参数
        tool = ["PermissionRequest", "PreToolUse"].contains(event) ? Self.label(root["tool_name"]) : nil
        error = event == "StopFailure" ? Self.label(root["error"]) : nil
        project = Self.label((root["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent })
        appBundleID = Self.label(environment["__CFBundleIdentifier"])
        terminal = Self.label(environment["TERM_PROGRAM"])
        at = now.timeIntervalSince1970
    }

    var isSessionEnd: Bool { event == "SessionEnd" }

    var fileName: String { "\(sessionID).json" }

    var jsonObject: [String: Any] {
        let optional: [String: String?] = [
            "kind": kind, "tool": tool, "error": error, "project": project, "app": appBundleID, "term": terminal,
        ]
        return optional.compactMapValues { $0 }.merging([
            "v": Self.schemaVersion,
            "source": Self.source,
            "session": sessionID,
            "event": event,
            "at": at,
        ] as [String: Any]) { _, new in new }
    }

    /// 会话 ID 拿来当文件名：只认字母数字和 - _，防止路径穿越
    static func isSafeSessionID(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= maxSessionIDLength
            && value.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_" }
    }

    private static func label(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return String(text.prefix(maxLabelLength))
    }
}

private extension Optional where Wrapped == Bool {
    var orFalse: Bool { self ?? false }
}

/// 把事件落到 `agents/<会话>.json`：一个会话一个文件，只存最新状态
enum AgentHookWriter {
    static func apply(_ event: AgentHookEvent, in directory: URL, fileManager: FileManager = .default) throws {
        let url = directory.appendingPathComponent(event.fileName, isDirectory: false)
        if event.isSessionEnd {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return
        }
        // 钩子在后台跑，可能乱序到达：已有的记录更新就不覆盖
        if let existing = existingTime(at: url), existing > event.at {
            return
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let data = try JSONSerialization.data(withJSONObject: event.jsonObject, options: [.sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private static func existingTime(at url: URL) -> TimeInterval? {
        guard
            let data = try? Data(contentsOf: url),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return nil
        }
        return object["at"] as? TimeInterval
    }
}
