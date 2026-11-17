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
    scheduler = ReminderScheduler(eyeInterval: 0.01, hydrationInterval: 3600, snoozeInterval: 300, onReminder: { _ in
        reminderCount += 1
        scheduler.stop()
    })
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
        snoozeInterval: 0.01,
        onReminder: { payload in
        reminders.append(payload)
    })
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
        snoozeInterval: 0.01,
        onReminder: { payload in
        reminders.append(payload)
    })
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
        snoozeInterval: 0.01,
        onReminder: { payload in
        reminders.append(payload)
    })
    defer { scheduler.stop() }

    scheduler.startWorking()
    try expect(
        waitForCondition(timeout: 0.9) { reminders.contains(where: { $0.type == .hydration }) },
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
    let scheduler = ReminderScheduler(eyeInterval: 0.02, hydrationInterval: 3600, snoozeInterval: 300, onReminder: { payloads.append($0) })
    scheduler.updateIntervals(eye: 0.02, hydration: 3600, eyeRest: 300)
    scheduler.startWorking()
    defer { scheduler.stop() }
    try expect(waitForCondition(timeout: 1) { !payloads.isEmpty }, "the eye reminder should fire")
    try expect(payloads.first?.restSeconds == 300, "the card should count down the mode's rest time (got \(String(describing: payloads.first?.restSeconds)))")
}

@MainActor
func testAutomaticRestBlocksStartResumeUpdatesAndSnooze() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(eyeInterval: 0.02, hydrationInterval: 0.02, snoozeInterval: 0.01, onReminder: { reminders.append($0) })
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
    try expect(waitForCondition(timeout: 0.9) { reminders.contains { $0.type == .eyeCare } && reminders.contains { $0.type == .hydration } }, "both reminders should run after returning")
    try expect(!reminders.contains { $0.id == payload.id }, "cancelled snoozes must not revive on return")
}

@MainActor
func testAutomaticRestReturnUsesFullEyeIntervalWithoutResettingOnRepeatedSamples() throws {
    // 喝水改成按网格排了（见 hydration 的测试），这里只看护眼：回来还是从头数一整个间隔
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(eyeInterval: 0.15, hydrationInterval: 3600, snoozeInterval: 300, onReminder: { reminders.append($0) })
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
            snoozeInterval: 300,
            onReminder: { _ in
            reminderCount += 1
            scheduler.setUserResting(true)
        })
        defer { scheduler.stop() }
        scheduler.startWorking()
        try expect(waitForCondition(timeout: 0.9) { reminderCount > 0 }, "reminder should fire before entering rest")
        try expect(!scheduler.isEyeReminderArmed && !scheduler.isHydrationReminderArmed, "a callback that enters rest must not rearm its old timer")
        try expect(!waitForCondition(timeout: 0.04) { reminderCount > 1 }, "cancelled callbacks must not emit again")
    }
}

// MARK: - 喝水提醒的时间网格（锚点是点「我要上班」那一刻）

/// 喝水按「以上班时刻为锚点的时间网格」排：第 k 杯在锚点后 (k - 0.5) 个间隔
@MainActor
func testFirstHydrationReminderLandsAtHalfTheInterval() throws {
    var hydrationReminders: [Date] = []
    let interval: TimeInterval = 1.2
    let scheduler = ReminderScheduler(eyeInterval: 999, hydrationInterval: interval, snoozeInterval: 300, onReminder: { payload in
        if payload.type == .hydration { hydrationReminders.append(Date()) }
    })
    defer { scheduler.stop() }

    let clockedInAt = Date()
    scheduler.startWorking(at: clockedInAt)
    try expect(!waitForCondition(timeout: interval * 0.25) { !hydrationReminders.isEmpty }, "the first cup must not come right after clocking in")
    try expect(waitForCondition(timeout: interval) { !hydrationReminders.isEmpty }, "the first cup should come half an interval after clocking in")
    let lateness = hydrationReminders[0].timeIntervalSince(clockedInAt)
    try expect(lateness >= interval * 0.4 && lateness < interval, "the first cup should land at half the interval, not a whole one (got \(lateness))")
}

private enum HydrationPause {
    case focus
    case automaticRest

    var label: String {
        switch self {
        case .focus: return "专注"
        case .automaticRest: return "自动休息"
        }
    }
}

