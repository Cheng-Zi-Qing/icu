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
}
