import Foundation

// 上下班按天统计、今日报告的结论和面板摆放

private let morning: Date = testUTCCalendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 9))!

private func makeTracker() throws -> (HealthSessionTracker, HealthMetricsStore) {
    let store = try HealthMetricsStore(appPaths: try makeTemporaryAppPaths(), calendar: testUTCCalendar)
    return (HealthSessionTracker(store: store), store)
}

private func day(
    work: Int = 0, focus: Int = 0, rest: Int = 0, breaks: Int = 0,
    eye: HealthReminderCounts = .empty, cups: Int = 0
) -> HealthDaySummary {
    HealthDaySummary(
        date: morning, eyeReminder: eye,
        hydrationReminder: HealthReminderCounts(shown: cups, completed: cups, snoozed: 0, skipped: 0),
        workDuration: work, focusCount: 0, focusDuration: focus, breakCount: breaks, breakDuration: rest
    )
}

func testWorkdayAddsUpEveryShiftFromClockInToClockOut() throws {
    let (tracker, store) = try makeTracker()
    // 第一段：上班 2 小时，其中专注 30 分钟、休息 15 分钟
    try tracker.recordStateTransition(from: .idle, to: .working, at: morning)
    try tracker.recordStateTransition(from: .working, to: .focus, at: morning.addingTimeInterval(3600))
    try tracker.recordStateTransition(from: .focus, to: .working, at: morning.addingTimeInterval(5400))
    try tracker.recordStateTransition(from: .working, to: .breakState, at: morning.addingTimeInterval(6300))
    try tracker.recordStateTransition(from: .breakState, to: .idle, at: morning.addingTimeInterval(7200))
    // 第二段：下午再上 3 小时
    let afternoon = morning.addingTimeInterval(5 * 3600)
    try tracker.recordStateTransition(from: .idle, to: .working, at: afternoon)
    try tracker.recordStateTransition(from: .working, to: .idle, at: afternoon.addingTimeInterval(3 * 3600))

    let summary = try store.daySummary(for: morning)
    try expect(summary.onDutyDuration == 5 * 3600, "both shifts count, breaks included (got \(summary.onDutyDuration))")
    try expect(summary.breakDuration == 900, "the break is timed (got \(summary.breakDuration))")
    try expect(summary.focusDuration == 1800, "focus is timed (got \(summary.focusDuration))")
    try expect(summary.shiftCount == 2, "two clock-ins today (got \(summary.shiftCount))")
    try expect(summary.firstClockInAt == morning, "the day starts at the first clock-in")
    try expect(summary.lastClockOutAt == afternoon.addingTimeInterval(3 * 3600), "and ends at the last clock-out")
}

func testWorkdayCheckpointKeepsTodayCurrentWithoutCountingTwice() throws {
    let (tracker, store) = try makeTracker()
    try tracker.recordStateTransition(from: .idle, to: .working, at: morning)
    for minute in 1...90 {
        try tracker.checkpoint(at: morning.addingTimeInterval(Double(minute) * 60 + 0.4))
    }
    let midway = try tracker.todayReport(at: morning.addingTimeInterval(90 * 60 + 0.4))
    try expect(midway.workDuration == 90 * 60, "still working: the report already has the 90 minutes (got \(midway.workDuration))")

    try tracker.recordStateTransition(from: .working, to: .idle, at: morning.addingTimeInterval(2 * 3600))
    let summary = try store.daySummary(for: morning)
    try expect(summary.workDuration == 2 * 3600, "checkpoints plus the clock-out add up exactly (got \(summary.workDuration))")
}

func testWorkdaySkipsTheTimeTheMacWasAsleep() throws {
    let (tracker, store) = try makeTracker()
    try tracker.recordStateTransition(from: .idle, to: .working, at: morning)
    try tracker.suspend(at: morning.addingTimeInterval(3600))
    tracker.resume(at: morning.addingTimeInterval(3 * 3600))
    try tracker.recordStateTransition(from: .working, to: .idle, at: morning.addingTimeInterval(4 * 3600))

    let summary = try store.daySummary(for: morning)
    try expect(summary.workDuration == 2 * 3600, "two hours asleep do not count (got \(summary.workDuration))")
}

