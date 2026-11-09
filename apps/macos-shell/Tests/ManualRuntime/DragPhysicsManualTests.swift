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
}

func testDragPhysicsFallsFromTheLiftedHeightBeforeItLands() throws {
    let config = DragPhysicsConfig()
    let moving = dragging(
        DragPhysics(config: config).pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 80, y: 40), start: 0, duration: 0.2
    )
    let released = moving.released(at: 0.2)
    // 拎着就已经抬起来了
    try expect(released.output(at: 0.2).fallOffset == config.liftHeight, "holding should lift the pet off the ground (got \(released.output(at: 0.2).fallOffset))")

    let frame = 1.0 / 60
    var physics = released
    var offsets: [CGFloat] = []
    var poses: [DragPose] = []
    var time: TimeInterval = 0.2
    let end = 0.2 + config.fallDuration + frame
    while time < end {
        time = min(end, time + frame)
        physics = physics.stepped(to: time)
        let output = physics.output(at: time)
        offsets.append(output.fallOffset)
        poses.append(output.pose)
    }
    // 从抬高处一路掉到贴地，中间只降不升、也不越界
    try expect(abs((offsets.first ?? 0) - config.liftHeight) < 0.5, "the fall starts from the lifted height (got \(offsets.first ?? 0))")
    try expect(abs(offsets.last ?? -1) < 0.001, "the fall ends exactly on the ground (got \(offsets.last ?? 0))")
    try expect(offsets.allSatisfy { $0 >= 0 && $0 <= config.liftHeight }, "the fall stays between the ground and the lift height")
    try expect(zip(offsets, offsets.dropFirst()).allSatisfy { $0 >= $1 }, "the pet should only go down while it falls")
    // 下落全程姿势还是拎着那套（窗户不会中途切回主窗口），最后一帧才换成地上姿势
    try expect(poses.dropLast().allSatisfy { $0.isLifted }, "the pet should keep hanging in the lift window while it falls (got \(poses))")
    try expect(!(poses.last ?? .none).isLifted, "landing should put the pet back into the normal window (got \(poses.last ?? DragPose.none))")
}

func testDragPhysicsPlaysLandingThenFullyResets() throws {
    let config = DragPhysicsConfig()
    let moving = dragging(
        DragPhysics(config: config).pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 80, y: 40), start: 0, duration: 0.2
    )
    let released = moving.released(at: 0.2)
    try expect(released.lastReleaseWasDrag == true, "release after a drag should be reported as a drag")

    // 松手后先往下坠：身体还是拎着的样子，只是位置越来越低（起步慢、落地快）
    let falling = released.stepped(to: 0.2 + config.fallDuration * 0.5)
    let midFall = falling.output(at: 0.2 + config.fallDuration * 0.5)
    guard case .hold = midFall.pose else {
        throw TestFailure(message: "the pet should keep hanging while it falls (got \(midFall.pose))")
    }
    try expect(midFall.fallOffset > 0 && midFall.fallOffset < config.liftHeight, "free fall should drop from the lifted height (got \(midFall.fallOffset))")
    try expect(midFall.landingSquash == 1, "nothing should squash while it is still in the air (got \(midFall.landingSquash))")

    // 落地那一刻才换成地上姿势，压扁也从这一刻才开始
    let landedAt = 0.2 + config.fallDuration + 0.02
    let justLanded = released.stepped(to: landedAt)
    guard case .landing = justLanded.output(at: landedAt).pose else {
        throw TestFailure(message: "release should play the landing pose once it hits the ground (got \(justLanded.output(at: landedAt).pose))")
    }
    try expect(justLanded.output(at: landedAt).fallOffset == 0, "once it lands it sits on the ground (got \(justLanded.output(at: landedAt).fallOffset))")
    try expect(justLanded.output(at: landedAt).landingSquash < 1, "landing should squash the body")

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
    // 晕劲儿被续到落地帧播完之后，所以复位要等到那之后
    let end = time + config.landingDuration + config.groundedDizzyDuration + config.settleDuration + 0.1
    let rested = stepping(released, from: time, to: end)
    try expect(rested.output(at: end) == .rest, "dizziness should wear off and fully reset (got \(rested.output(at: end)))")
}

