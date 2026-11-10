import AppKit

// 拎起来：身体挂在后颈上跟着鼠标甩，整只都要露出来（不被 128pt 的桌宠窗口裁掉）

private func transformed(_ t: CATransform3D, _ point: CGPoint) -> CGPoint {
    let x = t.m11 * point.x + t.m21 * point.y + t.m41
    let y = t.m12 * point.x + t.m22 * point.y + t.m42
    let w = t.m14 * point.x + t.m24 * point.y + t.m44
    return CGPoint(x: x / w, y: y / w)
}

private let liftCanvas = CGRect(x: 0, y: 0, width: 128, height: 128)

func testAnimationEngineLiftSwingsTheBodyAroundTheScruff() throws {
    let anchor = CGPoint(x: 0, y: 0)
    for swing in [CGFloat(-30), 30] {
        let lift = PetAnimationEngine.liftedTransform(
            drag: DragOutput(pose: .hold(tilt: 0), stretchY: 1.2, swingDegrees: swing, landingSquash: 1),
            layerBounds: liftCanvas,
            anchorPoint: anchor
        )
        let scruff = transformed(lift, CGPoint(x: 64, y: 128))
        let feet = transformed(lift, CGPoint(x: 64, y: 0))
        try expect(abs(scruff.x - 64) < 0.001 && abs(scruff.y - 128) < 0.001, "the grab point stays under the cursor (got \(scruff))")
        try expect(
            swing < 0 ? feet.x < 64 - 40 : feet.x > 64 + 40,
            "a \(swing)° swing should throw the feet far to that side (feet at \(feet))"
        )
    }
}

func testPetLiftWindowLeavesRoomForTheWildestSwing() throws {
    let config = DragPhysicsConfig()
    let room = CGRect(origin: .zero, size: PetLiftWindow.frame(around: liftCanvas).size)
    let canvasInRoom = liftCanvas.offsetBy(dx: PetLiftWindow.sideMargin, dy: PetLiftWindow.bottomMargin)
    for swing in [-config.maxSwingDegrees, 0, config.maxSwingDegrees] {
        let lift = PetAnimationEngine.liftedTransform(
            drag: DragOutput(pose: .hold(tilt: 0), stretchY: 1 + config.holdStretch + config.maxExtraStretch, swingDegrees: swing, landingSquash: 1),
            layerBounds: liftCanvas,
            anchorPoint: .zero
        )
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: 128, y: 0), CGPoint(x: 0, y: 128), CGPoint(x: 128, y: 128)] {
            let moved = transformed(lift, corner)
            let inRoom = CGPoint(x: moved.x + canvasInRoom.minX, y: moved.y + canvasInRoom.minY)
            try expect(room.insetBy(dx: -0.5, dy: -0.5).contains(inRoom), "at \(swing)° the corner \(corner) lands at \(inRoom), outside \(room)")
        }
    }
}

func testPetLiftWindowKeepsRoomForTheLiftedPet() throws {
    let config = DragPhysicsConfig()
    let room = CGRect(origin: .zero, size: PetLiftWindow.frame(around: liftCanvas).size)
    let canvasInRoom = liftCanvas.offsetBy(dx: PetLiftWindow.sideMargin, dy: PetLiftWindow.bottomMargin)
    // 拎起窗口的头顶留白得装得下这截抬高，再加 20pt 给转起来时翘起的画布角，否则松手后脑袋被裁掉一截
    try expect(
        PetLiftWindow.topMargin >= config.liftHeight + 20,
        "the headroom above the canvas should fit the lift height (got \(PetLiftWindow.topMargin), need \(config.liftHeight))"
    )
    // 拎着和下落全程：摆角在松手瞬间还很大，但几十毫秒内就衰掉了，取衰完后的幅度查四角
    for swing in [-CGFloat(10), 0, 10] {
        let lift = PetAnimationEngine.liftedTransform(
            drag: DragOutput(
                pose: .hold(tilt: 0),
                stretchY: 1 + config.holdStretch + config.maxExtraStretch,
                swingDegrees: swing,
                landingSquash: 1,
                fallOffset: config.liftHeight
            ),
            layerBounds: liftCanvas,
            anchorPoint: .zero
        )
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: 128, y: 0), CGPoint(x: 0, y: 128), CGPoint(x: 128, y: 128)] {
            let moved = transformed(lift, corner)
            let inRoom = CGPoint(x: moved.x + canvasInRoom.minX, y: moved.y + canvasInRoom.minY)
            try expect(room.insetBy(dx: -0.5, dy: -0.5).contains(inRoom), "lifted \(swing)° the corner \(corner) lands at \(inRoom), outside \(room)")
        }
    }
}

