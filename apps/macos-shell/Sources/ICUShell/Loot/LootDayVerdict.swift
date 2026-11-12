import Foundation

/// 看一天的数，判金宝箱（全部达标）和黑匣（状态很差），PRD 2.1 §4.2–4.3
struct LootDayVerdict {
    /// 护眼完成率到多少算达标
    static let eyeGoalRate = 0.8
    /// 提醒完成率低于多少算状态差
    static let roughCompletionRate = 0.4
    /// 至少出过几次提醒才看完成率（只出了一两次，跳过一次不算「状态很差」）
    static let minRemindersForRate = 3
    /// 超出工时多少秒算状态差
    static let roughOvertimeSeconds = 2 * 3600
    /// 几点以后还在上班算熬夜
    static let lateHour = 23

    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 喝水杯数够 + 护眼完成率 ≥ 80%（护眼一次都没提醒过就只看喝水）
    func allGoalsMet(_ day: HealthDaySummary, cupsGoal: Int) -> Bool {
        let cupsDone = day.hydrationReminder.completed >= max(1, cupsGoal)
        let eyeDone = day.eyeReminder.shown == 0 || day.eyeReminder.completionRate >= Self.eyeGoalRate
        return cupsDone && eyeDone
    }

    /// 完成率 < 40%，或超出工时 2 小时以上，或 23:00 后还在上班
    func isRough(_ day: HealthDaySummary, workHours: Double) -> Bool {
        guard day.hasActivity else { return false }
        let shown = day.eyeReminder.shown + day.hydrationReminder.shown
        let completed = day.eyeReminder.completed + day.hydrationReminder.completed
        if shown >= Self.minRemindersForRate, Double(completed) / Double(shown) < Self.roughCompletionRate {
            return true
        }
        if day.onDutyDuration > Int(workHours * 3600) + Self.roughOvertimeSeconds {
            return true
        }
        return workedLate(day)
    }

    private func workedLate(_ day: HealthDaySummary) -> Bool {
        let ends = day.shifts.map { $0.clockOutAt ?? $0.lastSeenAt } + [day.lastClockOutAt].compactMap { $0 }
        return ends.contains { calendar.component(.hour, from: $0) >= Self.lateHour }
    }
}
