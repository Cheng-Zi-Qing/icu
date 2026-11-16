import Foundation

struct ReminderPresentationPayload {
    let id: UUID
    let type: HealthReminderType
    let text: String
    /// 护眼提醒要休息多久（全屏休息倒计时用）
    var restSeconds: TimeInterval = 20
    /// 这条提醒之前已经推迟过几次（推迟后再出来的那条 +1）
    var snoozeCount = 0
}

@MainActor
final class ReminderScheduler {
    private(set) var isEyeReminderArmed = false
    private(set) var isHydrationReminderArmed = false

    private(set) var eyeInterval: TimeInterval
    private(set) var hydrationInterval: TimeInterval
    private(set) var eyeRestSeconds: TimeInterval = 20
    private let snoozeInterval: TimeInterval
    private let onReminder: ((ReminderPresentationPayload) -> Void)?
    private let onEyeReminder: (() -> Void)?
    private var eyeTimer: DispatchSourceTimer?
    private var hydrationTimer: DispatchSourceTimer?
    private var eyeTimerID: UUID?
    private var hydrationTimerID: UUID?
    private var snoozeTimers: [UUID: (id: UUID, timer: DispatchSourceTimer)] = [:]
    private var isWorkingEnabled = false
    private var isUserResting = false

    private var canSchedule: Bool { isWorkingEnabled && !isUserResting }

    init(
        eyeInterval: TimeInterval = 20 * 60,
        hydrationInterval: TimeInterval = 45 * 60,
        snoozeInterval: TimeInterval = 5 * 60,
        onReminder: ((ReminderPresentationPayload) -> Void)? = nil
    ) {
        self.eyeInterval = eyeInterval
        self.hydrationInterval = hydrationInterval
        self.snoozeInterval = snoozeInterval
        self.onReminder = onReminder
        self.onEyeReminder = nil
    }

    init(
        eyeInterval: TimeInterval = 20 * 60,
        hydrationInterval: TimeInterval = 45 * 60,
        onEyeReminder: (() -> Void)? = nil
    ) {
        self.eyeInterval = eyeInterval
        self.hydrationInterval = hydrationInterval
        self.snoozeInterval = 5 * 60
        self.onReminder = nil
        self.onEyeReminder = onEyeReminder
    }

    func startWorking() {
        isWorkingEnabled = true
        armEyeReminder()
        armHydrationReminder()
    }

    func enterFocus() {
        stop()
    }

    func resumeWorking() {
        startWorking()
    }

    func stop() {
        isWorkingEnabled = false
        cancelEyeReminder()
        cancelHydrationReminder()
        cancelSnoozeReminders()
    }

    func setUserResting(_ isResting: Bool) {
        guard isUserResting != isResting else { return }
        isUserResting = isResting
        if isResting {
            cancelEyeReminder()
            cancelHydrationReminder()
            cancelSnoozeReminders()
        } else if isWorkingEnabled {
            armEyeReminder()
            armHydrationReminder()
        }
    }

    /// 设置里改了间隔：已经在计时的提醒按新间隔重新计时，没在计时的不动
    func updateIntervals(eye: TimeInterval, hydration: TimeInterval, eyeRest: TimeInterval = 20) {
        eyeInterval = eye
        hydrationInterval = hydration
        eyeRestSeconds = eyeRest
        if isEyeReminderArmed { armEyeReminder() }
        if isHydrationReminderArmed { armHydrationReminder() }
    }

    func scheduleSnooze(for payload: ReminderPresentationPayload) {
        cancelSnoozeReminder(for: payload.id)
        guard canSchedule else { return }

        let timerID = UUID()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + snoozeInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.canSchedule, self.snoozeTimers[payload.id]?.id == timerID else { return }
            self.cancelSnoozeReminder(for: payload.id)
            self.emitReminder(payload)
        }
        snoozeTimers[payload.id] = (timerID, timer)
        timer.resume()
    }

    private func armEyeReminder() {
        cancelEyeReminder()
        guard canSchedule else { return }
        isEyeReminderArmed = true
        let timerID = UUID()
        eyeTimerID = timerID

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + eyeInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.canSchedule, self.eyeTimerID == timerID else { return }
            self.emitReminder(
                ReminderPresentationPayload(
                    id: UUID(),
                    type: .eyeCare,
                    text: DesktopPetCopy.eyeReminderMessage(),
                    restSeconds: self.eyeRestSeconds
                )
            )
            if self.eyeTimerID == timerID { self.armEyeReminder() }
        }
        eyeTimer = timer
        timer.resume()
    }

    private func armHydrationReminder() {
        cancelHydrationReminder()
        guard canSchedule else { return }
        isHydrationReminderArmed = true
        let timerID = UUID()
        hydrationTimerID = timerID

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + hydrationInterval)
        timer.setEventHandler { [weak self] in
            guard let self, self.canSchedule, self.hydrationTimerID == timerID else { return }
            self.emitReminder(
                ReminderPresentationPayload(
                    id: UUID(),
                    type: .hydration,
                    text: DesktopPetCopy.hydrationReminderMessage()
                )
            )
            if self.hydrationTimerID == timerID { self.armHydrationReminder() }
        }
        hydrationTimer = timer
        timer.resume()
    }

    private func cancelEyeReminder() {
        eyeTimerID = nil
        eyeTimer?.cancel()
        eyeTimer = nil
        isEyeReminderArmed = false
    }

    private func cancelHydrationReminder() {
        hydrationTimerID = nil
        hydrationTimer?.cancel()
        hydrationTimer = nil
        isHydrationReminderArmed = false
    }

    private func emitReminder(_ payload: ReminderPresentationPayload) {
        onReminder?(payload)
        if onReminder == nil {
            onEyeReminder?()
        }
    }

    private func cancelSnoozeReminder(for reminderID: UUID) {
        snoozeTimers[reminderID]?.timer.cancel()
        snoozeTimers[reminderID] = nil
    }

    private func cancelSnoozeReminders() {
        for entry in snoozeTimers.values {
            entry.timer.cancel()
        }
        snoozeTimers.removeAll()
    }
}
