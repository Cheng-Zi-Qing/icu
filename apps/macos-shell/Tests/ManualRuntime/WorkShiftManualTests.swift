import Foundation

// 逐段上下班打卡：每一段都留下来，App 被强退也不丢

private let nineAM: Date = testUTCCalendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 9))!

private func minutes(_ count: Double) -> TimeInterval { count * 60 }

private func makeShiftTracker(_ appPaths: AppPaths) throws -> (HealthSessionTracker, HealthMetricsStore) {
    let store = try HealthMetricsStore(appPaths: appPaths, calendar: testUTCCalendar)
    return (HealthSessionTracker(store: store), store)
}

func testShiftsKeepEveryClockInAndClockOutOfTheDay() throws {
    let (tracker, store) = try makeShiftTracker(try makeTemporaryAppPaths())
    try tracker.recordStateTransition(from: .idle, to: .working, at: nineAM)
    try tracker.recordStateTransition(from: .working, to: .idle, at: nineAM.addingTimeInterval(minutes(120)))
    try tracker.recordStateTransition(from: .idle, to: .working, at: nineAM.addingTimeInterval(minutes(240)))
    try tracker.recordStateTransition(from: .working, to: .breakState, at: nineAM.addingTimeInterval(minutes(300)))
    try tracker.recordStateTransition(from: .breakState, to: .idle, at: nineAM.addingTimeInterval(minutes(330)))

    let shifts = try store.daySummary(for: nineAM).shifts
    try expect(shifts.count == 2, "one record per clock-in (got \(shifts.count))")
    try expect(shifts[0].clockInAt == nineAM && shifts[0].clockOutAt == nineAM.addingTimeInterval(minutes(120)), "first shift 09:00–11:00 (got \(shifts[0]))")
    try expect(shifts[1].clockInAt == nineAM.addingTimeInterval(minutes(240)), "second shift starts at 13:00 (got \(shifts[1]))")
    try expect(shifts[1].clockOutAt == nineAM.addingTimeInterval(minutes(330)), "a break inside a shift does not end it (got \(shifts[1]))")
    try expect(!shifts.contains(where: \.endedUnexpectedly), "both were clocked out by hand")
}

func testShiftLeftOpenByAKillIsClosedAtTheLastMinuteSeen() throws {
    let appPaths = try makeTemporaryAppPaths()
    let (firstRun, _) = try makeShiftTracker(appPaths)
    try firstRun.recordStateTransition(from: .idle, to: .working, at: nineAM)
    for minute in 1...52 {
        try firstRun.checkpoint(at: nineAM.addingTimeInterval(minutes(Double(minute))))
    }
    // 被强退：没有下班打卡。重新打开
    let (secondRun, store) = try makeShiftTracker(appPaths)
    let closed = try secondRun.closeInterruptedShifts()

    let day = try store.daySummary(for: nineAM)
    try expect(closed == 1, "the open shift is closed on launch (got \(closed))")
    try expect(day.shifts.count == 1, "the record survives the kill (got \(day.shifts.count))")
    try expect(day.shifts[0].clockOutAt == nineAM.addingTimeInterval(minutes(52)), "clock-out is the last minute seen (got \(day.shifts[0]))")
    try expect(day.shifts[0].endedUnexpectedly, "and is marked as an unexpected quit")
    try expect(day.lastClockOutAt == nineAM.addingTimeInterval(minutes(52)), "the day's last clock-out follows (got \(String(describing: day.lastClockOutAt)))")
    try expect(day.workDuration == Int(minutes(52)), "worked time is untouched (got \(day.workDuration))")
    let closedAgain = try secondRun.closeInterruptedShifts()
    try expect(closedAgain == 0, "closing again changes nothing")
}

func testClockingInAgainAfterAKillKeepsTheEarlierShift() throws {
    let appPaths = try makeTemporaryAppPaths()
    let (firstRun, _) = try makeShiftTracker(appPaths)
    try firstRun.recordStateTransition(from: .idle, to: .working, at: nineAM)
    try firstRun.checkpoint(at: nineAM.addingTimeInterval(minutes(30)))
    // 被强退后没走启动补卡（比如老版本），直接再上班
    let (secondRun, store) = try makeShiftTracker(appPaths)
    try secondRun.recordStateTransition(from: .idle, to: .working, at: nineAM.addingTimeInterval(minutes(45)))

    let day = try store.daySummary(for: nineAM)
    try expect(day.shiftCount == 2 && day.shifts.count == 2, "two clock-ins, two records (got \(day.shifts))")
    try expect(day.shifts[0].clockOutAt == nineAM.addingTimeInterval(minutes(30)) && day.shifts[0].endedUnexpectedly, "the killed shift is closed at its last minute (got \(day.shifts[0]))")
    try expect(day.shifts[1].isOpen, "the new shift is running")
}

