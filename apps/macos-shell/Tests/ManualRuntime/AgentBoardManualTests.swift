import Foundation

// 桌宠这边：把 agents/*.json 理解成「在干活 / 在等你 / 干完了 / 出错了」，多个会话合成一个

private func record(
    _ event: String,
    session: String = "s1",
    at: TimeInterval = 1_000,
    kind: String? = nil,
    tool: String? = nil,
    error: String? = nil,
    app: String? = "com.googlecode.iterm2"
) -> [String: Any] {
    let optional: [String: Any?] = ["kind": kind, "tool": tool, "error": error, "app": app, "project": "icu"]
    return optional.compactMapValues { $0 }.merging(
        ["v": 1, "source": "claude", "session": session, "event": event, "at": at] as [String: Any]
    ) { _, new in new }
}

private func session(_ event: String, session id: String = "s1", at: TimeInterval = 1_000, kind: String? = nil, tool: String? = nil, error: String? = nil, app: String? = "com.googlecode.iterm2") throws -> AgentSession {
    guard let parsed = AgentSession(record: record(event, session: id, at: at, kind: kind, tool: tool, error: error, app: app)) else {
        throw TestFailure(message: "\(event) should parse")
    }
    return parsed
}

func testAgentSessionMapsHookEventsToWhatThePetShows() throws {
    let cases: [(String, String?, AgentPhase)] = [
        ("SessionStart", nil, .idle),
        ("UserPromptSubmit", nil, .working),
        ("PreToolUse", nil, .working),
        ("PostToolUse", nil, .working),
        ("PostToolUseFailure", nil, .working),
        ("PermissionRequest", nil, .waiting(.permission(tool: "Bash"))),
        ("Notification", "permission_prompt", .waiting(.permission(tool: nil))),
        ("Notification", "elicitation_dialog", .waiting(.question)),
        ("Notification", "agent_needs_input", .waiting(.question)),
        ("Notification", "idle_prompt", .done),
        ("Stop", nil, .done),
        ("StopFailure", nil, .failed(reason: "rate_limit")),
    ]
    for (event, kind, expected) in cases {
        let parsed = try session(event, kind: kind, tool: event == "PermissionRequest" ? "Bash" : nil, error: event == "StopFailure" ? "rate_limit" : nil)
        try expect(parsed.phase == expected, "\(event)/\(kind ?? "-") should mean \(expected) (got \(parsed.phase))")
    }
    let running = try session("PreToolUse")
    let finished = try session("PostToolUse")
    try expect(running.isInTool, "a tool is running between PreToolUse and PostToolUse")
    try expect(!finished.isInTool, "the tool finished")
}

func testAgentSessionRejectsRecordsItDoesNotUnderstand() throws {
    try expect(AgentSession(record: "nope") == nil, "not an object")
    try expect(AgentSession(record: ["event": "Stop", "at": 1.0]) == nil, "no session id")
    try expect(AgentSession(record: record("MessageDisplay")) == nil, "unknown event")
    try expect(AgentSession(record: record("Notification", kind: "auth_success")) == nil, "notification that does not change state")
    var future = record("Stop")
    future["v"] = 99
    try expect(AgentSession(record: future) == nil, "a newer record format is ignored rather than misread")
}

func testAgentSessionRoundTripsWhatTheHookWrites() throws {
    let stdin = try JSONSerialization.data(withJSONObject: [
        "session_id": "abc", "hook_event_name": "PermissionRequest", "tool_name": "Edit", "cwd": "/tmp/demo",
    ])
    guard let event = AgentHookEvent(stdin: stdin, environment: ["__CFBundleIdentifier": "io.appmakes.otty"], now: Date(timeIntervalSince1970: 5)) else {
        throw TestFailure(message: "hook should accept the event")
    }
    let parsed = AgentSession(record: event.jsonObject)
    try expect(parsed?.phase == .waiting(.permission(tool: "Edit")), "the pet reads exactly what the hook wrote (got \(String(describing: parsed?.phase)))")
    try expect(parsed?.project == "demo" && parsed?.appBundleID == "io.appmakes.otty" && parsed?.updatedAt == 5, "project, app and time survive the trip")
}

func testAgentBoardLetsStaleSessionsFallBackToIdle() throws {
    let board = AgentBoard(sessions: [
        try session("UserPromptSubmit", session: "thinking", at: 0),
        try session("PreToolUse", session: "building", at: 0),
        try session("Stop", session: "finished", at: 0),
        try session("PermissionRequest", session: "asking", at: 0),
    ])
    let phase = { (id: String, now: TimeInterval) in board.sessions.first { $0.id == id }!.effectivePhase(at: now, acknowledged: false) }
    try expect(phase("thinking", AgentBoard.workingTimeout - 1) == .working, "still thinking within the timeout")
    try expect(phase("thinking", AgentBoard.workingTimeout + 1) == .idle, "Esc fires no event, so silence means it stopped")
    try expect(phase("building", AgentBoard.workingTimeout + 1) == .working, "a long tool run (a build) gets more time")
    try expect(phase("building", AgentBoard.toolTimeout + 1) == .idle, "…but not forever")
    try expect(phase("finished", AgentBoard.settledTimeout + 1) == .idle, "done fades back to idle")
    try expect(phase("asking", 3_600) == .waiting(.permission(tool: nil)), "a question keeps waiting while you are away")
}

