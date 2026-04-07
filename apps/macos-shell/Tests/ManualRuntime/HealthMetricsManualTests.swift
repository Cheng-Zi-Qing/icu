import Foundation

func testHealthMetricsStorePersistsReminderEventsAndIgnoresDuplicateOutcomes() throws {
    let appPaths = try makeTemporaryAppPaths()
    let shownAt = Date(timeIntervalSince1970: 1_744_000_000)
    let reminderID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    do {
        let store = try HealthMetricsStore(appPaths: appPaths)
        try store.recordReminderShown(id: reminderID, type: .eyeCare, at: shownAt)
        try store.recordReminderOutcome(id: reminderID, outcome: .completed, at: shownAt.addingTimeInterval(30))
        try store.recordReminderOutcome(id: reminderID, outcome: .skipped, at: shownAt.addingTimeInterval(60))
    }

    let reloadedStore = try HealthMetricsStore(appPaths: appPaths)
    let summary = try reloadedStore.daySummary(for: shownAt)

    try expect(summary.eyeReminder.shown == 1, "shown count should persist")
    try expect(summary.eyeReminder.completed == 1, "first terminal outcome should win")
    try expect(summary.eyeReminder.skipped == 0, "duplicate outcome should be ignored")
}

func testHealthMetricsStoreBuildsWeekSummaryFromMultipleDays() throws {
    let appPaths = try makeTemporaryAppPaths()
    let store = try HealthMetricsStore(appPaths: appPaths)
    let firstDay = Date(timeIntervalSince1970: 1_744_000_000)
    let secondDay = firstDay.addingTimeInterval(86_400)

    try store.recordReminderShown(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        type: .eyeCare,
        at: firstDay
    )
    try store.recordReminderOutcome(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        outcome: .completed,
        at: firstDay.addingTimeInterval(30)
    )

    try store.recordReminderShown(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        type: .eyeCare,
        at: secondDay
    )
    try store.recordReminderOutcome(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        outcome: .skipped,
        at: secondDay.addingTimeInterval(30)
    )

    try store.recordReminderShown(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        type: .eyeCare,
        at: secondDay.addingTimeInterval(120)
    )
    try store.recordReminderOutcome(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        outcome: .completed,
        at: secondDay.addingTimeInterval(150)
    )

    let summary = try store.weekSummary(containing: secondDay)

    try expect(summary.eyeReminder.shown == 3, "week summary should total shown reminders")
    try expect(summary.eyeReminder.completed == 2, "week summary should total completed reminders")
    try expect(summary.eyeReminder.skipped == 1, "week summary should total skipped reminders")
    try expect(abs(summary.eyeReminderCompletionRate - (2.0 / 3.0)) < 0.0001, "week completion rate should use completed/shown")
    try expect(
        summary.weekEndExclusiveDate == summary.weekStartDate.addingTimeInterval(7 * 86_400),
        "week summary should expose an exclusive end date"
    )
}

func testHealthMetricsStoreRecoversFromCorruptMetricsFileAndRecordsDiagnostic() throws {
    let appPaths = try makeTemporaryAppPaths()
    let metricsURL = appPaths.stateDirectory.appendingPathComponent("health_metrics.json", isDirectory: false)
    try writeTextFile("{not valid json", to: metricsURL)

    var diagnostics: [String] = []
    let store = try HealthMetricsStore(appPaths: appPaths) { message in
        diagnostics.append(message)
    }

    let summary = try store.daySummary(for: Date(timeIntervalSince1970: 1_744_000_000))
    try expect(summary.eyeReminder.shown == 0, "corrupt metrics should recover as empty metrics")

    let stateFiles = try FileManager.default.contentsOfDirectory(
        at: appPaths.stateDirectory,
        includingPropertiesForKeys: nil
    )
    let backupExists = stateFiles.contains { fileURL in
        fileURL.lastPathComponent.hasPrefix("health_metrics.corrupt-")
    }

    try expect(backupExists, "corrupt metrics should be renamed aside for diagnostics")
    try expect(
        diagnostics.contains(where: { $0.contains("corrupt") }),
        "store should emit diagnostics for corrupt metrics recovery"
    )
}

