import AppKit

// Agent 干活时的小场景：按 work/scenes.json 的顺序循环播放；在演时不打盹、不做随机小动作

private func writeWorkScenes(in directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for name in ["read_0", "read_1", "eat_0"] {
        try makeColorPNG(at: directory.appendingPathComponent("\(name).png"), color: .brown)
    }
    let manifest = """
    { "fps": 4, "scenes": {
        "read": { "frames": ["read_0.png", "read_1.png"], "order": [0, 0, 1] },
        "eat": { "frames": ["eat_0.png"], "order": [0, 7] }
    } }
    """
    try manifest.write(to: directory.appendingPathComponent("scenes.json"), atomically: true, encoding: .utf8)
}

func testPetWorkScenesFollowTheManifestOrderAndLoop() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-work-\(UUID().uuidString)", isDirectory: true)
    try writeWorkScenes(in: directory)
    guard let scenes = PetWorkScenes(directory: directory, canvasPointSize: NSSize(width: 128, height: 128)) else {
        throw TestFailure(message: "work scenes should load")
    }
    let names = [0.0, 0.25, 0.5, 0.75].map { scenes.frameName(for: .read, after: $0) }
    try expect(names == ["read_0.png", "read_0.png", "read_1.png", "read_0.png"], "plays the order at 4 fps and loops (got \(names))")
    try expect(scenes.image(for: .read, after: 0) != nil, "frames load as images")
    try expect(scenes.frameName(for: .eat, after: 0.25) == nil, "an order index past the key frames is skipped rather than crashing")
    try expect(scenes.frameName(for: .write, after: 0) == nil, "a scene this pet does not have plays nothing")
    try expect(PetWorkScenes(directory: directory.appendingPathComponent("missing"), canvasPointSize: NSSize(width: 128, height: 128)) == nil, "no manifest, no scenes")
}

/// 没有素材的场景（比如「在想事情」就用平时的待机）：报一次「没画面」，之后不再空转刷新
func testPetWorkScenePlayerStaysQuietForASceneWithoutFrames() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-work-\(UUID().uuidString)", isDirectory: true)
    try writeWorkScenes(in: directory)
    var clock: TimeInterval = 0
    let player = PetWorkScenePlayer(now: { clock }, startsTimer: false)
    player.reload(scenes: PetWorkScenes(directory: directory, canvasPointSize: NSSize(width: 128, height: 128)))
    var reports: [Bool] = []
    player.onImageChanged = { reports.append($0 != nil) }

    player.play(.think)
    clock = 1
    player.tick()
    player.tick()
    try expect(player.activity == .think && player.image == nil, "thinking is known but has no frames")
    try expect(reports == [false], "one 'no picture' report, then quiet (got \(reports))")
}

