import AppKit

// Agent 状态的三段动作：在等你（循环）、干完了 / 出错了（只放一遍，干完了中途被抛起来）

private func writeStateScenes(in directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for name in ["wait_0", "wait_1", "done_0", "done_1", "fail_0", "read_0"] {
        try makeColorPNG(at: directory.appendingPathComponent("\(name).png"), color: .brown)
    }
    let manifest = """
    { "fps": 4, "scenes": {
        "read": { "frames": ["read_0.png"], "order": [0] },
        "wait": { "frames": ["wait_0.png", "wait_1.png"], "order": [0, 1] },
        "done": { "frames": ["done_0.png", "done_1.png"], "order": [0, 1, 1, 1], "fps": 8, "once": true,
                  "hop": { "atBeat": 1, "pixels": 3, "beats": 2 } },
        "fail": { "frames": ["fail_0.png"], "order": [0, 0] }
    } }
    """
    try manifest.write(to: directory.appendingPathComponent("scenes.json"), atomically: true, encoding: .utf8)
}

private func makeStateScenes() throws -> PetWorkScenes {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-states-\(UUID().uuidString)", isDirectory: true)
    try writeStateScenes(in: directory)
    guard let scenes = PetWorkScenes(directory: directory, canvasPointSize: NSSize(width: 128, height: 128)) else {
        throw TestFailure(message: "state scenes should load")
    }
    return scenes
}

func testPetScenesNameTheManifestEntries() throws {
    try expect(PetScene.work(.read).name == "read" && PetScene.waiting.name == "wait", "work scenes keep their activity name; waiting is `wait`")
    try expect(PetScene.done.name == "done" && PetScene.failed.name == "fail", "done / failed map to `done` / `fail`")
    try expect(PetScene.work(.search).activity == .search && PetScene.waiting.activity == nil, "only work scenes carry an activity")
    try expect(PetScene.waiting.facesSideways && !PetScene.work(.read).facesSideways, "state scenes are side-on like idle, work scenes face the viewer")
}

func testPetWorkScenesPlayOnceScenesToTheEndAndReadTheHop() throws {
    let scenes = try makeStateScenes()
    try expect(!scenes.playsOnce(.waiting) && scenes.playsOnce(.done), "waiting loops, done plays once")
    try expect(scenes.frameName(for: .waiting, after: 0.75) == "wait_1.png", "a looping scene wraps around")
    try expect(scenes.frameName(for: .done, after: 0.49) == "done_1.png", "a once scene runs through its order")
    try expect(scenes.isFinished(.done, after: 0.5) && !scenes.isFinished(.done, after: 0.49), "…and is finished after its last beat (4 beats at 8 fps)")
    try expect(scenes.frameName(for: .done, after: 0.6) == nil, "nothing to show once it is finished")
    try expect(!scenes.isFinished(.waiting, after: 100), "a looping scene never finishes")

    guard let hop = scenes.hop(for: .done) else { throw TestFailure(message: "done should have a hop") }
    try expect(hop.startsAfter == 0.125 && hop.pixels == 3 && hop.duration == 0.25, "hop at beat 1 for 2 beats at 8 fps (got \(hop))")
    try expect(scenes.hop(for: .failed) == nil, "failed has no hop")
    try expect(scenes.isFinished(.failed, after: 0.5), "done / failed end even if the manifest forgot `once` (they would block naps forever)")
}

func testPetScenePlayerFinishesOnceScenesAndFiresTheHopOnce() throws {
    var clock: TimeInterval = 0
    let player = PetWorkScenePlayer(now: { clock }, startsTimer: false)
    player.reload(scenes: try makeStateScenes())
    var images: [Bool] = []
    var hops: [PetSceneHop] = []
    var finished: [PetScene] = []
    player.onImageChanged = { images.append($0 != nil) }
    player.onHop = { hops.append($0) }
    player.onFinished = { finished.append($0) }

    player.play(.done)
    try expect(player.scene == .done && images == [true], "starts on the first frame")
    try expect(hops.isEmpty, "no hop before its beat")
    clock = 0.13
    player.tick()
    clock = 0.2
    player.tick()
    try expect(hops.count == 1 && hops.first?.pixels == 3, "the hop fires once when its beat comes (got \(hops))")
    clock = 0.6
    player.tick()
    try expect(player.scene == nil && player.image == nil, "after the last beat the scene is over")
    try expect(images.last == false && finished == [.done], "it says so once (images \(images), finished \(finished))")
    player.tick()
    try expect(finished == [.done], "and only once")

    var noAssets: [PetScene] = []
    let bare = PetWorkScenePlayer(now: { clock }, startsTimer: false)
    bare.onFinished = { noAssets.append($0) }
    bare.play(.failed)
    try expect(noAssets == [.failed] && bare.scene == nil, "a one-shot this pet has no frames for ends at once instead of blocking naps")

    player.play(.waiting)
    clock = 100
    player.tick()
    try expect(player.scene == .waiting && player.image != nil, "waiting keeps looping")
}

