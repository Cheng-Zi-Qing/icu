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
    // 每种工具从自己那一组俏皮话里抽（像 Claude Code 转圈时的 Pondering… Noodling…）
    let byTool: [String: AgentLinePool] = [
        "Read": .read, "Grep": .search, "Glob": .search, "LS": .search,
        "Edit": .update, "MultiEdit": .update, "NotebookEdit": .update, "Write": .write,
        "Bash": .bash, "BashOutput": .bash, "KillShell": .bash,
        "WebFetch": .fetch, "WebSearch": .webSearch, "Task": .delegate, "Agent": .delegate,
    ]
    for (tool, pool) in byTool {
        let text = AgentActivity.statusText(tool: tool)
        try expect(isLine(text, of: pool), "\(tool) reads like \(pool) (got \(text))")
    }
    try expect(isLine(AgentActivity.statusText(tool: nil), of: .think), "no tool yet: Claude is thinking")
    try expect(isLine(AgentActivity.statusText(tool: "mcp__docs__search_pages"), of: .search), "MCP tools read like the scene they play")
    try expect(isLine(AgentActivity.statusText(tool: "SomethingNew"), of: .think), "unknown tools fall back to thinking")
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
    let hold = AgentSceneHold.minimumDuration
    try expect(hold >= 10, "like Claude Code's one spinner word, a scene stays a good while (got \(hold)s)")
    let start = AgentSceneHold.none.updated(desired: .read, at: 0)
    try expect(start.hold.shown == .read && start.recheckAfter == nil, "the first scene starts right away")

    let quick = start.hold.updated(desired: .search, at: 1)
    try expect(quick.hold.shown == .read, "a tool one second later does not cut the scene short")
    try expect(quick.recheckAfter == hold - 1, "…but it is looked at again when the hold is up (got \(String(describing: quick.recheckAfter)))")

    let later = quick.hold.updated(desired: .search, at: hold)
    try expect(later.hold.shown == .search && later.hold.since == hold, "after the hold the scene changes")

    let same = later.hold.updated(desired: .search, at: hold + 1)
    try expect(same.hold.shown == .search && same.hold.since == hold && same.recheckAfter == nil, "the same work keeps looping without restarting")

    let stopped = later.hold.updated(desired: nil, at: hold + 1)
    try expect(stopped.hold.shown == nil && stopped.recheckAfter == nil, "waiting for you or done stops the scene at once")
}

/// 工具和工具之间那一两秒算「在想」：不为它换画面，一直在想够久了才换
func testAgentSceneHoldIgnoresTheShortThinksBetweenTools() throws {
    let hold = AgentSceneHold.minimumDuration
    let settle = AgentSceneHold.thinkSettle
    let reading = AgentSceneHold.none.updated(desired: .read, at: 0).hold

    let gap = reading.updated(desired: .think, at: hold - 1)
    try expect(gap.hold.shown == .read && gap.recheckAfter == settle, "a think gap waits to see if it lasts (got \(String(describing: gap.recheckAfter)))")
    let backToWork = gap.hold.updated(desired: .read, at: hold + 1)
    try expect(backToWork.hold.shown == .read && backToWork.hold.since == 0, "the next tool came: the same scene simply carries on")

    let stillThinking = gap.hold.updated(desired: .think, at: hold + 2)
    try expect(stillThinking.hold.shown == .read && stillThinking.recheckAfter == settle - 3, "the think started at \(hold - 1)s, so it counts from there (got \(String(describing: stillThinking.recheckAfter)))")
    let settled = stillThinking.hold.updated(desired: .think, at: hold - 1 + settle)
    try expect(settled.hold.shown == .think, "thinking for a good while does show thinking")
}
