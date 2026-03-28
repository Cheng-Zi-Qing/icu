import Foundation

func makeStateStoreForTests() throws -> StateStore {
    let root = try makeTemporaryDirectory()
    return try StateStore(paths: AppPaths(rootURL: root))
}

func at(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: seconds)
}

func testAllowsIdleWorkingFocusWorkingBreakWorkingIdleFlow() throws {
    let store = try makeStateStoreForTests()
    let controller = try WorkSessionController(store: store)

    try controller.startWork(now: at(0))
    try controller.enterFocus(now: at(300))
    let suggestion = try controller.resumeWorking(now: at(300 + (35 * 60)))
    try controller.takeBreak(now: at(300 + (36 * 60)))
    _ = try controller.resumeWorking(now: at(300 + (40 * 60)))
    try controller.stopWork(now: at(300 + (45 * 60)))

    try expect(controller.state == .idle, "controller should return to idle")
    try expect(suggestion == .light, "35 minutes of focus should produce a light suggestion")
}

func testRejectsBreakToFocusShortcut() throws {
    let store = try makeStateStoreForTests()
    let controller = try WorkSessionController(store: store)

    try controller.startWork(now: at(0))
    try controller.takeBreak(now: at(30))

    do {
        try controller.enterFocus(now: at(60))
        throw TestFailure(message: "break to focus transition should fail")
    } catch is WorkSessionError {
        return
    }
}

func testPersistWindowPlacementUpdatesCurrentStateAndStore() throws {
    let store = try makeStateStoreForTests()
    let controller = try WorkSessionController(store: store)
    let placement = SavedWindowPlacement(x: 900, y: 120)

    try controller.persistWindowPlacement(placement, now: at(42))

    try expect(controller.savedWindowPlacement == placement, "controller should expose saved window placement")

    let reloaded = try WorkSessionController(store: store)
    try expect(reloaded.savedWindowPlacement == placement, "window placement should persist in state store")
}

func testStateTransitionsPreserveSavedWindowPlacement() throws {
    let store = try makeStateStoreForTests()
    let controller = try WorkSessionController(store: store)
    let placement = SavedWindowPlacement(x: 777, y: 64)

    try controller.persistWindowPlacement(placement, now: at(10))
    try controller.startWork(now: at(20))
    try controller.stopWork(now: at(30))

    try expect(controller.savedWindowPlacement == placement, "window placement should survive state transitions")

    let reloaded = try WorkSessionController(store: store)
    try expect(reloaded.savedWindowPlacement == placement, "persisted placement should survive reload after transitions")
}
