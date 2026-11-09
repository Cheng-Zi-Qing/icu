import Foundation

// icu-hook：Claude Code 钩子事件 → agents/<会话>.json。只留状态，不留对话内容

private let hookSession = "6f1c2b9e-3d4a-4b8e-9c1d-2a7f5e0b8c31"

private func hookStdin(_ fields: [String: Any]) throws -> Data {
    let base: [String: Any] = [
        "session_id": hookSession,
        "transcript_path": "/Users/someone/.claude/projects/x/\(hookSession).jsonl",
        "cwd": "/Users/someone/Workspace/icu",
        "permission_mode": "default",
    ]
    return try JSONSerialization.data(withJSONObject: base.merging(fields) { _, new in new })
}

private let terminalEnv = ["__CFBundleIdentifier": "com.googlecode.iterm2", "TERM_PROGRAM": "iTerm.app"]

func testAgentHookKeepsOnlyStatusFields() throws {
    let stdin = try hookStdin([
        "hook_event_name": "PermissionRequest",
        "tool_name": "Bash",
        "tool_input": ["command": "rm -rf ~/secret-project"],
        "prompt": "please refactor my secret thing",
    ])
    guard let event = AgentHookEvent(stdin: stdin, environment: terminalEnv, now: Date(timeIntervalSince1970: 100)) else {
        throw TestFailure(message: "a permission request should be recorded")
    }
    try expect(event.event == "PermissionRequest" && event.tool == "Bash", "keeps the event and which tool wants permission")
    try expect(event.project == "icu", "keeps only the project folder name (got \(String(describing: event.project)))")
    try expect(event.appBundleID == "com.googlecode.iterm2" && event.terminal == "iTerm.app", "remembers which terminal to jump back to")
    try expect(event.at == 100, "stamps the time")

    let written = String(decoding: try JSONSerialization.data(withJSONObject: event.jsonObject), as: UTF8.self)
    for leaked in ["rm -rf", "secret", "transcript", "/Users/someone", "refactor"] {
        try expect(!written.contains(leaked), "the record must not carry conversation content or paths (found \(leaked) in \(written))")
    }
}

func testAgentHookRecordsWhatEachEventNeeds() throws {
    // 工具名决定水豚演哪个小场景（翻书、吃饭……）；只记名字，不记参数
    let tool = AgentHookEvent(stdin: try hookStdin(["hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": ["command": "ls"]]), environment: [:], now: Date())
    try expect(tool?.tool == "Bash", "a tool call keeps the tool name (got \(String(describing: tool?.tool)))")
    let finished = AgentHookEvent(stdin: try hookStdin(["hook_event_name": "PostToolUse", "tool_name": "Bash"]), environment: [:], now: Date())
    try expect(finished?.tool == nil, "a finished tool is no longer what it is doing")

    let note = AgentHookEvent(stdin: try hookStdin(["hook_event_name": "Notification", "notification_type": "idle_prompt", "message": "Claude is waiting"]), environment: [:], now: Date())
    try expect(note?.kind == "idle_prompt", "notifications keep their type (got \(String(describing: note?.kind)))")

    let failure = AgentHookEvent(stdin: try hookStdin(["hook_event_name": "StopFailure", "error": "rate_limit", "last_assistant_message": "half an answer"]), environment: [:], now: Date())
    try expect(failure?.error == "rate_limit", "API failures keep the error type")
}

func testAgentHookIgnoresWhatItCannotTrustOrDoesNotTrack() throws {
    try expect(AgentHookEvent(stdin: Data("not json".utf8), environment: [:], now: Date()) == nil, "garbage stdin is ignored")
    let untracked = try hookStdin(["hook_event_name": "MessageDisplay"])
    try expect(AgentHookEvent(stdin: untracked, environment: [:], now: Date()) == nil, "untracked events are ignored")
    for bad in ["../../etc/passwd", "", "a/b", String(repeating: "x", count: 300)] {
        let stdin = try JSONSerialization.data(withJSONObject: ["session_id": bad, "hook_event_name": "Stop"])
        try expect(AgentHookEvent(stdin: stdin, environment: [:], now: Date()) == nil, "unsafe session id \(bad.prefix(20)) is rejected")
    }
}

private func makeAgentsDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("agents")
    return url
}

private func readRecord(_ directory: URL) throws -> [String: Any]? {
    let url = directory.appendingPathComponent("\(hookSession).json")
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
}

func testAgentHookWriterWritesTheSessionAndRemovesItAtTheEnd() throws {
    let directory = try makeAgentsDirectory()
    let start = try hookStdin(["hook_event_name": "UserPromptSubmit", "prompt": "hi"])
    try AgentHookWriter.apply(AgentHookEvent(stdin: start, environment: [:], now: Date(timeIntervalSince1970: 10))!, in: directory)
    let started = try readRecord(directory)
    try expect(started?["event"] as? String == "UserPromptSubmit", "the session file holds the latest event")
    try expect(started?["source"] as? String == "claude", "records say which agent they came from")

    let end = try hookStdin(["hook_event_name": "SessionEnd", "reason": "prompt_input_exit"])
    try AgentHookWriter.apply(AgentHookEvent(stdin: end, environment: [:], now: Date(timeIntervalSince1970: 20))!, in: directory)
    let ended = try readRecord(directory)
    try expect(ended == nil, "ending the session removes its file")
}

func testAgentHookWriterNeverOverwritesANewerEvent() throws {
    let directory = try makeAgentsDirectory()
    let newer = try hookStdin(["hook_event_name": "Stop"])
    let older = try hookStdin(["hook_event_name": "PostToolUse", "tool_name": "Read"])
    try AgentHookWriter.apply(AgentHookEvent(stdin: newer, environment: [:], now: Date(timeIntervalSince1970: 50))!, in: directory)
    try AgentHookWriter.apply(AgentHookEvent(stdin: older, environment: [:], now: Date(timeIntervalSince1970: 40))!, in: directory)
    let kept = try readRecord(directory)
    try expect(kept?["event"] as? String == "Stop", "hooks run in the background and can land out of order; the newer one wins")
}

func testAgentHookOnlyKeepsNotificationsThatChangeTheState() throws {
    for kind in ["permission_prompt", "idle_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input"] {
        let stdin = try hookStdin(["hook_event_name": "Notification", "notification_type": kind])
        try expect(AgentHookEvent(stdin: stdin, environment: [:], now: Date())?.kind == kind, "\(kind) changes what the pet shows")
    }
    for kind in ["auth_success", "plugin_notification", "quota_auto_resume_fired"] {
        let stdin = try hookStdin(["hook_event_name": "Notification", "notification_type": kind])
        try expect(AgentHookEvent(stdin: stdin, environment: [:], now: Date()) == nil, "\(kind) must not overwrite the session state")
    }
}