func testWorkdayQuittingWhileWorkingClocksOut() throws {
    let (tracker, store) = try makeTracker()
    try tracker.recordStateTransition(from: .idle, to: .working, at: morning)
    try tracker.endSession(at: morning.addingTimeInterval(1800))
    try tracker.endSession(at: morning.addingTimeInterval(3600))

    let summary = try store.daySummary(for: morning)
    try expect(summary.workDuration == 1800, "quitting settles the last stretch once (got \(summary.workDuration))")
    try expect(summary.lastClockOutAt == morning.addingTimeInterval(1800), "and counts as clocking out")
}

func testWorkdayAcrossMidnightStartsTheNewDayAtMidnight() throws {
    let (tracker, store) = try makeTracker()
    let lateNight = morning.addingTimeInterval(14 * 3600)  // 23:00
    try tracker.recordStateTransition(from: .idle, to: .working, at: lateNight)
    try tracker.recordStateTransition(from: .working, to: .idle, at: lateNight.addingTimeInterval(2 * 3600))

    let first = try store.daySummary(for: lateNight)
    let second = try store.daySummary(for: lateNight.addingTimeInterval(2 * 3600))
    try expect(first.workDuration == 3600 && second.workDuration == 3600, "an hour lands on each day")
    try expect(second.firstClockInAt == testUTCCalendar.startOfDay(for: second.date), "the next day starts at midnight")
    try expect(first.lastClockOutAt != nil, "the first day has a clock-out")
}

func testWorkdayLifetimeTotalsEveryDayOnThisMac() throws {
    let appPaths = try makeTemporaryAppPaths()
    let tracker = HealthSessionTracker(store: try HealthMetricsStore(appPaths: appPaths, calendar: testUTCCalendar))
    for offset in 0..<3 {
        let start = morning.addingTimeInterval(Double(offset) * 86_400)
        try tracker.recordStateTransition(from: .idle, to: .working, at: start)
        try tracker.recordStateTransition(from: .working, to: .idle, at: start.addingTimeInterval(8 * 3600))
    }
    let reloaded = try HealthMetricsStore(appPaths: appPaths, calendar: testUTCCalendar)
    let lifetime = try reloaded.lifetimeSummary()
    try expect(lifetime == HealthLifetimeSummary(workedDayCount: 3, onDutyDuration: 24 * 3600), "3 days × 8 hours survive a reload (got \(lifetime))")
}

func testWorkdayReadsOlderMetricsFilesWithoutTheNewFields() throws {
    let appPaths = try makeTemporaryAppPaths()
    let url = appPaths.stateDirectory.appendingPathComponent("health_metrics.json", isDirectory: false)
    try writeText(at: url, contents: #"{"reminders": [], "session_days": {"2026-11-10": {"workDuration": 600, "focusCount": 1, "focusDuration": 60, "breakCount": 0}}}"#)
    let summary = try HealthMetricsStore(appPaths: appPaths, calendar: testUTCCalendar).daySummary(for: morning)
    try expect(summary.workDuration == 600 && summary.shiftCount == 0 && summary.firstClockInAt == nil, "old days still load")
}

func testWorkdaySplitsDaysAtLocalMidnight() throws {
    var shanghai = Calendar(identifier: .gregorian)
    shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let store = try HealthMetricsStore(appPaths: try makeTemporaryAppPaths(), calendar: shanghai)
    // 北京时间 07:30 上班：UTC 还是前一天 23:30
    let start = shanghai.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 7, minute: 30))!
    try store.settleWorkDuration(seconds: 3600, at: start)
    let summary = try store.daySummary(for: start)
    try expect(summary.workDuration == 3600, "the whole hour belongs to the local day (got \(summary.workDuration))")
}

func testTodayAdviceAsksForWaterWhenBehindTheDaysPace() throws {
    // 计划 8 小时 8 杯，上了 4 小时只喝 1 杯：该喝 4 杯
    let advice = TodayAdvice.advise(day: day(work: 4 * 3600, breaks: 1, cups: 1), cupsGoal: 8, workHours: 8)
    try expect(advice.first == TodayAdvice(topic: .water, tone: .act, text: "该补水了，还差 3 杯"), "water comes first (got \(advice))")
}

func testTodayAdviceAsksToRestTheEyes() throws {
    let skipped = HealthReminderCounts(shown: 4, completed: 1, snoozed: 0, skipped: 3)
    let advice = TodayAdvice.advise(day: day(work: 3 * 3600, breaks: 1, eye: skipped, cups: 3), cupsGoal: 8, workHours: 8)
    try expect(advice.map(\.topic) == [.eyes], "eye care is behind (got \(advice))")
    try expect(advice[0].text == "眼睛该放松了，看看远处", "says to relax the eyes")
}