@MainActor
func testDesktopPetViewPlaysTheWorkSceneInsteadOfIdling() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeWorkScenes(in: petRoot.appendingPathComponent("work", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let idle = view.presentedSource

    view.setWorkActivity(.read)
    try expect(view.workActivity == .read, "the view knows it is playing the reading scene")
    try expect(view.presentedSource != nil && view.presentedSource !== idle, "the scene replaces the idle frame")
    try expect(!view.canTurnTowardCursor, "a front-facing scene does not flip to look at the cursor")
    try expect(!view.behavior.isAvailable(), "no naps or random idle actions while the agent works")

    view.setWorkActivity(nil)
    try expect(view.workActivity == nil && view.presentedSource === idle, "when the work stops the idle animation comes back")
}

/// 待机动画在背后照常推进；演小场景时它的帧不能上屏，不然两个计时器轮流盖画面，豚鼠一直闪
@MainActor
func testIdleAnimationTicksDoNotFlickerOverTheWorkScene() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeWorkScenes(in: petRoot.appendingPathComponent("work", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.setWorkActivity(.read)
    let scene = view.presentedSource

    let nextIdleFrame = NSImage(size: NSSize(width: 8, height: 8))
    view.updateDisplayedImage(nextIdleFrame)
    try expect(view.presentedSource === scene, "an idle frame tick keeps the scene on screen")

    view.setWorkActivity(nil)
    try expect(view.presentedSource === nextIdleFrame, "stopping shows the idle frame the animation reached meanwhile")
}

func testPetWorkScenesReadPerSceneSpeedAndMotion() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-work-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try makeColorPNG(at: directory.appendingPathComponent("search_0.png"), color: .brown)
    try makeColorPNG(at: directory.appendingPathComponent("search_1.png"), color: .brown)
    let manifest = """
    { "fps": 4, "scenes": { "search": { "frames": ["search_0.png", "search_1.png"], "order": [0, 1], "fps": 8, "motion": "chase" },
                             "read": { "frames": ["search_0.png"], "order": [0] } } }
    """
    try manifest.write(to: directory.appendingPathComponent("scenes.json"), atomically: true, encoding: .utf8)
    guard let scenes = PetWorkScenes(directory: directory, canvasPointSize: NSSize(width: 128, height: 128)) else {
        throw TestFailure(message: "work scenes should load")
    }
    try expect(scenes.framesPerSecond(for: .search) == 8 && scenes.framesPerSecond(for: .read) == 4, "a scene can run faster than the default")
    try expect(scenes.frameName(for: .search, after: 0.125) == "search_1.png", "…and its frames follow its own speed")
    try expect(scenes.chases(.search) && !scenes.chases(.read), "only the chase scene moves the window")
}

/// 追球：从原位先往左跑，跑到头掉头，来回跑；屏幕边上没地方就跑短一点
func testPetChaseMotionRunsBackAndForthAroundHome() throws {
    let motion = PetChaseMotion(leftRoom: 60, rightRoom: 60)
    let period = motion.period
    let start = motion.position(after: 0)
    try expect(start.offset == 0 && !start.movingRight, "starts at home, running left (the way the pet faces)")
    let farLeft = motion.position(after: period / 4)
    try expect(abs(farLeft.offset + 60) < 0.01, "a quarter loop later it is at the left end (got \(farLeft.offset))")
    let back = motion.position(after: period / 2)
    try expect(abs(back.offset) < 0.01 && back.movingRight, "then turns around and runs back past home")
    let farRight = motion.position(after: period * 3 / 4)
    try expect(abs(farRight.offset - 60) < 0.01, "reaches the right end")
    try expect(!motion.position(after: period * 0.8).movingRight, "and turns again")

    let nearLeftEdge = PetChaseMotion(leftRoom: 10, rightRoom: 60)
    let samples = stride(from: 0.0, to: nearLeftEdge.period, by: 0.05).map { nearLeftEdge.position(after: $0).offset }
    try expect((samples.min() ?? 0) >= -10.01 && (samples.max() ?? 0) <= 60.01, "never runs past the room it has (got \(samples.min() ?? 0)…\(samples.max() ?? 0))")

    let boxedIn = PetChaseMotion(leftRoom: 0, rightRoom: 0)
    try expect(boxedIn.position(after: 1).offset == 0, "no room at all: runs in place")
}

@MainActor
func testPetChaseRunnerMovesTheWindowAndBringsItHome() throws {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let window = NSWindow(contentRect: NSRect(x: 400, y: 100, width: 128, height: 128), styleMask: [.borderless], backing: .buffered, defer: true)
    var clock: TimeInterval = 0
    var facing: [Bool] = []
    let runner = PetChaseRunner(window: window, visibleFrame: { _ in screen }, now: { clock }, startsTimer: false)
    runner.onFacingChanged = { facing.append($0) }

    runner.start()
    try expect(runner.isRunning, "running")
    clock = runner.motion?.period ?? 0
    clock /= 4
    runner.tick()
    try expect(window.frame.origin.x < 400 && window.frame.origin.y == 100, "runs sideways only (got \(window.frame.origin))")
    try expect(facing.last == false, "faces left while running left")

    // 不追了：不是一下子跳回去，而是转身小跑回原位
    var arrivals = 0
    runner.onReturnedHome = { arrivals += 1 }
    let stoppedAt = window.frame.origin.x
    runner.stop()
    try expect(!runner.isRunning && runner.isReturning, "stopped chasing, now heading home")
    try expect(window.frame.origin.x == stoppedAt, "no jump when it stops (got \(window.frame.origin.x), was \(stoppedAt))")
    try expect(facing.last == true, "turns around to face home on its right")
    let trip = PetChaseMotion.returnDuration(from: stoppedAt - 400)
    clock += trip / 2
    runner.tick()
    try expect(window.frame.origin.x > stoppedAt && window.frame.origin.x < 400, "halfway back (got \(window.frame.origin.x))")
    try expect(arrivals == 0, "not there yet")
    clock += trip
    runner.tick()
    try expect(!runner.isReturning && window.frame.origin == CGPoint(x: 400, y: 100), "back where it sat (got \(window.frame.origin))")
    try expect(arrivals == 1, "tells the controller once it is home (got \(arrivals))")
}

/// 往回跑的路上又开始搜：从当前位置接着追，不先跳回原位
func testPetChaseRunnerResumesWhereItIsWhenSearchingAgain() throws {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let window = NSWindow(contentRect: NSRect(x: 400, y: 100, width: 128, height: 128), styleMask: [.borderless], backing: .buffered, defer: true)
    var clock: TimeInterval = 0
    let runner = PetChaseRunner(window: window, visibleFrame: { _ in screen }, now: { clock }, startsTimer: false)
    runner.start()
    clock = 0.5
    runner.tick()
    runner.stop()
    clock += 0.2
    runner.tick()
    let here = window.frame.origin.x
    runner.start()
    try expect(runner.isRunning && !runner.isReturning, "chasing again")
    try expect(abs(window.frame.origin.x - here) <= 1, "picks up from where it is (got \(window.frame.origin.x), was \(here))")

    // 被拎起来：哪儿也不去
    runner.stop(returnHome: false)
    try expect(!runner.isRunning && !runner.isReturning, "picked up: stays in the hand")
}

/// 一个来回里，「往左跑、离原位 offset」是第几秒：往回跑的路上接着追时用
func testPetChaseMotionFindsWhereToResume() throws {
    let motion = PetChaseMotion(leftRoom: 60, rightRoom: 60)
    for offset: CGFloat in [-40, -1, 0, 1, 40] {
        let position = motion.position(after: motion.elapsed(resumingAt: offset))
        try expect(abs(position.offset - offset) < 0.01 && !position.movingRight, "resume at \(offset) heading left (got \(position))")
    }
    try expect(PetChaseMotion.returnDuration(from: -55) == 1, "55pt at 55pt/s is one second")
}
