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

/// 用户 2026-11-09：「豚鼠有时候左右会突然转换」。只理离得近、停得久的鼠标，转完一次歇好一阵
func testGazeOnlyMindsACursorThatIsCloseAndLingers() throws {
    try expect(PetGazeTracker.attentionRadius <= 240, "only a cursor right next to it counts (radius \(PetGazeTracker.attentionRadius))")
    try expect(PetGazeTracker.dwell >= 1.2, "the cursor has to stay put a good second (dwell \(PetGazeTracker.dwell))")
    try expect(PetGazeTracker.cooldown >= 4, "turns are seconds apart (cooldown \(PetGazeTracker.cooldown))")
    try expect(PetGazeTracker.homeDwell > PetGazeTracker.dwell, "after the cursor leaves it lingers before turning back")

    let nearby = CGPoint(x: gazeBody.maxX + 120, y: gazeBody.midY)
    let polls = stride(from: 0.0, to: PetGazeTracker.dwell, by: 0.2).map { (nearby, $0) }
    let (_, early) = observe(PetGazeTracker(), polls, facingRight: false)
    try expect(early.isEmpty, "polled again and again, it still waits out the whole dwell (got \(early))")
    let farther = CGPoint(x: gazeBody.midX + PetGazeTracker.attentionRadius + 20, y: gazeBody.midY)
    let (_, ignored) = observe(PetGazeTracker(), [(farther, 0), (farther, 5)], facingRight: false)
    try expect(ignored.isEmpty, "a cursor just outside the radius is ignored")
}

