import Foundation

/// 把上班 / 专注 / 休息的时长按天记到本机。
///
/// 时长不是等到切状态才入账：`checkpoint` 会把「到现在为止」的这一段先结掉（App 每分钟调一次，
/// 读今日报告前也调一次），所以报告里总是最新的数，App 意外退出最多丢一分钟。
/// 电脑睡着的那段不算上班：睡前 `suspend`，醒来 `resume`。
final class HealthSessionTracker {
    private let store: HealthMetricsStore
    private var activeState: ShellWorkState?
    private var activeStateStartedAt: Date?
    private var isSuspended = false

    init(store: HealthMetricsStore) {
        self.store = store
    }

    // Contract: callers should emit every transition while the app is alive.
    // On the first observed transition we only know the boundary timestamp from
    // this call, so any pre-launch/session duration before `at` cannot be inferred.
    func recordStateTransition(from oldState: ShellWorkState, to newState: ShellWorkState, at date: Date) throws {
        let settledState = activeState ?? oldState
        try settle(settledState, upTo: date)

        if settledState == .idle, newState != .idle {
            try store.recordClockIn(at: date)
        }
        if settledState != .idle, newState == .idle {
            try store.recordClockOut(at: date)
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

    /// 把正在进行的这一段结到 `date`，然后从 `date` 接着算。没在上班就什么都不做
    func checkpoint(at date: Date) throws {
        guard let activeState, !isSuspended, let startedAt = activeStateStartedAt else { return }
        // 只入账整秒，零头留给下一次，免得每分钟结一次越结越少
        let settled = try settle(activeState, upTo: date)
        activeStateStartedAt = startedAt.addingTimeInterval(settled)
    }

    /// 电脑要睡了：先把睡前这段结掉，睡着的时间不算
    func suspend(at date: Date) throws {
        try checkpoint(at: date)
        isSuspended = true
    }

    /// 电脑醒了：还在上班的话，从现在接着算
    func resume(at date: Date) {
        guard isSuspended else { return }
        isSuspended = false
        if activeState != nil {
            activeStateStartedAt = date
        }
    }

    /// App 要退出了：还在上班就当成下班，把最后一段结掉
    func endSession(at date: Date) throws {
        guard let activeState else { return }
        try recordStateTransition(from: activeState, to: .idle, at: date)
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

    /// 今天的数，含正在进行的这一段
    func todayReport(at date: Date) throws -> HealthDaySummary {
        try checkpoint(at: date)
        return try store.daySummary(for: date)
    }

    func weekReport(containing date: Date) throws -> HealthWeekSummary {
        try checkpoint(at: date)
        return try store.weekSummary(containing: date)
    }

    func lifetimeReport(at date: Date) throws -> HealthLifetimeSummary {
        try checkpoint(at: date)
        return try store.lifetimeSummary()
    }

    /// 把 `state` 从这一段的起点结到 `date`，返回入账了多少整秒
    @discardableResult
    private func settle(_ state: ShellWorkState, upTo date: Date) throws -> TimeInterval {
        guard !isSuspended, let startedAt = activeStateStartedAt else { return 0 }
        let duration = date.timeIntervalSince(startedAt).rounded(.down)
        guard duration >= 1 else { return 0 }
        switch state {
        case .working:
            try store.settleWorkDuration(seconds: duration, at: startedAt)
        case .focus:
            try store.settleFocusDuration(seconds: duration, at: startedAt)
        case .breakState:
            try store.settleBreakDuration(seconds: duration, at: startedAt)
        case .idle:
            return 0
        }
        try splitShiftAtMidnight(from: startedAt, to: startedAt.addingTimeInterval(duration))
        return duration
    }

    /// 上班跨过了零点：前一天算到零点下班，新的一天从零点上班，两天各自的时段都对得上
    private func splitShiftAtMidnight(from start: Date, to end: Date) throws {
        let calendar = store.calendar
        guard !calendar.isDate(start, inSameDayAs: end) else { return }
        let dayStart = calendar.startOfDay(for: end)
        try store.recordClockOut(at: dayStart.addingTimeInterval(-1))
        try store.recordClockIn(at: dayStart)
    }
}