func testDragPoseMirrorsItsLeanWhenThePetFacesRight() throws {
    try expect(DragPose.hold(tilt: -2).mirrored == .hold(tilt: 2), "a mirrored left lean becomes a right lean")
    try expect(DragPose.dizzy(tilt: 1, twinkle: 1).mirrored == .dizzy(tilt: -1, twinkle: 1), "dizzy frames mirror their lean too")
    try expect(DragPose.landing(frame: 1).mirrored == .landing(frame: 1), "landing frames have no lean")
    try expect(DragPose.hold(tilt: 0).isLifted && DragPose.dizzy(tilt: 0, twinkle: 0).isLifted, "hold and dizzy hang in the air")
    try expect(!DragPose.landing(frame: 0).isLifted && !DragPose.none.isLifted, "landing and resting are on the ground")
}

private func makeLiftablePet() throws -> (DesktopPetView, NSWindow) {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    let brown = NSColor(deviceRed: 0.7, green: 0.45, blue: 0.3, alpha: 1)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: brown)
    for tilt in -2...2 {
        try makeColorPNG(at: petRoot.appendingPathComponent("drag/hold_\(tilt).png"), color: brown)
    }
    for tilt in -2...2 {
        for twinkle in 0...1 {
            try makeColorPNG(at: petRoot.appendingPathComponent("drag/dizzy_\(tilt)_\(twinkle).png"), color: brown)
        }
    }
    // 甩晕后落地这段走的是单独一套坐姿帧；少写一张，姿势就会提前断掉、回到静止
    for twinkle in 0...1 {
        try makeColorPNG(at: petRoot.appendingPathComponent("drag/dizzy_grounded_\(twinkle).png"), color: brown)
    }
    try makeColorPNG(at: petRoot.appendingPathComponent("drag/land_0.png"), color: brown)
    try makeColorPNG(at: petRoot.appendingPathComponent("drag/land_1.png"), color: brown)
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let window = NSWindow(contentRect: NSRect(x: 600, y: 300, width: 128, height: DesktopPetView.compactContentSize.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    return (view, window)
}

func testDesktopPetViewHangsTheLiftedPetInABiggerWindow() throws {
    let (view, window) = try makeLiftablePet()
    defer { window.close() }

    view.applyDragPose(.hold(tilt: 0))
    guard let lift = view.liftWindow else {
        throw TestFailure(message: "lifting should open the bigger lift window")
    }
    try expect(lift.isVisible, "the lift window is on screen while held")
    try expect(lift.parent === window, "the lift window rides along with the pet window while it is dragged")
    try expect(lift.ignoresMouseEvents, "the lift window never steals the drag")
    try expect(view.imageView.alphaValue == 0, "the clipped pet in the small window steps aside")
    try expect(lift.spriteLayer.contents != nil, "the hold frame is drawn in the lift window")
    let canvas = window.convertToScreen(view.convert(view.imageView.frame, to: nil))
    try expect(
        lift.frame.insetBy(dx: PetLiftWindow.sideMargin - 1, dy: 0).contains(CGPoint(x: canvas.midX, y: canvas.midY))
            && lift.frame.width >= canvas.width + 2 * PetLiftWindow.sideMargin,
        "the lift window surrounds the pet with room to swing (lift \(lift.frame), canvas \(canvas))"
    )

    view.applyDragPose(.landing(frame: 0))
    try expect(!lift.isVisible, "landing puts it back into the normal window")
    try expect(view.imageView.alphaValue == 1, "the normal pet shows again on landing")
}

/// 一帧的实际渲染结果：姿势，加上拎起窗口 / 小窗口里这只到底可不可见
private struct DragRenderFrame {
    var time: TimeInterval
    var pose: DragPose
    var liftVisible: Bool
    var petAlpha: CGFloat
}

/// 甩 5 次换向把豚鼠甩晕，再继续拎着 `holdAfterShake` 秒才松手。
/// 逐帧推进物理，姿势一变就喂给真实的 DesktopPetView（和 PetAnimationEngine.tick 一样），
/// 记录每帧的渲染状态，用来看拎起窗口到底有没有收回去
private func dragAndReleaseTimeline(
    view: DesktopPetView,
    holdAfterShake: TimeInterval,
    secondsAfterRelease: TimeInterval
) throws -> (releasedAt: TimeInterval, frames: [DragRenderFrame]) {
    // 时间必须自己给：CACurrentMediaTime() 是巨大实数，跟这里从 0 开始的合成时间不同基准，
    // elapsed 会一直是负的，姿势卡在落地第一帧不动，看着像代码坏了
    var clock: TimeInterval = 0
    let controller = PetDragController(config: DragPhysicsConfig(), timeProvider: { clock })
    let frame: TimeInterval = 1.0 / 60
    var frames: [DragRenderFrame] = []
    var lastPose: DragPose?

    /// 推进一帧：先给控制器时间，再按姿势变化把新姿势喂给视图
    func tick(at time: TimeInterval, mouseLocation: CGPoint?) {
        clock = time
        if let mouseLocation {
            _ = controller.mouseDragged(mouseLocation: mouseLocation, keepVisible: .zero, visibleFrame: nil)
        }
        let output = controller.output(at: time)
        if output.pose != lastPose {
            lastPose = output.pose
            view.applyDragPose(output.pose)
        }
        frames.append(DragRenderFrame(
            time: time,
            pose: output.pose,
            liftVisible: view.liftWindow?.isVisible == true,
            petAlpha: view.imageView.alphaValue
        ))
    }

    controller.mouseDown(mouseLocation: .zero, windowOrigin: .zero)
    var time: TimeInterval = 0
    var point = CGPoint(x: 80, y: 0)
    // 0.8 秒内左右各甩 3 次（5 次换向），每段 80pt / 0.13s ≈ 600pt/s
    for index in 0..<6 {
        let segmentStart = time
        let from = CGPoint(x: index % 2 == 0 ? 0 : 80, y: 0)
        let to = CGPoint(x: index % 2 == 0 ? 80 : 0, y: 0)
        let steps = max(1, Int(0.13 * 60))
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            point = CGPoint(x: from.x + (to.x - from.x) * CGFloat(progress), y: 0)
            time = segmentStart + 0.13 * progress
            tick(at: time, mouseLocation: point)
        }
        time = segmentStart + 0.13
    }

    // 甩完继续拎着不动：星星熄了以后再松手就该是普通落地
    let shakeEnd = time
    while time < shakeEnd + holdAfterShake {
        time = min(shakeEnd + holdAfterShake, time + frame)
        tick(at: time, mouseLocation: point)
    }

    try expect(controller.mouseUp(), "releasing after a drag should be reported as a drag")
    let releasedAt = time
    let end = releasedAt + secondsAfterRelease
    while time < end {
        time = min(end, time + frame)
        tick(at: time, mouseLocation: nil)
    }
    return (releasedAt, frames)
}

