import CoreGraphics
import Foundation

// 屏幕坐标（y 向上），时间单位秒

/// 从 start 开始按 fps 逐帧推进到 end，返回最终状态
private func stepping(_ physics: DragPhysics, from start: TimeInterval, to end: TimeInterval, fps: Double = 60) -> DragPhysics {
    var current = physics
    var time = start
    while time < end {
        time = min(end, time + 1.0 / fps)
        current = current.stepped(to: time)
    }
    return current
}

/// 在 [start, start+duration] 内按 fps 把指针从 from 线性移到 to，同时推进物理
private func dragging(
    _ physics: DragPhysics,
    from: CGPoint,
    to: CGPoint,
    start: TimeInterval,
    duration: TimeInterval,
    fps: Double = 60
) -> DragPhysics {
    let steps = max(1, Int(duration * fps))
    return (1...steps).reduce(physics) { current, index in
        let t = Double(index) / Double(steps)
        let point = CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        let time = start + duration * t
        return current.moved(to: point, at: time).stepped(to: time)
    }
}

func testDragPhysicsTreatsTinyMovementAsClick() throws {
    let pressed = DragPhysics().pressed(at: CGPoint(x: 100, y: 100), at: 0)
    let wiggled = pressed.moved(to: CGPoint(x: 102, y: 101), at: 0.05)
    try expect(!wiggled.isDragging, "movement under the threshold should not start a drag")

    let released = wiggled.released(at: 0.1)
    try expect(released.lastReleaseWasDrag == false, "release without crossing the threshold should count as a click")
    try expect(released.output(at: 0.1) == .rest, "a click should not produce any drag effect")
}

func testDragPhysicsStartsHoldPoseAfterThreshold() throws {
    let start = DragPhysics().pressed(at: CGPoint(x: 100, y: 100), at: 0)
    let moved = start.moved(to: CGPoint(x: 100, y: 110), at: 0.05).stepped(to: 0.05)
    try expect(moved.isDragging, "moving past the threshold should start a drag")

    guard case .hold = moved.output(at: 0.05).pose else {
        throw TestFailure(message: "dragging should switch to the hold pose (got \(moved.output(at: 0.05).pose))")
    }
}

func testDragPhysicsStretchesWhileHeldAndStaysBounded() throws {
    let config = DragPhysicsConfig()
    let held = dragging(
        DragPhysics(config: config).pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 0, y: 10), start: 0, duration: 0.05
    )
    let settled = stepping(held, from: 0.05, to: 0.8)
    let stretch = settled.output(at: 0.8).stretchY

    try expect(stretch > 1 + config.holdStretch * 0.8, "held pet should stretch like mochi (got \(stretch))")
    try expect(stretch <= 1 + config.holdStretch + config.maxExtraStretch + 0.01, "stretch should stay bounded (got \(stretch))")
}

func testDragPhysicsSwingsAgainstHorizontalMotion() throws {
    let moving = dragging(
        DragPhysics().pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 120, y: 0), start: 0, duration: 0.2
    )
    let output = moving.output(at: 0.2)

    try expect(output.swingDegrees < -3, "moving right should swing the body back to the left (got \(output.swingDegrees))")
    guard case let .hold(tilt) = output.pose, tilt < 0 else {
        throw TestFailure(message: "fast rightward drag should pick a left-leaning hold frame (got \(output.pose))")
    }
}

func testDragPhysicsPlaysLandingThenFullyResets() throws {
    let config = DragPhysicsConfig()
    let moving = dragging(
        DragPhysics(config: config).pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 80, y: 40), start: 0, duration: 0.2
    )
    let released = moving.released(at: 0.2)
    try expect(released.lastReleaseWasDrag == true, "release after a drag should be reported as a drag")

    let justLanded = released.stepped(to: 0.22)
    guard case .landing = justLanded.output(at: 0.22).pose else {
        throw TestFailure(message: "release should play the landing pose (got \(justLanded.output(at: 0.22).pose))")
    }
    try expect(justLanded.output(at: 0.22).landingSquash < 1, "landing should squash the body")

    let rested = stepping(released, from: 0.2, to: 0.2 + config.settleDuration + 0.05)
    try expect(
        rested.output(at: 0.2 + config.settleDuration + 0.05) == .rest,
        "after settling every effect must return exactly to rest (got \(rested.output(at: 0.2 + config.settleDuration + 0.05)))"
    )
    try expect(!rested.isActive, "physics should report inactive once settled")
}

func testDragPhysicsGetsDizzyAfterHardShaking() throws {
    let config = DragPhysicsConfig()
    var physics = DragPhysics(config: config).pressed(at: .zero, at: 0)
    var time: TimeInterval = 0
    // 0.8 秒内左右各甩 3 次（5 次换向），每段 80pt / 0.13s ≈ 600pt/s
    for index in 0..<6 {
        let from = CGPoint(x: index % 2 == 0 ? 0 : 80, y: 0)
        let to = CGPoint(x: index % 2 == 0 ? 80 : 0, y: 0)
        physics = dragging(physics, from: from, to: to, start: time, duration: 0.13)
        time += 0.13
    }

    guard case .dizzy = physics.output(at: time).pose else {
        throw TestFailure(message: "hard shaking should make the pet dizzy (got \(physics.output(at: time).pose))")
    }

    let released = physics.released(at: time)
    let end = time + config.dizzyDuration + config.settleDuration + 0.1
    let rested = stepping(released, from: time, to: end)
    try expect(rested.output(at: end) == .rest, "dizziness should wear off and fully reset (got \(rested.output(at: end)))")
}

func testDragPhysicsSlowDraggingDoesNotCauseDizziness() throws {
    var physics = DragPhysics().pressed(at: .zero, at: 0)
    var time: TimeInterval = 0
    for index in 0..<6 {
        let from = CGPoint(x: index % 2 == 0 ? 0 : 30, y: 0)
        let to = CGPoint(x: index % 2 == 0 ? 30 : 0, y: 0)
        physics = dragging(physics, from: from, to: to, start: time, duration: 0.5)
        time += 0.5
    }

    if case .dizzy = physics.output(at: time).pose {
        throw TestFailure(message: "slow back-and-forth dragging should not trigger dizziness")
    }
}

func testDragPhysicsStaysStableAcrossLongFrameGaps() throws {
    let moving = dragging(
        DragPhysics().pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 200, y: 0), start: 0, duration: 0.1
    )
    // 模拟 App 卡顿 / 休眠 5 秒后才来下一帧
    let resumed = moving.stepped(to: 5.1)
    let output = resumed.output(at: 5.1)

    try expect(output.swingDegrees.isFinite && output.stretchY.isFinite, "long gaps must not blow up the springs")
    try expect(abs(output.swingDegrees) < 1, "after a long pause the swing should have settled (got \(output.swingDegrees))")
}