func testGazeTurnsTowardACursorThatStaysOnTheOtherSide() throws {
    let right = CGPoint(x: gazeBody.maxX + 120, y: gazeBody.midY)
    let (_, quick) = observe(PetGazeTracker(), [(right, 0), (right, PetGazeTracker.dwell - 0.2)], facingRight: false)
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

func testGazeHomeFacingLooksTowardTheMiddleOfTheScreen() throws {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let onRight = CGRect(x: 1200, y: 100, width: 104, height: 116)
    let onLeft = CGRect(x: 80, y: 100, width: 104, height: 116)
    try expect(PetGazeTracker.homeFacingRight(body: onRight, screen: screen) == false, "on the right half it should sit facing left")
    try expect(PetGazeTracker.homeFacingRight(body: onLeft, screen: screen) == true, "on the left half it should sit facing right")
}

func testGazeTurnsBackHomeOnceTheCursorWandersOff() throws {
    let far = CGPoint(x: gazeBody.maxX + PetGazeTracker.attentionRadius + 300, y: gazeBody.midY)
    let goHome = { (samples: [(CGPoint, TimeInterval)]) -> [Bool] in
        samples.reduce((PetGazeTracker(), [Bool]())) { state, sample in
            let (next, turn) = state.0.observing(cursor: sample.0, body: gazeBody, facingRight: true, homeFacingRight: false, at: sample.1)
            return (next, state.1 + (turn.map { [$0] } ?? []))
        }.1
    }
    let soon = goHome([(far, 0.0), (far, PetGazeTracker.dwell)])
    try expect(soon.isEmpty, "it does not spin back the moment the cursor leaves (got \(soon))")
    let turns = goHome([(far, 0.0), (far, PetGazeTracker.dwell), (far, PetGazeTracker.homeDwell)])
    try expect(turns == [false], "with the cursor gone a while it should turn back toward the middle of the screen (got \(turns))")

    let onBody = CGPoint(x: gazeBody.midX, y: gazeBody.midY)
    let (_, petting) = [(onBody, 0.0), (onBody, 2.0), (onBody, 3.0)].reduce((PetGazeTracker(), [Bool]())) { state, sample in
        let (next, turn) = state.0.observing(cursor: sample.0, body: gazeBody, facingRight: true, homeFacingRight: false, at: sample.1)
        return (next, state.1 + (turn.map { [$0] } ?? []))
    }
    try expect(petting.isEmpty, "while the cursor rests on it (petting) it should not spin around")
}

func testGazeTrackerDoesNotChangeTheOriginal() throws {
    let original = PetGazeTracker()
    _ = original.observing(cursor: CGPoint(x: 2000, y: 360), body: gazeBody, facingRight: false, at: 0)
    try expect(original == PetGazeTracker(), "observing returns a new tracker")
}

// MARK: - 待机小动作（按权重随机挑，参考 Shimeji）

func testIdleActionScheduleWeighsYuzuWobbleOverBirdVisits() throws {
    let picks = stride(from: 0.0, to: 1.0, by: 0.01).map { PetIdleActionSchedule.pick(random: $0) }
    let count = { (clip: PetActionClip) in picks.filter { $0 == clip }.count }
    let idleActs: [PetActionClip] = [.yuzuWobble, .birdVisit, .sunbathe, .bath]
    try expect(idleActs.map(count).reduce(0, +) == picks.count, "only idle actions are picked")
    for rarer in [PetActionClip.birdVisit, .sunbathe, .bath] {
        try expect(count(.yuzuWobble) > count(rarer) && count(rarer) > 0, "yuzu wobble is the common one, \(rarer) a rarer treat (\(count(.yuzuWobble)) vs \(count(rarer)))")
    }
}

/// 晒太阳、泡澡：idle_act/ 下 8 帧一轮，慢慢放（4 fps）多放几遍，不是一闪而过
func testSunbathingAndBathingAreSlowIdleActs() throws {
    for (clip, name) in [(PetActionClip.sunbathe, "sunbathe"), (.bath, "bath")] {
        try expect(clip.directory == "idle_act" && !clip.loops && !clip.isPokeReaction, "\(name) is an idle act")
        try expect(clip.frameNames == (0..<8).map { "\(name)_\($0).png" }, "\(name) has the 8 frames the pipeline draws")
        try expect(clip.framesPerSecond == 4 && clip.duration == 6, "\(name) plays slowly, three rounds (got \(clip.duration)s)")
    }
    let capybara = inferredManualTestRepoRootURL().appendingPathComponent("assets/pets/capybara", isDirectory: true)
    let outfits = (try? FileManager.default.contentsOfDirectory(atPath: capybara.appendingPathComponent("outfits").path)) ?? []
    for root in [capybara] + outfits.map({ capybara.appendingPathComponent("outfits/\($0)", isDirectory: true) }) {
        let files = Set((try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("idle_act").path)) ?? [])
        let missing = (PetActionClip.sunbathe.frameNames + PetActionClip.bath.frameNames).filter { !files.contains($0) }
        try expect(missing.isEmpty, "\(root.lastPathComponent)/idle_act is missing \(missing)")
    }
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

// MARK: - 戳一下

func testPokeZonesFollowTheSittingCapybara() throws {
    // 侧身坐姿、脸朝左的 32×32 素材格子
    let cases: [(CGFloat, CGFloat, PetPokeZone, String)] = [
        (2, 12, .nose, "the snout"),
        (11, 10, .head, "the forehead"),
        (10, 2, .head, "the orange on its head"),
        (14, 22, .belly, "the round tummy"),
        (25, 18, .back, "the back"),
        (26, 25, .back, "the bottom"),
        (11, 29, .legs, "a front paw"),
        (19, 30, .legs, "a hind foot"),
    ]
    for (x, y, expected, part) in cases {
        let zone = PetPokeZone.zone(spriteX: x, spriteY: y)
        try expect(zone == expected, "poking \(part) at (\(x), \(y)) should be \(expected) (got \(zone))")
    }
}

func testPokeZoneMapsViewPointsAndMirrorsWhenFacingRight() throws {
    let imageRect = CGRect(x: 0, y: 24, width: 128, height: 128)
    // 素材格子 (2, 12)：脸朝左时是鼻子；视图 y 向上，所以从顶边往下数
    let point = CGPoint(x: 2.5 * 4, y: imageRect.maxY - 12.5 * 4)
    try expect(PetPokeZone.zone(at: point, imageRect: imageRect, facingRight: false) == .nose, "the snout on the left")
    try expect(
        PetPokeZone.zone(at: point, imageRect: imageRect, facingRight: true) == .back,
        "facing right the picture is mirrored: the left edge is its back"
    )
    try expect(
        PetPokeZone.zone(at: CGPoint(x: 64, y: 10), imageRect: imageRect, facingRight: false) == nil,
        "below the picture is not the pet"
    )
}

func testEveryPokeZoneHasItsOwnReaction() throws {
    let reactions = PetPokeZone.allCases.map(\.reaction)
    try expect(Set(reactions.map { "\($0)" }).count == PetPokeZone.allCases.count, "each part reacts differently")
    try expect(PetPokeZone.belly.reaction == .tickled, "the belly is ticklish")
    try expect(PetPokeZone.legs.reaction == .annoyed, "poking its legs is annoying")
    try expect(PetPokeZone.nose.reaction == .sneezed, "poking its nose makes it sneeze")
    try expect(PetPokeZone.back.reaction == .startled, "poking its back makes it jump")
}

func testPokeTrackerGetsGrumpyAfterTooManyPokesInAShortTime() throws {
    var tracker = PetPokeTracker()
    var results: [Bool] = []
    for index in 0..<PetPokeTracker.overdoneCount {
        let (next, overdone) = tracker.registering(at: 100 + Double(index) * 0.5)
        tracker = next
        results.append(overdone)
    }
    try expect(results == Array(repeating: false, count: PetPokeTracker.overdoneCount - 1) + [true], "the \(PetPokeTracker.overdoneCount)th quick poke is one too many (got \(results))")
    let (_, again) = tracker.registering(at: 103)
    try expect(!again, "after getting cross it starts counting from zero")
}

func testPokeTrackerForgetsPokesSpreadOut() throws {
    var tracker = PetPokeTracker()
    for index in 0..<(PetPokeTracker.overdoneCount * 2) {
        let (next, overdone) = tracker.registering(at: Double(index) * (PetPokeTracker.window / 2 + 0.1))
        tracker = next
        try expect(!overdone, "an occasional poke never makes it cross (poke \(index))")
    }
}

func testPokeTrackerDoesNotChangeTheOriginal() throws {
    let original = PetPokeTracker()
    let (next, _) = original.registering(at: 1)
    try expect(next != original && original == PetPokeTracker(), "registering returns a new tracker")
}

/// App 里写死的帧数要和像素生成器（poke-reactions.mjs）生成的一致，每套装扮都有
func testPokeReactionFramesExistInTheRepoAssets() throws {
    let capybara = inferredManualTestRepoRootURL()
        .appendingPathComponent("assets/pets/capybara", isDirectory: true)
    let outfits = (try? FileManager.default.contentsOfDirectory(atPath: capybara.appendingPathComponent("outfits").path)) ?? []
    let roots = [capybara] + outfits.map { capybara.appendingPathComponent("outfits/\($0)", isDirectory: true) }
    let reactions = PetActionClip.allCases.filter(\.isPokeReaction)
    try expect(reactions.count == 5, "five poke reactions")
    for root in roots {
        let react = root.appendingPathComponent("react", isDirectory: true)
        let files = Set((try? FileManager.default.contentsOfDirectory(atPath: react.path)) ?? [])
        for clip in reactions {
            let missing = clip.frameNames.filter { !files.contains($0) }
            try expect(missing.isEmpty, "\(react.path) is missing \(missing)")
            let prefix = String(clip.frameNames[0].dropLast("0.png".count))
            let generated = files.filter { $0.hasPrefix(prefix) }.count
            try expect(generated == clip.frameNames.count, "\(clip) plays \(clip.frameNames.count) frames but \(generated) were generated in \(react.lastPathComponent)")
        }
    }
}
