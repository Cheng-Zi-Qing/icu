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
func testReminderCallbackCannotRearmAfterStop() throws {
    var scheduler: ReminderScheduler!
    var reminderCount = 0
    scheduler = ReminderScheduler(eyeInterval: 0.01, hydrationInterval: 3600, snoozeInterval: 300) { _ in
        reminderCount += 1
        scheduler.stop()
    }
    defer { scheduler.stop() }
    scheduler.startWorking()
    try expect(waitForCondition(timeout: 0.5) { reminderCount > 0 }, "reminder should fire before stopping")
    try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "a callback that stops work must not rearm its old timer")
}

@MainActor
func testWorkingStateArmsEyeReminder() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200)
    scheduler.startWorking()
    try expect(scheduler.isEyeReminderArmed, "working state should arm eye reminder")
}

@MainActor
func testWorkingStateArmsHydrationReminder() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200, hydrationInterval: 3600)
    scheduler.startWorking()
    try expect(scheduler.isHydrationReminderArmed, "working state should arm hydration reminder")
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

@MainActor
func testHydrationReminderCallbackIncludesHydrationType() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(
        eyeInterval: 999,
        hydrationInterval: 0.2,
        snoozeInterval: 0.01
    ) { payload in
        reminders.append(payload)
    }
    defer { scheduler.stop() }

    scheduler.startWorking()
    try expect(
        waitForCondition(timeout: 0.35) { reminders.contains(where: { $0.type == .hydration }) },
        "scheduler should emit hydration reminder payloads"
    )
}

@MainActor
func testUpdatingIntervalsWhileWorkingKeepsRemindersArmed() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200, hydrationInterval: 3600)
    scheduler.startWorking()
    scheduler.updateIntervals(eye: 900, hydration: 2400)
    try expect(scheduler.eyeInterval == 900 && scheduler.hydrationInterval == 2400, "new intervals should be stored")
    try expect(scheduler.isEyeReminderArmed && scheduler.isHydrationReminderArmed, "reminders stay armed with the new intervals")
}

@MainActor
func testUpdatingIntervalsWhileIdleDoesNotArmReminders() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200, hydrationInterval: 3600)
    scheduler.updateIntervals(eye: 900, hydration: 2400)
    try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "idle should stay idle")
}

@MainActor
func testEyeReminderCarriesTheRestDurationOfTheCurrentMode() throws {
    var payloads: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(eyeInterval: 0.02, hydrationInterval: 3600, snoozeInterval: 300) { payloads.append($0) }
    scheduler.updateIntervals(eye: 0.02, hydration: 3600, eyeRest: 300)
    scheduler.startWorking()
    defer { scheduler.stop() }
    try expect(waitForCondition(timeout: 1) { !payloads.isEmpty }, "the eye reminder should fire")
    try expect(payloads.first?.restSeconds == 300, "the card should count down the mode's rest time (got \(String(describing: payloads.first?.restSeconds)))")
}

@MainActor
func testAutomaticRestBlocksStartResumeUpdatesAndSnooze() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(eyeInterval: 0.02, hydrationInterval: 0.02, snoozeInterval: 0.01) { reminders.append($0) }
    defer { scheduler.stop() }
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "rest test")
    scheduler.startWorking()
    scheduler.scheduleSnooze(for: payload)
    scheduler.setUserResting(true)
    scheduler.startWorking()
    scheduler.resumeWorking()
    scheduler.updateIntervals(eye: 0.02, hydration: 0.02)
    scheduler.scheduleSnooze(for: payload)
    try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "start/resume/settings changes must not arm during automatic rest")
    try expect(!waitForCondition(timeout: 0.08) { !reminders.isEmpty }, "rest must cancel old eye/hydration/snooze timers and reject new snoozes")
    scheduler.setUserResting(false)
    try expect(scheduler.isEyeReminderArmed && scheduler.isHydrationReminderArmed, "returning to manual working should rearm both reminders")
    try expect(waitForCondition(timeout: 0.3) { reminders.contains { $0.type == .eyeCare } && reminders.contains { $0.type == .hydration } }, "both reminders should run after returning")
    try expect(!reminders.contains { $0.id == payload.id }, "cancelled snoozes must not revive on return")
}

@MainActor
func testAutomaticRestReturnUsesFullIntervalsWithoutResettingOnRepeatedSamples() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(eyeInterval: 0.15, hydrationInterval: 0.15, snoozeInterval: 300) { reminders.append($0) }
    defer { scheduler.stop() }
    scheduler.startWorking()
    try expect(!waitForCondition(timeout: 0.07) { !reminders.isEmpty }, "first interval should not have elapsed")
    scheduler.setUserResting(true)
    try expect(!waitForCondition(timeout: 0.12) { !reminders.isEmpty }, "old deadlines must not fire during rest")
    scheduler.setUserResting(false)
    try expect(!waitForCondition(timeout: 0.09) { !reminders.isEmpty }, "return should start a complete interval")
    scheduler.setUserResting(false)
    try expect(waitForCondition(timeout: 0.1) { !reminders.isEmpty }, "repeated active samples must not restart the interval")
}

@MainActor
func testAutomaticRestReturnDoesNotReviveFocusBreakOrStop() throws {
    let scheduler = ReminderScheduler(eyeInterval: 1200, hydrationInterval: 3600)
    defer { scheduler.stop() }
    scheduler.startWorking()
    scheduler.setUserResting(true)
    scheduler.enterFocus()
    scheduler.setUserResting(false)
    try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "return to focus must keep reminders disabled")
    scheduler.setUserResting(true)
    scheduler.resumeWorking()
    scheduler.stop()
    scheduler.setUserResting(false)
    scheduler.updateIntervals(eye: 900, hydration: 1800)
    try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "manual break/stop during rest must stay stopped on return")
    scheduler.enterFocus()
    scheduler.setUserResting(true)
    scheduler.setUserResting(false)
    try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "focus entered before rest must also stay disabled")
}

@MainActor
func testReminderCallbackCannotRearmAfterAutomaticRest() throws {
    for type in [HealthReminderType.eyeCare, .hydration] {
        var scheduler: ReminderScheduler!
        var reminderCount = 0
        scheduler = ReminderScheduler(
            eyeInterval: type == .eyeCare ? 0.01 : 3600,
            hydrationInterval: type == .hydration ? 0.01 : 3600,
            snoozeInterval: 300
        ) { _ in
            reminderCount += 1
            scheduler.setUserResting(true)
        }
        defer { scheduler.stop() }
        scheduler.startWorking()
        try expect(waitForCondition(timeout: 0.5) { reminderCount > 0 }, "reminder should fire before entering rest")
        try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "a callback that enters rest must not rearm its old timer")
        try expect(!waitForCondition(timeout: 0.04) { reminderCount > 1 }, "cancelled callbacks must not emit again")
    }
}