func testAgentBoardShowsTheSessionThatNeedsYouMost() throws {
    let board = AgentBoard(sessions: [
        try session("UserPromptSubmit", session: "a", at: 100),
        try session("Stop", session: "b", at: 110),
        try session("PermissionRequest", session: "c", at: 120, tool: "Bash"),
        try session("Notification", session: "d", at: 130, kind: "elicitation_dialog"),
        try session("StopFailure", session: "e", at: 125, error: "overloaded"),
    ])
    let summary = board.summary(at: 140)
    try expect(summary.kind == .waiting && summary.count == 2, "two sessions wait for you (got \(summary.kind) × \(summary.count))")
    try expect(summary.lead?.id == "d", "the most recent one that waits leads, for the card and jumping back")

    let calm = AgentBoard(sessions: [try session("UserPromptSubmit", session: "a", at: 100), try session("Stop", session: "b", at: 110)])
    try expect(calm.summary(at: 140).kind == .done, "done outranks still working")
    try expect(AgentBoard(sessions: []).summary(at: 0) == .idle, "no sessions, plain idle")
}

func testAgentBoardStopsNaggingOnceYouGoBackToThatTerminal() throws {
    let waiting = AgentBoard(sessions: [
        try session("PermissionRequest", session: "c", at: 120, app: "io.appmakes.otty"),
        try session("PermissionRequest", session: "x", at: 121, app: "com.microsoft.VSCode"),
    ])
    let seen = waiting.acknowledging(appBundleID: "io.appmakes.otty")
    try expect(seen.summary(at: 130).count == 1, "the one in the terminal you switched to is in your hands now")
    try expect(waiting.summary(at: 130).count == 2, "acknowledging returns a new board")

    let askedAgain = seen.replacing(sessions: [
        try session("PermissionRequest", session: "c", at: 200, app: "io.appmakes.otty"),
        try session("PermissionRequest", session: "x", at: 121, app: "com.microsoft.VSCode"),
    ])
    try expect(askedAgain.summary(at: 210).count == 2, "a new question from the same session needs you again")
}

/// 「干完了」「出错了」是提醒：你回到那个终端（或者本来就在那里）就算提醒到了，直接消失
func testAgentBoardDropsFinishedSessionsOnceYouHaveSeenThem() throws {
    let board = AgentBoard(sessions: [
        try session("Stop", session: "done", at: 120, app: "io.appmakes.otty"),
        try session("StopFailure", session: "broke", at: 121, error: "rate_limit", app: "io.appmakes.otty"),
        try session("Stop", session: "elsewhere", at: 122, app: "com.microsoft.VSCode"),
    ])
    try expect(board.summary(at: 130).kind == .failed, "before you look, the error stands out")

    let seen = board.acknowledging(appBundleID: "io.appmakes.otty")
    let summary = seen.summary(at: 130)
    try expect(summary.kind == .done && summary.count == 1 && summary.lead?.id == "elsewhere", "what you saw in Otty is gone; the VS Code one still reminds you (got \(summary.kind) × \(summary.count))")
    try expect(seen.acknowledging(appBundleID: "com.microsoft.VSCode").summary(at: 130) == .idle, "once every reminder is seen the pet goes back to normal")

    let workingAgain = seen.replacing(sessions: [try session("UserPromptSubmit", session: "done", at: 140, app: "io.appmakes.otty")])
    try expect(workingAgain.summary(at: 150).kind == .working, "the next turn of the same session shows again")
}

func testAgentSummaryStatusText() throws {
    let one = try session("PermissionRequest")
    try expect(AgentSummary(kind: .waiting, count: 1, lead: one).statusText == "在等你", "single waiting")
    try expect(AgentSummary(kind: .waiting, count: 3, lead: one).statusText == "3 个在等你", "several waiting show a count")
    let reading = AgentSession(record: ["v": 1, "session": "r", "event": "PreToolUse", "tool": "Read", "at": 1.0])
    try expect(AgentSummary(kind: .working, count: 2, lead: reading).statusText == "读取中", "working says what it is doing, no count")
    try expect(AgentSummary(kind: .working, count: 1, lead: nil).statusText == "思考中", "working without a tool is thinking")
    try expect(AgentSummary(kind: .done, count: 1, lead: one).statusText == "干完了", "done")
    try expect(AgentSummary(kind: .failed, count: 1, lead: one).statusText == "出错了", "failed")
    try expect(AgentSummary.idle.statusText == nil, "idle leaves the normal status alone")
}
