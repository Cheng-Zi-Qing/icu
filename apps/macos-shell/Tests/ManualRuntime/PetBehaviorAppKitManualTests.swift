import AppKit

// 像素桌宠的动作：一律逐帧 / 整像素，不做漂浮、旋转、压扁这类会把像素糊掉的补间

/// 1 个素材像素 = 4pt（32px 素材放进 128pt 画布）
private let spritePixel: CGFloat = 4

func testPetAnimationEngineStaysStillWithoutInteraction() throws {
    let engine = PetAnimationEngine()
    let start = CACurrentMediaTime()
    for step in 0..<40 {
        let transform = engine.baseTransform(at: start + Double(step) * 0.37)
        try expect(
            transform == .identity,
            "with no click the pixel pet should not float, sway, tilt or squash (got \(transform) at step \(step))"
        )
    }
}

func testPetClickHopMovesInWholeSpritePixels() throws {
    for (doubleClick, height) in [(false, spritePixel), (true, spritePixel * 2)] {
        let layer = InteractionLayer()
        if doubleClick {
            layer.handleDoubleClick(at: 0)
        } else {
            layer.handleMouseDown(at: 0)
        }
        var highest: CGFloat = 0
        for step in 0...60 {
            let transform = layer.evaluate(at: Double(step) * 0.01)
            try expect(
                transform.scaleX == 1 && transform.scaleY == 1 && transform.rotateZ == 0
                    && transform.rotateX == 0 && transform.rotateY == 0,
                "a hop only moves the pet, it never squashes or tilts it (got \(transform))"
            )
            try expect(
                transform.translateY.truncatingRemainder(dividingBy: spritePixel) == 0,
                "hop height should snap to whole sprite pixels (got \(transform.translateY))"
            )
            highest = max(highest, transform.translateY)
        }
        try expect(highest == height, "hop should reach \(height)pt (got \(highest))")
        try expect(layer.evaluate(at: 1) == .identity, "hop should land back on the ground")
    }
}

// MARK: - 摸头 / 打盹

private struct BehaviorFixture {
    let react: PetPoseSprites
    let sleep: PetPoseSprites
    let idleActs: PetPoseSprites

    func sprites(for clip: PetActionClip) -> PetPoseSprites {
        switch clip.directory {
        case "react": return react
        case "sleep": return sleep
        default: return idleActs
        }
    }
}

private func makeBehaviorFixture() throws -> BehaviorFixture {
    let root = try makeTemporaryDirectory()
    let react = root.appendingPathComponent("react", isDirectory: true)
    let sleep = root.appendingPathComponent("sleep", isDirectory: true)
    let idleActs = root.appendingPathComponent("idle_act", isDirectory: true)
    let pink = NSColor(deviceRed: 0.9, green: 0.5, blue: 0.6, alpha: 1)
    let blue = NSColor(deviceRed: 0.3, green: 0.4, blue: 0.8, alpha: 1)
    for name in PetActionClip.petted.frameNames {
        try makeColorPNG(at: react.appendingPathComponent(name), color: pink)
    }
    for clip in [PetActionClip.doze, .nap, .wake] {
        for name in clip.frameNames {
            try makeColorPNG(at: sleep.appendingPathComponent(name), color: blue)
        }
    }
    for clip in [PetActionClip.yuzuWobble, .birdVisit] {
        for name in clip.frameNames {
            try makeColorPNG(at: idleActs.appendingPathComponent(name), color: pink)
        }
    }
    let size = DesktopPetView.compactContentSize
    return BehaviorFixture(
        react: PetPoseSprites(directory: react, canvasPointSize: size),
        sleep: PetPoseSprites(directory: sleep, canvasPointSize: size),
        idleActs: PetPoseSprites(directory: idleActs, canvasPointSize: size)
    )
}

private final class FakeClock {
    var now: TimeInterval = 1000
    var userIdle: TimeInterval = 0
    var isFree = true
    var random = 0.5
}

private func makeCoordinator(_ fixture: BehaviorFixture, clock: FakeClock) -> PetBehaviorCoordinator {
    let coordinator = PetBehaviorCoordinator(
        sprites: { fixture.sprites(for: $0) },
        userIdle: { clock.userIdle },
        now: { clock.now },
        random: { clock.random },
        startsTimer: false
    )
    coordinator.isAvailable = { clock.isFree }
    return coordinator
}