func testTodayAdviceKeepsToTwoLinesAndPraisesAGoodDay() throws {
    let rough = TodayAdvice.advise(day: day(work: 10 * 3600), cupsGoal: 8, workHours: 8)
    try expect(rough.count == TodayAdvice.maxCount, "at most two lines (got \(rough))")
    try expect(rough.allSatisfy { $0.tone == .act }, "all of them things to do")

    let good = HealthReminderCounts(shown: 3, completed: 3, snoozed: 0, skipped: 0)
    let fine = TodayAdvice.advise(day: day(work: 3 * 3600, breaks: 1, eye: good, cups: 8), cupsGoal: 8, workHours: 8)
    try expect(fine.map(\.text) == ["喝水达标了", "护眼做得不错"], "a good day says so (got \(fine))")

    let fresh = TodayAdvice.advise(day: day(work: 600), cupsGoal: 8, workHours: 8)
    try expect(fresh.map(\.topic) == [.allGood], "ten minutes in, nothing to nag about (got \(fresh))")
}

func testTodayReportContentShowsShiftsSpanAndLifetime() throws {
    var summary = day(work: 5 * 3600, rest: 900, breaks: 1, cups: 2)
    summary.shiftCount = 2
    summary.firstClockInAt = morning.addingTimeInterval(12 * 60)
    summary.lastClockOutAt = morning.addingTimeInterval(9 * 3600 + 30 * 60)
    let lifetime = HealthLifetimeSummary(workedDayCount: 12, onDutyDuration: 86 * 3600 + 30 * 60)

    let done = TodayReportContent(day: summary, lifetime: lifetime, cupsGoal: 6, workHours: 8, isOnDuty: false, calendar: testUTCCalendar)
    let values = Dictionary(uniqueKeysWithValues: done.rows.map { ($0.label, $0.value) })
    try expect(values["上班"] == "5:15 · 2 段", "on duty adds work and break time (got \(values))")
    try expect(values["时段"] == "09:12–18:30", "first clock-in to last clock-out (got \(values))")
    try expect(values["休息"] == "1 次 · 0:15", "breaks show their time (got \(values))")
    try expect(values["喝水"] == "2/6 杯", "cups against the goal (got \(values))")
    try expect(done.footer == "累计 12 天 · 86:30", "lifetime on this Mac (got \(String(describing: done.footer)))")
    try expect(done.accessibilityText.hasPrefix("今日报告：该补水了"), "the conclusion is read first (got \(done.accessibilityText))")

    let working = TodayReportContent(day: summary, lifetime: nil, cupsGoal: 6, workHours: 8, isOnDuty: true, calendar: testUTCCalendar)
    try expect(working.rows.contains { $0.value == "09:12–现在" }, "still on duty reads 现在")
    try expect(working.footer == nil, "no lifetime, no footer")
}

func testReportPanelSitsBesideThePetTowardTheScreenCenter() throws {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let size = CGSize(width: 232, height: 260)

    let bottomRight = CGRect(x: 1300, y: 20, width: 120, height: 100)
    let left = ReportPanelPlacement.frame(size: size, beside: bottomRight, in: screen)
    try expect(left.maxX == bottomRight.minX - ReportPanelPlacement.gap, "pet on the right: report on its left (got \(left))")
    try expect(left.minY == screen.minY, "kept on screen even though the pet is low (got \(left))")
    try expect(!left.intersects(bottomRight), "does not cover the pet")

    let topLeft = CGRect(x: 10, y: 760, width: 120, height: 100)
    let right = ReportPanelPlacement.frame(size: size, beside: topLeft, in: screen)
    try expect(right.minX == topLeft.maxX + ReportPanelPlacement.gap && screen.contains(right), "pet on the left: report on its right (got \(right))")

    let squeezed = CGRect(x: 0, y: 0, width: 300, height: 875)
    let wide = CGRect(x: 40, y: 300, width: 220, height: 100)
    let above = ReportPanelPlacement.frame(size: size, beside: wide, in: squeezed)
    try expect(above.minY == wide.maxY + ReportPanelPlacement.gap, "no room at the sides: goes above (got \(above))")

    let button = CGRect(x: 1400, y: 875, width: 24, height: 24)
    let menuBar = ReportPanelPlacement.frame(size: size, below: button, in: screen)
    try expect(menuBar.maxX == button.maxX && menuBar.maxY == button.minY - 6, "menu bar: hangs under the button, growing left (got \(menuBar))")
}