func testShiftsSplitAtMidnightLikeTheDays() throws {
    let (tracker, store) = try makeShiftTracker(try makeTemporaryAppPaths())
    let lateNight = nineAM.addingTimeInterval(14 * 3600)  // 23:00
    try tracker.recordStateTransition(from: .idle, to: .working, at: lateNight)
    try tracker.recordStateTransition(from: .working, to: .idle, at: lateNight.addingTimeInterval(2 * 3600))

    let first = try store.daySummary(for: lateNight).shifts
    let second = try store.daySummary(for: lateNight.addingTimeInterval(2 * 3600)).shifts
    try expect(first.count == 1 && first[0].clockOutAt != nil && !first[0].isOpen, "the night's shift ends at midnight (got \(first))")
    try expect(second.count == 1 && second[0].clockOutAt == lateNight.addingTimeInterval(2 * 3600), "the new day has its own shift (got \(second))")
}

func testTodayReportListsEveryShiftAndMarksTheInterruptedOne() throws {
    var summary = HealthDaySummary(
        date: nineAM, eyeReminder: .empty, hydrationReminder: .empty,
        workDuration: 4 * 3600, focusCount: 0, focusDuration: 0, breakCount: 0
    )
    summary.shiftCount = 3
    summary.shifts = [
        WorkShift(clockInAt: nineAM.addingTimeInterval(minutes(120)), clockOutAt: nineAM.addingTimeInterval(minutes(180)), endedUnexpectedly: true),
        WorkShift(clockInAt: nineAM, clockOutAt: nineAM.addingTimeInterval(minutes(100))),
        WorkShift(clockInAt: nineAM.addingTimeInterval(minutes(200))),
    ]

    let working = TodayReportContent(day: summary, lifetime: nil, cupsGoal: 6, workHours: 8, isOnDuty: true, calendar: testUTCCalendar)
    let shiftRows = working.rows.filter { $0.kind == .shift }
    try expect(shiftRows.map(\.value) == ["09:00–10:40", "11:00–12:00 意外退出", "12:20–现在"], "one row per shift in order (got \(shiftRows.map(\.value)))")
    try expect(shiftRows.map(\.label) == ["打卡", "", ""], "the label only on the first row (got \(shiftRows.map(\.label)))")
    try expect(!working.rows.contains { $0.kind == .span }, "the shifts replace the single span row")
    try expect(working.detailRows.filter { $0.kind == .shift }.count == 3, "all shifts are drawn")
}

func testTodayReportKeepsTheClockInOfAnOldDayWithoutShifts() throws {
    var summary = HealthDaySummary(
        date: nineAM, eyeReminder: .empty, hydrationReminder: .empty,
        workDuration: 3600, focusCount: 0, focusDuration: 0, breakCount: 0
    )
    summary.shiftCount = 1
    summary.firstClockInAt = nineAM

    let content = TodayReportContent(day: summary, lifetime: nil, cupsGoal: 6, workHours: 8, isOnDuty: false, calendar: testUTCCalendar)
    try expect(content.rows.contains { $0.kind == .span && $0.value == "09:00 起" }, "no clock-out recorded: still shows when work began (got \(content.rows))")
}

func testTodayReportKeepsTheSpanWhenOlderShiftsHaveNoRecords() throws {
    var summary = HealthDaySummary(
        date: nineAM, eyeReminder: .empty, hydrationReminder: .empty,
        workDuration: 3 * 3600, focusCount: 0, focusDuration: 0, breakCount: 0
    )
    // 上午两段是老版本记的（没有逐段打卡），下午这段有
    summary.shiftCount = 3
    summary.firstClockInAt = nineAM
    summary.lastClockOutAt = nineAM.addingTimeInterval(minutes(300))
    summary.shifts = [WorkShift(clockInAt: nineAM.addingTimeInterval(minutes(240)), clockOutAt: nineAM.addingTimeInterval(minutes(300)))]

    let content = TodayReportContent(day: summary, lifetime: nil, cupsGoal: 6, workHours: 8, isOnDuty: false, calendar: testUTCCalendar)
    try expect(content.rows.contains { $0.kind == .span && $0.value == "09:00–14:00" }, "the morning is not hidden (got \(content.rows))")
    try expect(content.rows.filter { $0.kind == .shift }.map(\.value) == ["13:00–14:00"], "the recorded shift is listed (got \(content.rows))")
}