func testPetClickHopCanBeAskedForAnyHeight() throws {
    let layer = InteractionLayer()
    layer.hop(pixels: 3, duration: 0.4, at: 0)
    var highest: CGFloat = 0
    for step in 0...50 {
        let lift = layer.evaluate(at: Double(step) * 0.01).translateY
        try expect(lift.truncatingRemainder(dividingBy: InteractionLayer.spritePixel) == 0, "whole sprite pixels only (got \(lift))")
        highest = max(highest, lift)
    }
    try expect(highest == InteractionLayer.spritePixel * 3, "reaches 3 sprite pixels (got \(highest))")
    try expect(layer.evaluate(at: 0.5) == .identity, "and lands")
}

/// 在等你：不打盹、不做小动作，但侧身坐着，可以转头看鼠标；干完了放完一遍自己回到待机
@MainActor
func testDesktopPetViewPlaysStateScenesAndReportsWhenOneShotsEnd() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeStateScenes(in: petRoot.appendingPathComponent("work", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let idle = view.presentedSource

    view.setScene(.waiting)
    try expect(view.scene == .waiting && view.workActivity == nil, "waiting is a scene but not work")
    try expect(view.presentedSource !== idle, "the waiting frames replace idle")
    try expect(!view.behavior.isAvailable(), "no naps or idle actions while waiting")
    try expect(view.canTurnTowardCursor, "a side-on scene can still turn to look at the cursor")

    var finished: [PetScene] = []
    view.onSceneFinished = { finished.append($0) }
    view.workPlayer.finishForTesting()
    try expect(finished == [.waiting] && view.scene == nil && view.presentedSource === idle, "a finished scene hands back to idle")
}

/// 控制器：在等你一直招手、头顶挂卡片，「跳过去」切回终端；提醒排在后面；干完了演一遍
@MainActor
func testPetWaitsWithACardThenCelebratesAndLetsTheReminderThrough() throws {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeStateScenes(in: petRoot.appendingPathComponent("work", isDirectory: true))
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
    guard let view = controller.window?.contentView as? DesktopPetView else { throw TestFailure(message: "pet view missing") }
    var jumped: [String] = []
    controller.activateApp = { jumped.append($0) }

    let waiting = AgentSession(record: ["v": 1, "session": "s1", "event": "PermissionRequest", "tool": "Bash", "at": 1.0,
                                        "project": "icu", "app": "com.example.term"])
    controller.setAgentSummary(AgentSummary(kind: .waiting, count: 1, lead: waiting))
    try expect(view.scene == .waiting, "waiting: the waving loop (got \(String(describing: view.scene)))")
    try expect(view.isShowingWaitCard && view.waitCardView.content?.title == "icu 在等你", "a card says who waits")
    try expect(controller.window?.frame.height == DesktopPetView.reminderExpandedContentSize.height, "the window grows to fit the card")

    controller.presentReminder(payload: ReminderPresentationPayload(id: UUID(), type: .hydration, text: "喝水"))
    try expect(view.reminderCardView.isHidden, "a reminder waits behind the agent")

    let jump = view.waitCardView.jumpButton
    _ = jump.sendAction(jump.action, to: jump.target)
    try expect(jumped == ["com.example.term"] && !view.isShowingWaitCard, "jumping brings the terminal forward and puts the card away")

    let followUp = AgentSession(record: ["v": 1, "session": "s1", "event": "Notification", "kind": "permission_prompt", "at": 1.5,
                                         "project": "icu", "app": "com.example.term"])
    controller.setAgentSummary(AgentSummary(kind: .waiting, count: 1, lead: followUp))
    try expect(!view.isShowingWaitCard, "the follow-up notification of the same wait does not bring the card back")

    let done = AgentSession(record: ["v": 1, "session": "s1", "event": "Stop", "at": 2.0, "project": "icu"])
    controller.setAgentSummary(AgentSummary(kind: .done, count: 1, lead: done))
    try expect(!view.reminderCardView.isHidden, "the held reminder comes out once nothing waits")
    try expect(view.scene == nil, "the celebration waits behind the reminder card (L2 over L1)")

    view.reminderCardView.onAction?(.completed)
    try expect(view.scene == .done, "after the card the pet celebrates (got \(String(describing: view.scene)))")
    view.workPlayer.finishForTesting()
    try expect(view.scene == nil, "and settles back to idle")
}