func testDragPhysicsStaysDizzyOnTheGroundAfterLanding() throws {
    let config = DragPhysicsConfig()
    var physics = DragPhysics(config: config).pressed(at: .zero, at: 0)
    var time: TimeInterval = 0
    // 0.8 秒内左右各甩 3 次（5 次换向），先把豚鼠甩晕
    for index in 0..<6 {
        let from = CGPoint(x: index % 2 == 0 ? 0 : 80, y: 0)
        let to = CGPoint(x: index % 2 == 0 ? 80 : 0, y: 0)
        physics = dragging(physics, from: from, to: to, start: time, duration: 0.13)
        time += 0.13
    }

    let released = physics.released(at: time)
    // 晕着松手：先拎着往下坠，星星还亮着，姿势不能提前换成地上的
    let midFall = released.output(at: time + config.fallDuration * 0.5)
    guard case .dizzy = midFall.pose else {
        throw TestFailure(message: "a dizzy release should keep the stars while it falls (got \(midFall.pose))")
    }
    try expect(midFall.fallOffset > 0, "a dizzy release falls from the lifted height too (got \(midFall.fallOffset))")
    // 落地那一刻就该是待地晕，不能先播坐姿 + 灰尘的普通落地帧
    let impact = time + config.fallDuration + 0.02
    guard case .dizzyGrounded = released.output(at: impact).pose else {
        throw TestFailure(message: "release while dizzy should be dizzy on the ground right away (got \(released.output(at: impact).pose))")
    }
    // 压扁照走：落地那一刻仍然先墩一下，不是硬切（取刚落地那片刻，中段是回弹、会大于 1）
    let squashAtImpact = released.output(at: impact).landingSquash
    try expect(squashAtImpact < 1, "a dizzy landing still squashes on impact (got \(squashAtImpact))")

    // 落地帧播完、晕劲儿还没过：姿势该待在地上，不再拎回拎起窗口
    let grounded = stepping(released, from: time, to: time + config.landingDuration + 1.0 / 60)
    let groundedTime = time + config.landingDuration + 1.0 / 60
    guard case let .dizzyGrounded(twinkle) = grounded.output(at: groundedTime).pose else {
        throw TestFailure(message: "a dizzy pet that already landed should stay dizzy on the ground (got \(grounded.output(at: groundedTime).pose))")
    }
    try expect(!grounded.output(at: groundedTime).pose.isLifted, "dizziness on the ground must not pull the pet back into the lift window")
    try expect(twinkle == 0 || twinkle == 1, "the grounded pose still picks a dizzy_grounded_<twinkle> frame (got twinkle \(twinkle))")
    try expect(
        DragPose.dizzyGrounded(twinkle: twinkle).mirrored == .dizzyGrounded(twinkle: twinkle),
        "grounded dizzy frames have no lean to mirror"
    )

    // 星星还在闪：说明确实在播甩晕那套帧（采样窗口覆盖整个待地晕）
    var twinkles: Set<Int> = []
    var sample = grounded
    var sampleTime = groundedTime
    let groundedEnd = time + config.landingDuration + config.groundedDizzyDuration
    while sampleTime < groundedEnd - 1.0 / 60 {
        sampleTime = min(groundedEnd - 1.0 / 60, sampleTime + 1.0 / 60)
        sample = sample.stepped(to: sampleTime)
        if case let .dizzyGrounded(twinkle) = sample.output(at: sampleTime).pose { twinkles.insert(twinkle) }
    }
    try expect(twinkles == [0, 1], "the twinkle should keep flipping while it is dizzy on the ground (got \(twinkles.sorted()))")

    // 待地晕要持续到配置的时长，差一帧都还该晕着
    let stillDizzy = stepping(released, from: time, to: groundedEnd - 1.0 / 60)
    guard case .dizzyGrounded = stillDizzy.output(at: groundedEnd - 1.0 / 60).pose else {
        throw TestFailure(message: "the pet should stay dizzy on the ground for the full \(config.groundedDizzyDuration)s (got \(stillDizzy.output(at: groundedEnd - 1.0 / 60).pose))")
    }

    let end = groundedEnd + config.settleDuration + 0.1
    let rested = stepping(released, from: time, to: end)
    try expect(rested.output(at: end) == .rest, "once the dizziness wears off it should return to rest (got \(rested.output(at: end)))")
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

/// 左右来回晃鼠标（正弦），frequency 次/秒、amplitude pt，按 fps 采样 swing 角度
private func shaking(frequency: Double, amplitude: CGFloat, seconds: Double, fps: Double = 120) -> [(TimeInterval, CGFloat)] {
    var physics = DragPhysics().pressed(at: .zero, at: 0)
    physics = physics.moved(to: CGPoint(x: 0, y: 10), at: 0.001)
    var samples: [(TimeInterval, CGFloat)] = []
    for index in 1...Int(seconds * fps) {
        let time = Double(index) / fps
        let point = CGPoint(x: amplitude * CGFloat(sin(2 * .pi * frequency * time)), y: 10)
        physics = physics.moved(to: point, at: time).stepped(to: time)
        samples.append((time, physics.output(at: time).swingDegrees))
    }
    return samples
}

private func signChanges(_ values: [CGFloat], deadband: CGFloat = 4) -> Int {
    var last = 0
    var changes = 0
    for value in values where abs(value) > deadband {
        let sign = value > 0 ? 1 : -1
        if last != 0, sign != last { changes += 1 }
        last = sign
    }
    return changes
}

func testDragPhysicsSwingFollowsTheShakeFrequency() throws {
    for frequency in [1.5, 3.0, 4.5] {
        let late = shaking(frequency: frequency, amplitude: 50, seconds: 3).filter { $0.0 >= 1 }.map(\.1)
        let perSecond = Double(signChanges(late)) / 2
        try expect(
            abs(perSecond - 2 * frequency) <= 1,
            "shaking at \(frequency)Hz should swing at the same rhythm (\(perSecond) flips/s, want \(2 * frequency))"
        )
    }
}

func testDragPhysicsSwingIsExaggeratedButBounded() throws {
    let config = DragPhysicsConfig()
    let swings = shaking(frequency: 3, amplitude: 60, seconds: 2).map(\.1)
    let peak = swings.map(abs).max() ?? 0
    try expect(peak >= 30, "a real shake should throw the body far out (peak \(peak)°)")
    try expect(peak <= config.maxSwingDegrees + 0.01, "swing must stay within the limit (peak \(peak)°)")
}

func testDragPhysicsKeepsWobblingAfterTheMouseStops() throws {
    let moving = dragging(
        DragPhysics().pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 150, y: 0), start: 0, duration: 0.15
    )
    var physics = moving
    var swings: [CGFloat] = []
    var time: TimeInterval = 0.15
    while time < 1.2 {
        time += 1.0 / 120
        physics = physics.stepped(to: time)
        swings.append(physics.output(at: time).swingDegrees)
    }
    try expect(swings.contains { $0 > 3 }, "after a sudden stop the body should overshoot past the middle like a pendulum")
    try expect(abs(swings.last ?? 99) < 2, "the wobble should die down within a second (got \(swings.last ?? 99))")
}