func testDesktopPetViewStaysDizzyOnTheGroundWhenReleasedWhileSeeingStars() throws {
    let (view, window) = try makeLiftablePet()
    defer { window.close() }
    let config = DragPhysicsConfig()
    let frame: TimeInterval = 1.0 / 60

    let (releasedAt, frames) = try dragAndReleaseTimeline(
        view: view,
        holdAfterShake: 0,
        secondsAfterRelease: config.landingDuration + config.groundedDizzyDuration + config.settleDuration + 0.2
    )
    let held = frames.filter { $0.time < releasedAt }
    let after = frames.filter { $0.time > releasedAt }

    try expect(
        held.contains { if case .dizzy = $0.pose { return true }; return false },
        "hard shaking should light up the stars while held (poses \(held.map { $0.pose }))"
    )
    try expect(
        held.allSatisfy { $0.liftVisible && $0.petAlpha == 0 },
        "while held the whole pet is drawn in the lift window and the clipped one steps aside"
    )

    let groundedEnd = releasedAt + config.landingDuration + config.groundedDizzyDuration
    let fallEnd = releasedAt + config.fallDuration
    // 下落这段还拎在拎起窗口里：星星照样挂着，直到落地那一刻才换回主窗口
    try expect(
        after.filter { $0.time < fallEnd - frame }.allSatisfy { $0.liftVisible && $0.petAlpha == 0 && $0.pose.isLifted },
        "while it is still falling the pet should keep hanging in the lift window (got \(after.prefix(30).map { ($0.time, $0.pose, $0.liftVisible, $0.petAlpha) }))"
    )
    try expect(
        after.filter { $0.time > fallEnd + frame }.allSatisfy { !$0.liftVisible && $0.petAlpha == 1 && !$0.pose.isLifted },
        "once it lands the pet should go back on the ground, not hang it back up (got \(after.filter { $0.liftVisible || $0.petAlpha != 1 }))"
    )
    let firstGrounded = after.first { if case .dizzyGrounded = $0.pose { return true }; return false }
    guard let firstGrounded else {
        throw TestFailure(message: "a pet released while seeing stars should keep seeing them on the ground (got \(after.first?.pose ?? DragPose.none))")
    }
    try expect(!firstGrounded.pose.isLifted, "dizziness on the ground must not pull the pet back into the lift window")
    try expect(
        abs(firstGrounded.time - releasedAt - config.fallDuration) <= 1.5 * frame,
        "releasing while seeing stars should be dizzy on the ground from the first frame after the fall (started at \(firstGrounded.time), want \(releasedAt + config.fallDuration))"
    )
    let lastGrounded = after.last { if case .dizzyGrounded = $0.pose { return true }; return false }
    // 松手时补的晕劲儿只保证「至少」这么久：甩的过程中本来就把晕劲儿续得更久时就顺延，
    // 所以 groundedEnd 是下限而不是精确值，不能要求最后一帧正好落在它上面
    try expect(
        (lastGrounded?.time ?? 0) >= groundedEnd - 1.5 * frame,
        "grounded dizziness should last at least until the landing frame plus \(config.groundedDizzyDuration)s (last frame at \(lastGrounded?.time ?? 0), want at least \(groundedEnd))"
    )
    // 晕劲儿一结束就回待机，不拖尾（余量按帧算，顺着顺延的情况）
    let restFrom = (lastGrounded?.time ?? groundedEnd) + 2 * frame
    try expect(
        after.filter { $0.time > restFrom }.allSatisfy { $0.pose == .none },
        "once the dizziness wears off it should return to rest (got \(after.last?.pose ?? DragPose.none))"
    )
}

