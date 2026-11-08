import Foundation

// 摸头手势和打盹节奏：纯逻辑，不依赖 AppKit

private func feed(_ detector: PetStrokeDetector, _ samples: [(CGFloat, TimeInterval)]) -> (PetStrokeDetector, Int) {
    samples.reduce((detector, 0)) { state, sample in
        let (next, stroked) = state.0.feeding(x: sample.0, at: sample.1)
        return (next, state.1 + (stroked ? 1 : 0))
    }
}

func testStrokeDetectorRecognizesRubbingBackAndForthOnTheHead() throws {
    // 右 → 左 → 右，每段都超过最小距离，1 秒内
    let samples: [(CGFloat, TimeInterval)] = [
        (40, 0.0), (48, 0.1), (56, 0.2),
        (48, 0.3), (40, 0.4),
        (48, 0.5), (56, 0.6),
    ]
    let (_, strokes) = feed(PetStrokeDetector(), samples)
    try expect(strokes == 1, "rubbing back and forth should count as one pat (got \(strokes))")
}

func testStrokeDetectorIgnoresPassingOverTheHead() throws {
    let samples: [(CGFloat, TimeInterval)] = (0..<12).map { (CGFloat(20 + $0 * 6), Double($0) * 0.05) }
    let (_, strokes) = feed(PetStrokeDetector(), samples)
    try expect(strokes == 0, "sliding across the head once is not a pat")
}

func testStrokeDetectorIgnoresJitter() throws {
    // 来回只有 2pt 的手抖
    let samples: [(CGFloat, TimeInterval)] = (0..<20).map { index -> (CGFloat, TimeInterval) in
        let x: CGFloat = index % 2 == 0 ? 40 : 42
        return (x, Double(index) * 0.05)
    }
    let (_, strokes) = feed(PetStrokeDetector(), samples)
    try expect(strokes == 0, "tiny jitter should not count as a pat")
}

func testStrokeDetectorForgetsSlowStrokes() throws {
    // 每段之间隔太久，凑不成一次摸头
    let samples: [(CGFloat, TimeInterval)] = [
        (40, 0.0), (56, 0.2),
        (40, 1.6),
        (56, 3.2),
    ]
    let (_, strokes) = feed(PetStrokeDetector(), samples)
    try expect(strokes == 0, "strokes far apart in time are not a pat")
}

func testStrokeDetectorDoesNotChangeTheOriginal() throws {
    let original = PetStrokeDetector()
    _ = original.feeding(x: 40, at: 0)
    let (afterOne, _) = original.feeding(x: 40, at: 0)
    try expect(afterOne != original, "feeding returns a new detector")
    try expect(original == PetStrokeDetector(), "the original detector stays untouched")
}

func testNapScheduleDozesOffAfterTheUserIsAwayForAWhile() throws {
    let away = PetNapSchedule.napAfterIdle
    var phase = PetNapSchedule.next(.awake, userIdle: away - 1, canNap: true, now: 100)
    try expect(phase == .awake, "stays awake while the user was active recently")

    phase = PetNapSchedule.next(.awake, userIdle: away, canNap: true, now: 100)
    guard case let .dozing(until) = phase else {
        throw TestFailure(message: "should start dozing once the user is away (got \(phase))")
    }
    try expect(until > 100, "dozing lasts a moment")

    phase = PetNapSchedule.next(phase, userIdle: away + 1, canNap: true, now: until)
    try expect(phase == .napping, "falls asleep after dozing")

    phase = PetNapSchedule.next(phase, userIdle: away + 60, canNap: true, now: until + 60)
    try expect(phase == .napping, "keeps napping while the user is away")
}

func testNapScheduleWakesUpWhenTheUserComesBack() throws {
    let phase = PetNapSchedule.next(.napping, userIdle: 0.3, canNap: true, now: 500)
    guard case let .waking(until) = phase else {
        throw TestFailure(message: "user input should wake the pet up (got \(phase))")
    }
    try expect(PetNapSchedule.next(phase, userIdle: 0.5, canNap: true, now: until - 0.1) == phase, "wake-up beat plays out")
    try expect(PetNapSchedule.next(phase, userIdle: 1, canNap: true, now: until) == .awake, "then back to normal")
}

func testNapScheduleNeverNapsWhileBusy() throws {
    let away = PetNapSchedule.napAfterIdle + 100
    try expect(
        PetNapSchedule.next(.awake, userIdle: away, canNap: false, now: 1) == .awake,
        "no napping while peeking from the edge, dragged or showing a reminder"
    )
    try expect(
        PetNapSchedule.next(.napping, userIdle: away, canNap: false, now: 1) == .awake,
        "a reminder popping up wakes the pet right away"
    )
    try expect(
        PetNapSchedule.next(.dozing(until: 5), userIdle: 0.2, canNap: true, now: 1) == .awake,
        "moving the mouse while it is only dozing just opens its eyes"
    )
}