/// 暂停（专注 / 自动休息）回来接着原锚点的网格排，不是从回来那一刻重新数一整个间隔
@MainActor
private func expectHydrationGridSurvivesPause(_ pause: HydrationPause) throws {
    // 把表往前拨来模拟暂停了很久，不用真的等
    var clockShift: TimeInterval = 0
    let now: () -> Date = { Date().addingTimeInterval(clockShift) }
    var reminders: [ReminderPresentationPayload] = []
    let interval: TimeInterval = 2
    let scheduler = ReminderScheduler(eyeInterval: 999, hydrationInterval: interval, snoozeInterval: 300, nowProvider: now, onReminder: { reminders.append($0) })
    defer { scheduler.stop() }

    scheduler.startWorking(at: now())
    switch pause {
    case .focus: scheduler.enterFocus()
    case .automaticRest: scheduler.setUserResting(true)
    }
    // 暂停了 3.2 个间隔：回来时正走在第 4 格的 20% 处
    clockShift = 3.2 * interval
    try expect(!waitForCondition(timeout: 0.3) { !reminders.isEmpty }, "暂停期间不该来提醒（\(pause.label)）")

    switch pause {
    case .focus: scheduler.resumeWorking()
    case .automaticRest: scheduler.setUserResting(false)
    }
    // 第 4 杯在锚点后 3.5 个间隔，所以只剩 0.6s；从回来重新数一整个间隔会是 1s
    try expect(waitForCondition(timeout: 0.85) { !reminders.isEmpty }, "回来要接着原锚点的网格排（\(pause.label)）")
    try expect(!waitForCondition(timeout: 0.25) { reminders.count > 1 }, "只排下一格，不连发（\(pause.label)）")
}

@MainActor
func testHydrationGridSurvivesFocusAndAutomaticRest() throws {
    try expectHydrationGridSurvivesPause(.focus)
    try expectHydrationGridSurvivesPause(.automaticRest)
}

@MainActor
func testHydrationCatchesUpOneGridSlotAfterALongGap() throws {
    var reminders: [ReminderPresentationPayload] = []
    let interval: TimeInterval = 1.2
    let scheduler = ReminderScheduler(eyeInterval: 999, hydrationInterval: interval, snoozeInterval: 300, onReminder: { reminders.append($0) })
    defer { scheduler.stop() }

    // 锚点在 1000 个间隔以前（中间睡了很久）：只补下一格，不把漏掉的都补发出来
    scheduler.startWorking(at: Date().addingTimeInterval(-1000 * interval))
    try expect(!waitForCondition(timeout: 0.3) { !reminders.isEmpty }, "补的那杯也是网格点，不该在上班那一刻就连发")
    try expect(waitForCondition(timeout: 1) { !reminders.isEmpty }, "半格后补上这一杯")
    try expect(!waitForCondition(timeout: 0.4) { reminders.count > 1 }, "补完一格就等下一格")
}

@MainActor
func testStartingWorkAgainResetsTheHydrationGrid() throws {
    var reminders: [ReminderPresentationPayload] = []
    let interval: TimeInterval = 1.2
    let scheduler = ReminderScheduler(eyeInterval: 999, hydrationInterval: interval, snoozeInterval: 300, onReminder: { reminders.append($0) })
    defer { scheduler.stop() }

    scheduler.startWorking(at: Date())
    try expect(waitForCondition(timeout: 1) { reminders.count == 1 }, "第一杯在半格后")
    scheduler.stop()

    // 新的上下班段从第 1 格重新算：半格后就来，而不是接着上一段等第 2 格（1.5 个间隔）
    scheduler.startWorking(at: Date())
    try expect(waitForCondition(timeout: 0.9) { reminders.count == 2 }, "再点「我要上班」要把网格重置回第 1 格")
}

@MainActor
func testHydrationIsNotArmedOnceTheGoalIsMet() throws {
    var reminders: [ReminderPresentationPayload] = []
    let scheduler = ReminderScheduler(eyeInterval: 999, hydrationInterval: 0.1, snoozeInterval: 300, onReminder: { reminders.append($0) })
    defer { scheduler.stop() }

    scheduler.hydrationProgress = { (done: 6, goal: 6) }
    scheduler.startWorking(at: Date())
    try expect(!scheduler.isHydrationReminderArmed, "今天喝够了就不排喝水提醒")
    try expect(scheduler.isEyeReminderArmed, "喝够水不影响护眼提醒")
    try expect(!waitForCondition(timeout: 0.9) { !reminders.isEmpty }, "喝够了就不该再来 payload")

    scheduler.hydrationProgressChanged()
    try expect(!scheduler.isHydrationReminderArmed, "喝够了刷新进度也不排")
}

@MainActor
func testHydrationProgressChangedKeepsTheGridUntilTheGoalIsMet() throws {
    var reminders: [ReminderPresentationPayload] = []
    var done = 0
    let scheduler = ReminderScheduler(eyeInterval: 999, hydrationInterval: 0.4, snoozeInterval: 300, onReminder: { reminders.append($0) })
    defer { scheduler.stop() }

    scheduler.hydrationProgress = { (done: done, goal: 3) }
    scheduler.startWorking(at: Date())
    done = 2
    scheduler.hydrationProgressChanged()
    try expect(scheduler.isHydrationReminderArmed, "没喝够就继续按网格排")
    done = 3
    scheduler.hydrationProgressChanged()
    try expect(!scheduler.isHydrationReminderArmed, "喝够的那一刻就停")
    try expect(!waitForCondition(timeout: 0.9) { !reminders.isEmpty }, "停了就不再来 payload")
}
