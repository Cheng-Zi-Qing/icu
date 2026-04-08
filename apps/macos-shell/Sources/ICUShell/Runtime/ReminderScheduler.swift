import Foundation

struct ReminderPresentationPayload {
    let id: UUID
    let type: HealthReminderType
    let text: String
}

@MainActor
final class ReminderScheduler {
    private(set) var isEyeReminderArmed = false
    private(set) var isHydrationReminderArmed = false

    private let eyeInterval: TimeInterval
    private let hydrationInterval: TimeInterval
    private let snoozeInterval: TimeInterval
    private let onReminder: ((ReminderPresentationPayload) -> Void)?
    private let onEyeReminder: (() -> Void)?
    private var eyeTimer: DispatchSourceTimer?
    private var hydrationTimer: DispatchSourceTimer?
    private var snoozeTimers: [UUID: DispatchSourceTimer] = [:]

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
        armEyeReminder()
        armHydrationReminder()
    }

    func enterFocus() {
        cancelEyeReminder()
        cancelHydrationReminder()
        cancelSnoozeReminders()
    }

    func resumeWorking() {
        armEyeReminder()
        armHydrationReminder()
    }

    func stop() {
        cancelEyeReminder()
        cancelHydrationReminder()
        cancelSnoozeReminders()
    }

    func scheduleSnooze(for payload: ReminderPresentationPayload) {
        cancelSnoozeReminder(for: payload.id)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + snoozeInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.cancelSnoozeReminder(for: payload.id)
            self.emitReminder(payload)
        }
        snoozeTimers[payload.id] = timer
        timer.resume()
    }

    private func armEyeReminder() {
        cancelEyeReminder()
        isEyeReminderArmed = true

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + eyeInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.emitReminder(
                ReminderPresentationPayload(
                    id: UUID(),
                    type: .eyeCare,
                    text: DesktopPetCopy.eyeReminderMessage()
                )
            )
            self.armEyeReminder()
        }
        eyeTimer = timer
        timer.resume()
    }

    private func armHydrationReminder() {
        cancelHydrationReminder()
        isHydrationReminderArmed = true

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + hydrationInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.emitReminder(
                ReminderPresentationPayload(
                    id: UUID(),
                    type: .hydration,
                    text: DesktopPetCopy.hydrationReminderMessage()
                )
            )
            self.armHydrationReminder()
        }
        hydrationTimer = timer
        timer.resume()
    }

    private func cancelEyeReminder() {
        eyeTimer?.cancel()
        eyeTimer = nil
        isEyeReminderArmed = false
    }

    private func cancelHydrationReminder() {
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
        snoozeTimers[reminderID]?.cancel()
        snoozeTimers[reminderID] = nil
    }

    private func cancelSnoozeReminders() {
        for timer in snoozeTimers.values {
            timer.cancel()
        }
        snoozeTimers.removeAll()
    }
}
