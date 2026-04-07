import Foundation

final class HealthSessionTracker {
    private let store: HealthMetricsStore
    private var activeState: ShellWorkState?
    private var activeStateStartedAt: Date?

    init(store: HealthMetricsStore) {
        self.store = store
    }

    // Contract: callers should emit every transition while the app is alive.
    // On the first observed transition we only know the boundary timestamp from
    // this call, so any pre-launch/session duration before `at` cannot be inferred.
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
        return summary.hasActivity
    }

    func recordReminderShown(_ payload: ReminderPresentationPayload, at date: Date) throws {
        try store.recordReminderShown(id: payload.id, type: payload.type, at: date)
    }

    func recordReminderOutcome(
        for payload: ReminderPresentationPayload,
        outcome: HealthReminderOutcome,
        at date: Date
    ) throws {
        try store.recordReminderOutcome(id: payload.id, outcome: outcome, at: date)
    }

    func todayReport(at date: Date) throws -> HealthDaySummary {
        try store.daySummary(for: date)
    }

    func weekReport(containing date: Date) throws -> HealthWeekSummary {
        try store.weekSummary(containing: date)
    }
}