func testHealthMetricsStoreEmitsDiagnosticsForIgnoredInvalidEvents() throws {
    let appPaths = try makeTemporaryAppPaths()
    var diagnostics: [String] = []
    let store = try HealthMetricsStore(appPaths: appPaths) { message in
        diagnostics.append(message)
    }

    let shownAt = Date(timeIntervalSince1970: 1_744_000_000)
    let reminderID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let unknownID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

    try store.recordReminderShown(id: reminderID, type: .eyeCare, at: shownAt)
    try store.recordReminderShown(id: reminderID, type: .eyeCare, at: shownAt.addingTimeInterval(10))
    try store.recordReminderOutcome(id: unknownID, outcome: .completed, at: shownAt.addingTimeInterval(20))
    try store.recordReminderOutcome(id: reminderID, outcome: .completed, at: shownAt.addingTimeInterval(30))
    try store.recordReminderOutcome(id: reminderID, outcome: .skipped, at: shownAt.addingTimeInterval(40))

    try expect(
        diagnostics.contains(where: { $0.contains("duplicate shown") }),
        "store should emit diagnostics for duplicate shown events"
    )
    try expect(
        diagnostics.contains(where: { $0.contains("unknown reminder id") }),
        "store should emit diagnostics for unknown reminder outcomes"
    )
    try expect(
        diagnostics.contains(where: { $0.contains("duplicate outcome") }),
        "store should emit diagnostics for duplicate outcomes"
    )
}

func testHealthMetricsStoreSerializesConcurrentWrites() throws {
    let appPaths = try makeTemporaryAppPaths()
    let store = try HealthMetricsStore(appPaths: appPaths)
    let shownAt = Date(timeIntervalSince1970: 1_744_000_000)
    let lock = NSLock()
    var errors: [Error] = []
    let writeCount = 64

    DispatchQueue.concurrentPerform(iterations: writeCount) { index in
        let reminderID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
        do {
            try store.recordReminderShown(id: reminderID, type: .eyeCare, at: shownAt.addingTimeInterval(Double(index)))
        } catch {
            lock.lock()
            errors.append(error)
            lock.unlock()
        }
    }

    try expect(errors.isEmpty, "concurrent writes should not throw errors")
    let summary = try store.daySummary(for: shownAt)
    try expect(summary.eyeReminder.shown == writeCount, "serial store writes should not lose events")
}

func testHealthSessionTrackerSettlesWorkFocusAndBreakMetricsAcrossTransitions() throws {
    let appPaths = try makeTemporaryAppPaths()
    let store = try HealthMetricsStore(appPaths: appPaths)
    let tracker = HealthSessionTracker(store: store)
    let start = Date(timeIntervalSince1970: 1_744_000_000)

    try tracker.recordStateTransition(from: .idle, to: .working, at: start)
    try tracker.recordStateTransition(from: .working, to: .focus, at: start.addingTimeInterval(600))
    try tracker.recordStateTransition(from: .focus, to: .working, at: start.addingTimeInterval(1500))
    try tracker.recordStateTransition(from: .working, to: .breakState, at: start.addingTimeInterval(2100))

    let summary = try store.daySummary(for: start)
    try expect(summary.workDuration == 1_200, "working spans should be settled on boundary changes")
    try expect(summary.focusCount == 1, "entering focus should increment focus count")
    try expect(summary.focusDuration == 900, "focus duration should be settled when leaving focus")
    try expect(summary.breakCount == 1, "entering break should increment break count")
}

func testHealthSessionTrackerOnlyRequestsStopWorkReportWhenDataExists() throws {
    let appPaths = try makeTemporaryAppPaths()
    let store = try HealthMetricsStore(appPaths: appPaths)
    let tracker = HealthSessionTracker(store: store)
    let start = Date(timeIntervalSince1970: 1_744_000_000)

    let shouldPresentBeforeActivity = try tracker.shouldPresentStopWorkReport(at: start)
    try expect(shouldPresentBeforeActivity == false, "empty day should not request stop-work report")

    try tracker.recordStateTransition(from: .idle, to: .working, at: start)
    try tracker.recordStateTransition(from: .working, to: .idle, at: start.addingTimeInterval(300))

    let shouldPresentAfterActivity = try tracker.shouldPresentStopWorkReport(at: start)
    try expect(shouldPresentAfterActivity == true, "day with settled work data should request stop-work report")
}

func testHealthSessionTrackerSplitsSettledDurationAcrossMidnightBoundary() throws {
    let appPaths = try makeTemporaryAppPaths()
    let store = try HealthMetricsStore(appPaths: appPaths)
    let tracker = HealthSessionTracker(store: store)

    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let start = utcCalendar.date(from: DateComponents(
        year: 2025,
        month: 4,
        day: 3,
        hour: 23,
        minute: 50
    ))!
    let end = start.addingTimeInterval(1_200)

    try tracker.recordStateTransition(from: .idle, to: .working, at: start)
    try tracker.recordStateTransition(from: .working, to: .idle, at: end)

    let firstDaySummary = try store.daySummary(for: start)
    let secondDaySummary = try store.daySummary(for: end)

    try expect(firstDaySummary.workDuration == 600, "work before midnight should settle on first day")
    try expect(secondDaySummary.workDuration == 600, "work after midnight should settle on next day")
}