// MARK: - 转头看鼠标

private let gazeBody = CGRect(x: 1000, y: 300, width: 104, height: 116)

private func observe(
    _ tracker: PetGazeTracker,
    _ samples: [(CGPoint, TimeInterval)],
    facingRight: Bool
) -> (PetGazeTracker, [Bool]) {
    samples.reduce((tracker, [Bool]())) { state, sample in
        let (next, turn) = state.0.observing(cursor: sample.0, body: gazeBody, facingRight: facingRight, at: sample.1)
        return (next, state.1 + (turn.map { [$0] } ?? []))
    }
}

func testGazeTurnsTowardACursorThatStaysOnTheOtherSide() throws {
    let right = CGPoint(x: gazeBody.maxX + 120, y: gazeBody.midY)
    let (_, quick) = observe(PetGazeTracker(), [(right, 0), (right, 0.2)], facingRight: false)
    try expect(quick.isEmpty, "a cursor just passing by should not make it turn yet")

    let (_, turns) = observe(PetGazeTracker(), [(right, 0), (right, 0.2), (right, PetGazeTracker.dwell)], facingRight: false)
    try expect(turns == [true], "a cursor lingering on the right should make it face right (got \(turns))")
}

func testGazeIgnoresCursorOnTheBodyFarAwayOrInTheMiddle() throws {
    let cases: [(String, CGPoint)] = [
        ("on the body (patting the head)", CGPoint(x: gazeBody.maxX - 10, y: gazeBody.maxY - 10)),
        ("far across the screen", CGPoint(x: gazeBody.maxX + PetGazeTracker.attentionRadius + 200, y: gazeBody.midY)),
        ("straight above the middle", CGPoint(x: gazeBody.midX + 5, y: gazeBody.maxY + 80)),
    ]
    for (name, cursor) in cases {
        let samples = stride(from: 0.0, through: 3.0, by: 0.2).map { (cursor, $0) }
        let (_, turns) = observe(PetGazeTracker(), samples, facingRight: false)
        try expect(turns.isEmpty, "cursor \(name) should not make it turn (got \(turns))")
    }
}

func testGazeWaitsBetweenTurns() throws {
    let right = CGPoint(x: gazeBody.maxX + 120, y: gazeBody.midY)
    let left = CGPoint(x: gazeBody.minX - 120, y: gazeBody.midY)
    let (afterRight, first) = observe(PetGazeTracker(), [(right, 0), (right, PetGazeTracker.dwell)], facingRight: false)
    try expect(first == [true], "first turn")

    let soon = PetGazeTracker.dwell + 0.1
    let (afterQuick, quick) = observe(afterRight, [(left, soon), (left, soon + PetGazeTracker.dwell)], facingRight: true)
    try expect(quick.isEmpty, "should not flip straight back within the cooldown")

    let later = PetGazeTracker.dwell + PetGazeTracker.cooldown
    let (_, second) = observe(afterQuick, [(left, later)], facingRight: true)
    try expect(second == [false], "turns back once the cooldown is over (got \(second))")
}

func testGazeTrackerDoesNotChangeTheOriginal() throws {
    let original = PetGazeTracker()
    _ = original.observing(cursor: CGPoint(x: 2000, y: 360), body: gazeBody, facingRight: false, at: 0)
    try expect(original == PetGazeTracker(), "observing returns a new tracker")
}

// MARK: - 待机小动作（按权重随机挑，参考 Shimeji）

func testIdleActionScheduleWeighsYuzuWobbleOverBirdVisits() throws {
    let picks = stride(from: 0.0, to: 1.0, by: 0.01).map { PetIdleActionSchedule.pick(random: $0) }
    let wobbles = picks.filter { $0 == .yuzuWobble }.count
    let birds = picks.filter { $0 == .birdVisit }.count
    try expect(wobbles + birds == picks.count, "only idle actions are picked")
    try expect(wobbles > birds && birds > 0, "yuzu wobble is the common one, the bird visit the rarer treat (\(wobbles) vs \(birds))")
}

func testIdleActionScheduleSpacesActionsOut() throws {
    for random in [0.0, 0.5, 0.999] {
        let delay = PetIdleActionSchedule.nextDelay(random: random)
        try expect(
            PetIdleActionSchedule.delayRange.contains(delay),
            "delay \(delay) should stay within \(PetIdleActionSchedule.delayRange)"
        )
    }
    try expect(PetIdleActionSchedule.delayRange.lowerBound >= 20, "small actions should not be constant fidgeting")
}