func testDesktopPetViewLandsNormallyWhenTheStarsAlreadyBurnedOut() throws {
    let (view, window) = try makeLiftablePet()
    defer { window.close() }
    let config = DragPhysicsConfig()
    let frame: TimeInterval = 1.0 / 60

    // 甩晕后继续拎着，等星星熄了、回到拎着的普通状态再松手
    let (releasedAt, frames) = try dragAndReleaseTimeline(
        view: view,
        holdAfterShake: config.dizzyDuration + 1.5,
        secondsAfterRelease: config.landingDuration + config.settleDuration + 0.5
    )
    let held = frames.filter { $0.time < releasedAt }
    let after = frames.filter { $0.time > releasedAt }

    try expect(
        held.contains { if case .hold = $0.pose { return true }; return false },
        "once the stars burn out it should go back to the ordinary hold pose (poses \(held.map { $0.pose }))"
    )
    try expect(held.allSatisfy { $0.liftVisible && $0.petAlpha == 0 }, "still held, so it keeps hanging in the lift window")

    try expect(
        !after.contains { if case .dizzyGrounded = $0.pose { return true }; return false },
        "the stars burned out before the release, so it should just land (got \(after.map { $0.pose }))"
    )
    // 松手后先拎着往下坠，落地那一刻才换成坐姿 + 灰尘的落地帧
    guard case .hold = after.first?.pose else {
        throw TestFailure(message: "a release without dizziness should fall first, still hanging (got \(after.first?.pose ?? DragPose.none))")
    }
    let fallEnd = releasedAt + config.fallDuration
    try expect(
        after.filter { $0.time < fallEnd - frame }.allSatisfy { $0.pose.isLifted && $0.liftVisible && $0.petAlpha == 0 },
        "the pet should keep hanging in the lift window while it falls (got \(after.prefix(30).map { ($0.time, $0.pose, $0.liftVisible, $0.petAlpha) }))"
    )
    try expect(
        after.contains { if case .landing = $0.pose { return true }; return false },
        "once it hits the ground it should play the landing pose (got \(after.map { $0.pose }))"
    )
    try expect(
        after.filter { $0.time > fallEnd + frame }.allSatisfy { !$0.pose.isLifted && !$0.liftVisible && $0.petAlpha == 1 },
        "landing should put the pet back into the normal window (got \(after.filter { $0.liftVisible || $0.petAlpha != 1 }))"
    )
    try expect(after.last?.pose == DragPose.none, "after landing it should return to rest (got \(after.last?.pose ?? DragPose.none))")
}