private func rubHead(_ coordinator: PetBehaviorCoordinator, clock: FakeClock) {
    for x: CGFloat in [40, 50, 60, 50, 40, 50, 60] {
        clock.now += 0.08
        coordinator.pointerMoved(x: x, overHead: true)
    }
}

func testPetBehaviorPlaysHappyFramesWhenTheHeadIsRubbed() throws {
    let fixture = try makeBehaviorFixture()
    let clock = FakeClock()
    let coordinator = makeCoordinator(fixture, clock: clock)
    var shown: [NSImage?] = []
    coordinator.onImageChanged = { shown.append($0) }

    for x: CGFloat in [40, 50, 60, 70, 80] {
        clock.now += 0.08
        coordinator.pointerMoved(x: x, overHead: true)
    }
    try expect(coordinator.activeClip == nil, "just passing over the head is not a pat")

    rubHead(coordinator, clock: clock)
    try expect(coordinator.activeClip == .petted, "rubbing the head should play the happy frames")
    try expect(shown.last! === fixture.react.image(named: "petted_0.png"), "starts from the first happy frame")

    clock.now += 1 / PetActionClip.petted.framesPerSecond
    coordinator.tick()
    try expect(shown.last! === fixture.react.image(named: "petted_1.png"), "heart floats up frame by frame")

    clock.now += PetActionClip.petted.duration
    coordinator.tick()
    try expect(coordinator.activeClip == nil && shown.last! == nil, "happy frames end on their own")
}

func testPetBehaviorIgnoresRubbingBesideTheHead() throws {
    let fixture = try makeBehaviorFixture()
    let clock = FakeClock()
    let coordinator = makeCoordinator(fixture, clock: clock)
    for x: CGFloat in [40, 50, 60, 50, 40, 50, 60] {
        clock.now += 0.08
        coordinator.pointerMoved(x: x, overHead: false)
    }
    try expect(coordinator.activeClip == nil, "rubbing the belly or the air is not a head pat")
}

func testPetBehaviorNapsWhileTheUserIsAwayAndWakesWhenTheyReturn() throws {
    let fixture = try makeBehaviorFixture()
    let clock = FakeClock()
    let coordinator = makeCoordinator(fixture, clock: clock)
    var shown: [NSImage?] = []
    coordinator.onImageChanged = { shown.append($0) }

    clock.userIdle = PetNapSchedule.napAfterIdle + 1
    coordinator.tick()
    try expect(coordinator.activeClip == .doze, "dozes off when the user is away")

    clock.now += PetNapSchedule.dozeDuration
    coordinator.tick()
    try expect(coordinator.activeClip == .nap, "then falls asleep")
    try expect(shown.last! === fixture.sleep.image(named: "nap_0.png"), "sleeping frames play")

    clock.now += 1 / PetActionClip.nap.framesPerSecond * Double(PetActionClip.nap.frameNames.count)
    coordinator.tick()
    try expect(coordinator.activeClip == .nap, "sleeping loops until the user is back")

    rubHead(coordinator, clock: clock)
    try expect(coordinator.activeClip == .nap, "no hearts while asleep; the wake-up comes first")

    clock.userIdle = 0.2
    coordinator.tick()
    try expect(coordinator.activeClip == .wake, "wakes up with a start when the user returns")
    try expect(shown.last! === fixture.sleep.image(named: "wake_0.png"), "shows the wake-up frame")

    clock.now += PetNapSchedule.wakeDuration
    coordinator.tick()
    try expect(coordinator.activeClip == nil && shown.last! == nil, "back to the normal idle animation")
}

func testPetBehaviorWakesRightAwayWhenItCannotNap() throws {
    let fixture = try makeBehaviorFixture()
    let clock = FakeClock()
    let coordinator = makeCoordinator(fixture, clock: clock)
    clock.userIdle = PetNapSchedule.napAfterIdle + 1
    coordinator.tick()
    clock.now += PetNapSchedule.dozeDuration
    coordinator.tick()
    try expect(coordinator.activeClip == .nap, "asleep")

    clock.isFree = false
    coordinator.tick()
    try expect(coordinator.activeClip == nil, "a reminder or edge peek takes over immediately")
}

