import AppKit

// 桌宠窗口这边：状态条显示 Agent 状态，菜单里能接入 / 断开 Claude Code

@MainActor
private func makeAgentAwarePet() throws -> DesktopPetWindowController {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let stateStore = try StateStore(paths: appPaths)
    return DesktopPetWindowController(
        workSessionController: try WorkSessionController(store: stateStore),
        reminderScheduler: ReminderScheduler(),
        healthTracker: HealthSessionTracker(store: try HealthMetricsStore(appPaths: appPaths)),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet",
        onQuitRequested: {}
    )
}

private func agentSession(_ event: String) -> AgentSession? {
    AgentSession(record: ["v": 1, "session": "s1", "event": event, "at": 1.0])
}

@MainActor
func testPetStatusChipShowsTheAgentStateAndFallsBack() throws {
    let controller = try makeAgentAwarePet()
    defer { controller.close() }
    guard let view = controller.window?.contentView as? DesktopPetView else {
        throw TestFailure(message: "pet view missing")
    }
    let normal = view.persistentStatusText

    controller.setAgentSummary(AgentSummary(kind: .waiting, count: 2, lead: agentSession("PermissionRequest")))
    try expect(view.persistentStatusText == "2 个在等你", "the chip tells you sessions wait for you (got \(view.persistentStatusText))")

    controller.setAgentSummary(.idle)
    try expect(view.persistentStatusText == normal, "with no agent activity the usual status comes back (got \(view.persistentStatusText))")
}

@MainActor
func testPetMenuConnectsAndDisconnectsClaudeCode() throws {
    let controller = try makeAgentAwarePet()
    defer { controller.close() }
    guard let window = controller.window as? DesktopPetWindow else {
        throw TestFailure(message: "pet window missing")
    }
    var connected = false
    var requests: [Bool] = []
    controller.claudeConnection = { connected }
    controller.onClaudeConnectionChange = { requests.append($0) }

    try expect(window.menuModelProvider?().items.contains(.connectClaude) == true, "offers to connect")
    window.actionHandler?(.connectClaude)
    connected = true
    try expect(window.menuModelProvider?().items.contains(.disconnectClaude) == true, "then offers to disconnect")
    window.actionHandler?(.disconnectClaude)
    try expect(requests == [true, false], "menu choices reach the app (got \(requests))")
}

@MainActor
func testPetPlaysTheSceneForWhatTheAgentIsDoing() throws {
    let controller = try makeAgentAwarePet()
    defer { controller.close() }
    guard let view = controller.window?.contentView as? DesktopPetView else {
        throw TestFailure(message: "pet view missing")
    }
    let reading = AgentSession(record: ["v": 1, "session": "s1", "event": "PreToolUse", "tool": "Read", "at": 1.0])
    controller.setAgentSummary(AgentSummary(kind: .working, count: 1, lead: reading))
    try expect(view.workActivity == .read, "reading a file: the reading scene (got \(String(describing: view.workActivity)))")
    try expect(view.persistentStatusText == "读取中", "the status chip names the work (got \(view.persistentStatusText))")

    // 一秒内又去搜索：画面要停够 3 秒，字也跟着画面，不各说各的
    let searching = AgentSession(record: ["v": 1, "session": "s1", "event": "PreToolUse", "tool": "Grep", "at": 2.0])
    controller.setAgentSummary(AgentSummary(kind: .working, count: 1, lead: searching))
    try expect(view.workActivity == .read && view.persistentStatusText == "读取中",
               "text stays with the scene on screen (got \(String(describing: view.workActivity)), \(view.persistentStatusText))")

    // 同一个画面里换了个工具（读文件 → 抓网页）：画面不动，字马上换
    let fetching = AgentSession(record: ["v": 1, "session": "s1", "event": "PreToolUse", "tool": "WebFetch", "at": 3.0])
    controller.setAgentSummary(AgentSummary(kind: .working, count: 1, lead: fetching))
    try expect(view.persistentStatusText == "抓取网页中", "same scene, the text follows the tool (got \(view.persistentStatusText))")

    controller.setAgentSummary(AgentSummary(kind: .waiting, count: 1, lead: agentSession("PermissionRequest")))
    try expect(view.workActivity == nil, "waiting for you stops the scene at once")
}

/// 搜索时追着球跑来跑去；不搜了回原位坐好
@MainActor
func testPetChasesTheBallWhileTheAgentSearches() throws {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let work = appPaths.assetsDirectory.appendingPathComponent("pets/capybara/work", isDirectory: true)
    try makeColorPNG(at: appPaths.assetsDirectory.appendingPathComponent("pets/capybara/idle/main/0.png"), color: .brown)
    try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    try makeColorPNG(at: work.appendingPathComponent("search_0.png"), color: .brown)
    try #"{ "fps": 4, "scenes": { "search": { "frames": ["search_0.png"], "order": [0], "fps": 8, "motion": "chase" } } }"#
        .write(to: work.appendingPathComponent("scenes.json"), atomically: true, encoding: .utf8)
    let stateStore = try StateStore(paths: appPaths)
    let controller = DesktopPetWindowController(
        workSessionController: try WorkSessionController(store: stateStore),
        reminderScheduler: ReminderScheduler(),
        healthTracker: HealthSessionTracker(store: try HealthMetricsStore(appPaths: appPaths)),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        onQuitRequested: {}
    )
    defer { controller.close() }
    guard let window = controller.window, let view = window.contentView as? DesktopPetView else { throw TestFailure(message: "pet window missing") }
    let home = window.frame.origin

    let searching = AgentSession(record: ["v": 1, "session": "s1", "event": "PreToolUse", "tool": "Grep", "at": 1.0])
    controller.setAgentSummary(AgentSummary(kind: .working, count: 1, lead: searching))
    try expect(controller.isChasing, "searching sends it after the ball")

    // 先跑出去一段，再让它停
    let deadline = Date().addingTimeInterval(0.6)
    while Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    try expect(window.frame.origin != home, "ran away from home (got \(window.frame.origin))")

    controller.setAgentSummary(AgentSummary(kind: .done, count: 1, lead: agentSession("Stop")))
    try expect(!controller.isChasing, "done: stops chasing")
    try expect(view.workActivity == .search, "still running frames on the way home (got \(String(describing: view.workActivity)))")
    let backBy = Date().addingTimeInterval(2)
    // 等它跑完整趟（最后几帧四舍五入后位置可能已经等于原位，但还没到站）
    while view.workActivity != nil && Date() < backBy { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    try expect(window.frame.origin == home, "trots back to where it was (got \(window.frame.origin), home \(home))")
    try expect(view.workActivity == nil, "home: the run stops (got \(String(describing: view.workActivity)))")
}
