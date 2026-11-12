import Foundation

private func payload(_ type: HealthReminderType, rest: TimeInterval = 20) -> ReminderPresentationPayload {
    ReminderPresentationPayload(id: UUID(), type: type, text: "x", restSeconds: rest)
}

private let first: (Int) -> Int = { _ in 0 }
private let last: (Int) -> Int = { $0 - 1 }

func testReminderCardContentShowsWhichCupThisIs() throws {
    let content = ReminderCardContent(payload: payload(.hydration), cups: CupProgress(done: 3, goal: 6), pick: first)
    try expect(content.symbol == .drop, "water reminders show a drop")
    try expect(content.detail(remaining: 0) == "第 4/6 杯", "the next cup out of today's goal (got \(content.detail(remaining: 0)))")
    try expect(!content.showsCountdown, "water reminders have no countdown")
}

func testReminderCardContentCheersPastTheGoalAndCopesWithoutData() throws {
    let past = ReminderCardContent(payload: payload(.hydration), cups: CupProgress(done: 6, goal: 6), pick: first)
    try expect(past.detail(remaining: 0) == "超额 1 杯", "past the goal (got \(past.detail(remaining: 0)))")

    let unknown = ReminderCardContent(payload: payload(.hydration), cups: nil, pick: first)
    try expect(unknown.detail(remaining: 0) == "小口慢慢喝", "no summary yet (got \(unknown.detail(remaining: 0)))")
}

func testReminderCardContentCountsDownTheLookAway() throws {
    let content = ReminderCardContent(payload: payload(.eyeCare, rest: 20), cups: nil, pick: first)
    try expect(content.symbol == .eye, "eye reminders show an eye")
    try expect(content.showsCountdown && content.restSeconds == 20, "counts down the 20 seconds")
    try expect(content.detail(remaining: 14) == "还剩 14 秒", "seconds left (got \(content.detail(remaining: 14)))")
}

func testReminderCardContentUsesMinutesForTheHourlyBreak() throws {
    let content = ReminderCardContent(payload: payload(.eyeCare, rest: 300), cups: nil, pick: first)
    try expect(content.detail(remaining: 252) == "还剩 4:12", "minutes and seconds left (got \(content.detail(remaining: 252)))")
    try expect(content.detail(remaining: -3) == "还剩 0 秒", "never negative (got \(content.detail(remaining: -3)))")
}

func testReminderCardContentFillsProgressSegmentsAsTimeRunsOut() throws {
    let content = ReminderCardContent(payload: payload(.eyeCare, rest: 20), cups: nil, pick: first)
    try expect(ReminderCardContent.progressSegments == 20, "twenty pixel segments")
    try expect(content.remainingSegments(remaining: 20) == 20, "full at the start")
    try expect(content.remainingSegments(remaining: 14) == 14, "14 of 20 seconds left is 14 segments")
    try expect(content.remainingSegments(remaining: 0.5) == 1, "the last segment stays until time is up")
    try expect(content.remainingSegments(remaining: 0) == 0, "empty at the end")
}

func testReminderCardContentPicksPlayfulLinesFromTheRightPool() throws {
    let cases: [(ReminderPresentationPayload, ReminderQuips.Pool)] = [
        (payload(.hydration), ReminderQuips.hydration),
        (payload(.eyeCare, rest: 20), ReminderQuips.lookAway),
        (payload(.eyeCare, rest: 300), ReminderQuips.standUp),
    ]
    for (reminder, pool) in cases {
        let a = ReminderCardContent(payload: reminder, cups: nil, pick: first)
        let b = ReminderCardContent(payload: reminder, cups: nil, pick: last)
        try expect(a.title == pool.lines.first! && b.title == pool.lines.last!, "title comes from the line pool (got \(a.title) / \(b.title))")
        // 喝水的主按钮是「我喝了」；护眼的主按钮是「开始休息」（点了才全屏倒计时）
        let primary = reminder.type == .eyeCare ? pool.start : pool.done
        try expect(a.completeTitle == primary.first! && b.completeTitle == primary.last!, "the main button comes from its pool (got \(a.completeTitle))")
        try expect(a.snoozeTitle == ReminderQuips.later.first! && b.snoozeTitle == ReminderQuips.later.last!, "snooze from the shared pool")
        try expect(a.skipTitle == ReminderQuips.nope.first! && b.skipTitle == ReminderQuips.nope.last!, "skip from the shared pool")
    }
}