func testPetBehaviorPlaysARandomIdleActionNowAndThen() throws {
    let fixture = try makeBehaviorFixture()
    let clock = FakeClock()
    clock.random = 0
    let coordinator = makeCoordinator(fixture, clock: clock)
    let firstDelay = PetIdleActionSchedule.nextDelay(random: 0)

    clock.now += firstDelay - 1
    coordinator.tick()
    try expect(coordinator.activeClip == nil, "waits a while before fidgeting")

    clock.now += 1
    coordinator.tick()
    let expected = PetIdleActionSchedule.pick(random: 0)
    try expect(coordinator.activeClip == expected, "plays a small idle action when its time comes (got \(String(describing: coordinator.activeClip)))")

    clock.now += expected.duration
    coordinator.tick()
    try expect(coordinator.activeClip == nil, "the small action plays once and ends")

    clock.now += firstDelay - 1
    coordinator.tick()
    try expect(coordinator.activeClip == nil, "the next one is spaced out again")
    clock.now += 1
    coordinator.tick()
    try expect(coordinator.activeClip != nil, "and comes back later")
}

func testPetBehaviorSkipsIdleActionsWhileBusyOrAsleep() throws {
    let fixture = try makeBehaviorFixture()
    let clock = FakeClock()
    let coordinator = makeCoordinator(fixture, clock: clock)

    clock.isFree = false
    clock.now += PetIdleActionSchedule.delayRange.upperBound + 1
    coordinator.tick()
    try expect(coordinator.activeClip == nil, "no idle actions while peeking, dragged or showing a reminder")

    clock.isFree = true
    clock.userIdle = PetNapSchedule.napAfterIdle + 1
    coordinator.tick()
    clock.now += PetNapSchedule.dozeDuration
    coordinator.tick()
    clock.now += PetIdleActionSchedule.delayRange.upperBound + 1
    coordinator.tick()
    try expect(coordinator.activeClip == .nap, "a sleeping pet keeps sleeping instead of fidgeting")
}

func testDesktopPetViewShowsHappyFramesWhenItsHeadIsRubbed() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    for name in PetActionClip.petted.frameNames {
        try makeColorPNG(at: petRoot.appendingPathComponent("react/\(name)"), color: .systemPink)
    }
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.layoutSubtreeIfNeeded()
    let imageView = try requirePetImageView(in: view)
    let idleImage = imageView.image
    let body = try require(view.petBodyRect, "pet body should be known")
    let headY = body.maxY - body.height * 0.2

    for x in [body.midX - 12, body.midX, body.midX + 12, body.midX, body.midX - 12, body.midX, body.midX + 12] {
        let event = try require(
            NSEvent.mouseEvent(
                with: .mouseMoved, location: NSPoint(x: x, y: headY), modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0
            ),
            "mouse event"
        )
        view.mouseMoved(with: event)
    }
    try expect(view.activeActionClipForTesting == .petted, "rubbing the head on screen should start the happy frames")
    try expect(imageView.image !== idleImage, "the happy frame replaces the idle frame on screen")
}

// MARK: - 转头看鼠标（轮询鼠标位置）

func testPetGazeControllerTurnsThePetTowardALingeringCursor() throws {
    var now: TimeInterval = 0
    var cursor = CGPoint(x: 1300, y: 360)
    var facingRight = false
    var canTurn = true
    let controller = PetGazeController(
        bodyFrameOnScreen: { CGRect(x: 1000, y: 300, width: 104, height: 116) },
        isFacingRight: { facingRight },
        onTurn: { facingRight = $0 },
        cursor: { cursor },
        now: { now },
        startsTimer: false
    )
    controller.canTurn = { canTurn }

    controller.tick()
    now += PetGazeTracker.dwell
    controller.tick()
    try expect(facingRight, "cursor lingering on the right should turn the pet right")

    canTurn = false
    cursor = CGPoint(x: 700, y: 360)
    for _ in 0..<20 {
        now += 0.2
        controller.tick()
    }
    try expect(facingRight, "no turning while docked to a side edge, peeking, dragged or napping")

    canTurn = true
    now += PetGazeTracker.cooldown
    controller.tick()
    now += PetGazeTracker.dwell
    controller.tick()
    try expect(!facingRight, "turns back once it is allowed again")
}

private func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message: message) }
    return value
}
