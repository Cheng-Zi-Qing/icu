import Foundation

@discardableResult
func waitForCondition(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.005,
    condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(pollInterval))
    }
    return condition()
}

@MainActor
func testWorkingStateArmsEyeReminder() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200)
    scheduler.startWorking()
    try expect(scheduler.isEyeReminderArmed, "working state should arm eye reminder")
}

@MainActor
func testFocusSuspendsEyeReminder() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200)
    scheduler.startWorking()
    scheduler.enterFocus()
    try expect(!scheduler.isEyeReminderArmed, "focus should suspend eye reminder")
}

@MainActor
func testResumeWorkingRearmsEyeReminder() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200)
    scheduler.startWorking()
    scheduler.enterFocus()
    scheduler.resumeWorking()
    try expect(scheduler.isEyeReminderArmed, "resume working should re-arm eye reminder")
}

@MainActor
func testEyeReminderCallbackCarriesStableReminderIdentifier() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(
        eyeInterval: 0.2,
        snoozeInterval: 0.01
    ) { payload in
        reminders.append(payload)
    }
    defer { scheduler.stop() }

    scheduler.startWorking()
    try expect(
        waitForCondition(timeout: 0.35) { reminders.count == 1 },
        "scheduler should emit the first reminder payload"
    )

    let firstReminder = reminders[0]
    scheduler.scheduleSnooze(for: firstReminder)

    try expect(
        waitForCondition(timeout: 0.2) { reminders.count >= 2 },
        "snoozing should emit a follow-up payload"
    )

    let matchingFollowUps = reminders.dropFirst().filter { $0.id == firstReminder.id }
    try expect(
        matchingFollowUps.count == 1,
        "snoozed follow-up should carry the same stable reminder identifier exactly once"
    )
}

@MainActor
func testSnoozeSchedulesOneFollowUpReminder() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(
        eyeInterval: 0.2,
        snoozeInterval: 0.01
    ) { payload in
        reminders.append(payload)
    }
    defer { scheduler.stop() }

    scheduler.startWorking()
    try expect(
        waitForCondition(timeout: 0.35) { reminders.count == 1 },
        "scheduler should emit the first reminder"
    )

    let firstReminder = reminders[0]
    scheduler.scheduleSnooze(for: firstReminder)

    try expect(
        waitForCondition(timeout: 0.2) { reminders.count >= 2 },
        "snooze should emit a follow-up reminder"
    )

    let followUps = reminders.dropFirst().filter { $0.id == firstReminder.id }
    try expect(
        followUps.count == 1,
        "snooze should emit exactly one follow-up for the same reminder id"
    )
}
