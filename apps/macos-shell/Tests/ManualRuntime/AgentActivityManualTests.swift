import Foundation

// Agent 在干哪种活（读文件、搜索、改代码……），水豚就演对应的小场景；换场景至少隔 3 秒，免得一秒闪好几下

func testAgentActivityFollowsTheTool() throws {
    let cases: [(String?, AgentActivity)] = [
        ("Read", .read), ("WebFetch", .read),
        ("Grep", .search), ("Glob", .search), ("WebSearch", .search),
        ("Edit", .write), ("Write", .write), ("MultiEdit", .write), ("NotebookEdit", .write),
        ("Bash", .eat), ("BashOutput", .eat),
        ("Task", .delegate), ("Agent", .delegate),
        ("mcp__github__search_issues", .search), ("mcp__notion__fetch_page", .read), ("mcp__notion__update_page", .write),
        ("TodoWrite", .think), ("Skill", .think), (nil, .think),
    ]
    for (tool, expected) in cases {
        try expect(AgentActivity(tool: tool) == expected, "\(tool ?? "no tool") should be \(expected) (got \(AgentActivity(tool: tool)))")
    }
}

private func record(_ event: String, tool: String? = nil, at: TimeInterval = 100, session: String = "s1") -> [String: Any] {
    var fields: [String: Any] = ["v": 1, "session": session, "event": event, "at": at]
    fields["tool"] = tool
    return fields
}

/// 状态条上的字和 Claude Code 终端里显示的工具名对得上（Read、Search、Update、Write、Bash、Fetch、Web Search…）
func testAgentStatusTextMatchesWhatClaudeCodeShows() throws {
    let byTool: [String: String] = [
        "Read": "读取中", "Grep": "搜索中", "Glob": "搜索中", "LS": "搜索中",
        "Edit": "更新中", "MultiEdit": "更新中", "NotebookEdit": "更新中", "Write": "写入中",
        "Bash": "运行 Bash", "BashOutput": "运行 Bash", "KillShell": "运行 Bash",
        "WebFetch": "抓取网页中", "WebSearch": "网页搜索中", "Task": "子 Agent 运行中", "Agent": "子 Agent 运行中",
    ]
    for (tool, text) in byTool {
        try expect(AgentActivity.statusText(tool: tool) == text, "\(tool) reads \(text) (got \(AgentActivity.statusText(tool: tool)))")
    }
    try expect(AgentActivity.statusText(tool: nil) == "思考中", "no tool yet: Claude shows Thinking")
    try expect(AgentActivity.statusText(tool: "mcp__docs__search_pages") == "搜索中", "MCP tools read like the scene they play")
    try expect(AgentActivity.statusText(tool: "SomethingNew") == "思考中", "unknown tools fall back to thinking")
}

func testAgentSummaryTellsWhichSceneToPlay() throws {
    let reading = AgentSession(record: record("PreToolUse", tool: "Read"))
    try expect(reading?.activity == .read, "a running Read is reading")
    let between = AgentSession(record: record("PostToolUse"))
    try expect(between?.activity == .think, "between tools it is thinking")
    let waiting = AgentSession(record: record("PermissionRequest", tool: "Bash"))
    try expect(waiting?.activity == nil, "waiting for you is not a work scene")

    let board = AgentBoard(sessions: [reading, AgentSession(record: record("PreToolUse", tool: "Bash", at: 110, session: "s2"))].compactMap { $0 })
    try expect(board.summary(at: 120).activity == .eat, "the most recent working session picks the scene")
    try expect(AgentBoard(sessions: [waiting].compactMap { $0 }).summary(at: 120).activity == nil, "no scene while something waits for you")
    try expect(AgentSummary.idle.activity == nil, "no scene when idle")
}

func testAgentSceneHoldKeepsEachSceneOnScreenLongEnough() throws {
    let start = AgentSceneHold.none.updated(desired: .read, at: 0)
    try expect(start.hold.shown == .read && start.recheckAfter == nil, "the first scene starts right away")

    let quick = start.hold.updated(desired: .search, at: 1)
    try expect(quick.hold.shown == .read, "a tool one second later does not cut the scene short")
    try expect(quick.recheckAfter == 2, "…but it is looked at again when the 3 seconds are up (got \(String(describing: quick.recheckAfter)))")

    let later = start.hold.updated(desired: .search, at: 3)
    try expect(later.hold.shown == .search && later.hold.since == 3, "after 3 seconds the scene changes")

    let same = later.hold.updated(desired: .search, at: 4)
    try expect(same.hold == later.hold && same.recheckAfter == nil, "the same work keeps looping without restarting")

    let stopped = later.hold.updated(desired: nil, at: 4)
    try expect(stopped.hold.shown == nil && stopped.recheckAfter == nil, "waiting for you or done stops the scene at once")
}
