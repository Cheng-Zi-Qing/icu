import Foundation

final class ReminderScheduler {
    private(set) var isEyeReminderArmed = false

    private let eyeInterval: TimeInterval
    private let onEyeReminder: (() -> Void)?
    private var eyeTimer: DispatchSourceTimer?

    init(eyeInterval: TimeInterval = 20 * 60, onEyeReminder: (() -> Void)? = nil) {
        self.eyeInterval = eyeInterval
        self.onEyeReminder = onEyeReminder
    }

    func startWorking() {
        armEyeReminder()
    }

    func enterFocus() {
        cancelEyeReminder()
    }

    func resumeWorking() {
        armEyeReminder()
    }

    func stop() {
        cancelEyeReminder()
    }

    private func armEyeReminder() {
        cancelEyeReminder()
        isEyeReminderArmed = true

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + eyeInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.onEyeReminder?()
            self.armEyeReminder()
        }
        timer.resume()
        eyeTimer = timer
    }

    private func cancelEyeReminder() {
        eyeTimer?.cancel()
        eyeTimer = nil
        isEyeReminderArmed = false
    }
}