func testDragPhysicsStretchesMoreWhenYankedFast() throws {
    let config = DragPhysicsConfig()
    let still = stepping(
        dragging(DragPhysics(config: config).pressed(at: .zero, at: 0), from: .zero, to: CGPoint(x: 0, y: 10), start: 0, duration: 0.05),
        from: 0.05, to: 2
    ).output(at: 2).stretchY
    let yanked = dragging(
        DragPhysics(config: config).pressed(at: .zero, at: 0),
        from: .zero, to: CGPoint(x: 0, y: 300), start: 0, duration: 0.3
    ).output(at: 0.3).stretchY
    try expect(still >= 1.12, "hanging still should already look clearly stretched (got \(still))")
    try expect(yanked > still + 0.05, "yanking up fast should stretch the body further (\(yanked) vs \(still))")
}

/// 3Hz 甩动时每帧的完整输出
private func shakingOutputs(frequency: Double, amplitude: CGFloat, seconds: Double, fps: Double = 120) -> [DragOutput] {
    var physics = DragPhysics().pressed(at: .zero, at: 0).moved(to: CGPoint(x: 0, y: 10), at: 0.001)
    return (1...Int(seconds * fps)).map { index in
        let time = Double(index) / fps
        physics = physics.moved(to: CGPoint(x: amplitude * CGFloat(sin(2 * .pi * frequency * time)), y: 10), at: time).stepped(to: time)
        return physics.output(at: time)
    }
}

func testDragPhysicsBodyBendsLikeAWaveBehindTheSwing() throws {
    let config = DragPhysicsConfig()
    let outputs = shakingOutputs(frequency: 3, amplitude: 50, seconds: 2).dropFirst(120)
    let bends = outputs.map(\.bendDegrees)
    try expect(bends.contains { $0 > 4 } && bends.contains { $0 < -4 }, "the lower body should whip both ways (bends \(bends.min() ?? 0)…\(bends.max() ?? 0))")
    try expect(bends.allSatisfy { abs($0) <= config.maxBendDegrees + 0.01 }, "the bend stays within its limit")
    let lagging = outputs.filter { abs($0.swingDegrees) > 5 && abs($0.bendDegrees) > 2 && ($0.swingDegrees > 0) != ($0.bendDegrees > 0) }
    try expect(Double(lagging.count) / Double(outputs.count) > 0.15, "the feet lag behind the swing, so the body ripples like a wave (\(lagging.count) lagging samples)")
    let tilts = Set(outputs.compactMap { output -> Int? in
        if case let .hold(tilt) = output.pose { return tilt }
        if case let .dizzy(tilt, _) = output.pose { return tilt }
        return nil
    })
    try expect(tilts.contains(-2) && tilts.contains(2), "the wave reaches the most bent frames on both sides (got \(tilts.sorted()))")
}

func testDragPhysicsBouncesLikeJellyWhenPickedUp() throws {
    let config = DragPhysicsConfig()
    let target = 1 + config.holdStretch
    var physics = DragPhysics(config: config).pressed(at: .zero, at: 0).moved(to: CGPoint(x: 0, y: 4), at: 0.01)
    var stretches: [CGFloat] = []
    var time = 0.01
    while time < 2 {
        time += 1.0 / 120
        physics = physics.stepped(to: time)
        stretches.append(physics.output(at: time).stretchY)
    }
    guard let peakIndex = stretches.indices.max(by: { stretches[$0] < stretches[$1] }) else { return }
    try expect(stretches[peakIndex] > target + 0.03, "picking it up should overshoot the hanging stretch (peak \(stretches[peakIndex]), rest \(target))")
    let afterPeak = stretches[peakIndex...]
    try expect((afterPeak.min() ?? target) < target - 0.01, "…then spring back past it, boing (min after the peak \(afterPeak.min() ?? 0))")
    try expect(abs((stretches.last ?? 0) - target) < 0.01, "and settle on the hanging stretch (got \(stretches.last ?? 0))")
}
