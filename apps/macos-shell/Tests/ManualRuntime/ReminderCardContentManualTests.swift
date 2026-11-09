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
    try expect(ReminderCardContent.progressSegments == 10, "ten pixel segments")
    try expect(content.remainingSegments(remaining: 20) == 10, "full at the start")
    try expect(content.remainingSegments(remaining: 14) == 7, "14 of 20 seconds left is 7 segments")
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
        try expect(a.completeTitle == pool.done.first! && b.completeTitle == pool.done.last!, "done button comes from its pool")
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
        for title in pool.done {
            try expect(title.count <= ReminderQuips.maxButtonLength, "button '\(title)' is too long")
        }
    }
    for title in ReminderQuips.later + ReminderQuips.nope {
        try expect(title.count <= ReminderQuips.maxButtonLength, "button '\(title)' is too long")
    }
}