func testReminderQuipsAreVariedAndShortEnoughForTheCard() throws {
    try expect(ReminderQuips.nope.first == "我就不", "the signature skip line is 我就不")
    for pool in [ReminderQuips.hydration, ReminderQuips.lookAway, ReminderQuips.standUp] {
        try expect(pool.lines.count >= 5 && pool.done.count >= 2, "each pool needs enough variety")
        for line in pool.lines {
            try expect(line.count <= ReminderQuips.maxLineLength, "line '\(line)' is too long for the card")
        }
        for title in pool.done + pool.start {
            try expect(title.count <= ReminderQuips.maxButtonLength, "button '\(title)' is too long")
        }
    }
    for title in ReminderQuips.later + ReminderQuips.nope {
        try expect(title.count <= ReminderQuips.maxButtonLength, "button '\(title)' is too long")
    }
}

func testReminderCardContentSaysWhatTheMainButtonDoes() throws {
    let water = ReminderCardContent(payload: payload(.hydration), cups: CupProgress(done: 3, goal: 6), pick: first)
    try expect(!water.startsRest && water.scene == .remind(.hydration), "water is confirmed on the card; the pet drinks along")
    try expect(water.summary == "第 4/6 杯" && water.hint == "喝完点一下，水豚帮你记上", "water card copy (got \(water.summary) / \(water.hint))")

    let look = ReminderCardContent(payload: payload(.eyeCare, rest: 20), cups: nil, pick: first)
    try expect(look.startsRest && !look.isLongRest && look.scene == .remind(.eyeCare), "eye care starts a rest; the pet looks away")
    try expect(look.summary == "看 6 米外的远处 20 秒", "says how long to look away (got \(look.summary))")
    try expect(look.hint == "点开始，屏幕会先帮你挡一会儿" && look.restTitle == "看看 6 米外的远处", "tells you the screen gets covered")

    let walk = ReminderCardContent(payload: payload(.eyeCare, rest: 300), cups: nil, pick: first)
    try expect(walk.isLongRest && walk.summary == "离开屏幕歇 5 分钟" && walk.restTitle == "起来走走，离开屏幕", "the hourly break is in minutes (got \(walk.summary))")
    try expect(PetScene.remind(.hydration).name == "drink" && PetScene.remind(.eyeCare).name == "look_away", "scene names match the manifest")
    try expect(!PetScene.remind(.eyeCare).isOneShot && PetScene.remind(.eyeCare).facesSideways, "reminder scenes loop, side-on like idle")
}

func testReminderStageSitsInTheMiddleOfTheScreen() throws {
    let visible = CGRect(x: 100, y: 50, width: 1440, height: 800)
    let frame = ReminderStageRules.frame(size: CGSize(width: 432, height: 204), in: visible)
    try expect(frame.midX == visible.midX, "centred left to right (got \(frame))")
    try expect(abs(frame.midY - visible.midY) < visible.height * 0.1 && frame.midY > visible.midY, "a little above the middle (got \(frame))")

    let tiny = ReminderStageRules.frame(size: CGSize(width: 432, height: 204), in: CGRect(x: 0, y: 0, width: 300, height: 150))
    try expect(tiny.origin == .zero, "a screen smaller than the card pins it to the corner instead of pushing it off (got \(tiny))")
}

func testEyeRestEndedEarlyCountsOnlyWhenHalfDone() throws {
    try expect(ReminderStageRules.restOutcome(rested: 20, total: 20) == .completed, "the whole rest counts")
    try expect(ReminderStageRules.restOutcome(rested: 10, total: 20) == .completed, "half the rest still counts")
    try expect(ReminderStageRules.restOutcome(rested: 9, total: 20) == .skipped, "less than half is a skip")
    try expect(ReminderStageRules.unansweredTimeout >= 60, "the card waits at least a minute before giving up")
}
