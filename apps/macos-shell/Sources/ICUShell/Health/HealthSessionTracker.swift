import Foundation

final class HealthSessionTracker {
    private let store: HealthMetricsStore
    private var activeState: ShellWorkState?
    private var activeStateStartedAt: Date?

    init(store: HealthMetricsStore) {
        self.store = store
    }

    func recordStateTransition(from oldState: ShellWorkState, to newState: ShellWorkState, at date: Date) throws {
        let settledState = activeState ?? oldState
        let settledStart = activeStateStartedAt ?? date

        if date >= settledStart {
            let duration = date.timeIntervalSince(settledStart)
            switch settledState {
            case .working:
                try store.settleWorkDuration(seconds: duration, at: settledStart)
            case .focus:
                try store.settleFocusDuration(seconds: duration, at: settledStart)
            case .idle, .breakState:
                break
            }
        }

        switch newState {
        case .focus:
            try store.recordFocusSessionStart(at: date)
        case .breakState:
            try store.recordBreakStart(at: date)
        case .idle, .working:
            break
        }

        if newState == .idle {
            activeState = nil
            activeStateStartedAt = nil
        } else {
            activeState = newState
            activeStateStartedAt = date
        }
    }

    func shouldPresentStopWorkReport(at date: Date) throws -> Bool {
        let summary = try store.daySummary(for: date)
        return summary.workDuration > 0
            || summary.focusDuration > 0
            || summary.focusCount > 0
            || summary.breakCount > 0
            || summary.eyeReminder.shown > 0
            || summary.eyeReminder.completed > 0
            || summary.eyeReminder.snoozed > 0
            || summary.eyeReminder.skipped > 0
    }

    func todayReport(at date: Date) throws -> HealthDaySummary {
        try store.daySummary(for: date)
    }

    func weekReport(containing date: Date) throws -> HealthWeekSummary {
        try store.weekSummary(containing: date)
    }
}
