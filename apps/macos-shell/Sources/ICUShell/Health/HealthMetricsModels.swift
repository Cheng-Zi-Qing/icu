import Foundation

enum HealthReminderType: String, Codable {
    case eyeCare = "eye_care"
    case hydration
}

enum HealthReminderOutcome: String, Codable {
    case shown
    case completed
    case snoozed
    case skipped
}

struct HealthReminderCounts: Codable {
    var shown: Int
    var completed: Int
    var snoozed: Int
    var skipped: Int

    static let empty = HealthReminderCounts(shown: 0, completed: 0, snoozed: 0, skipped: 0)

    var completionRate: Double {
        guard shown > 0 else {
            return 0
        }

        return Double(completed) / Double(shown)
    }
}

struct HealthDaySummary: Codable {
    var date: Date
    var eyeReminder: HealthReminderCounts
    var hydrationReminder: HealthReminderCounts
    var workDuration: Int
    var focusCount: Int
    var focusDuration: Int
    var breakCount: Int
    /// 休息了多久（秒）
    var breakDuration: Int = 0
    /// 今天上了几次班（点了几次「开始工作」）
    var shiftCount: Int = 0
    /// 今天第一次上班、最后一次下班的时刻
    var firstClockInAt: Date? = nil
    var lastClockOutAt: Date? = nil

    /// 上班到下班一共多久：普通工作 + 专注 + 休息，多段上下班累加
    var onDutyDuration: Int {
        workDuration + focusDuration + breakDuration
    }

    var eyeReminderCompletionRate: Double {
        eyeReminder.completionRate
    }

    var hydrationReminderCompletionRate: Double {
        hydrationReminder.completionRate
    }

    var hasActivity: Bool {
        workDuration > 0
            || focusDuration > 0
            || focusCount > 0
            || breakCount > 0
            || breakDuration > 0
            || shiftCount > 0
            || eyeReminder.shown > 0
            || eyeReminder.completed > 0
            || eyeReminder.snoozed > 0
            || eyeReminder.skipped > 0
            || hydrationReminder.shown > 0
            || hydrationReminder.completed > 0
            || hydrationReminder.snoozed > 0
            || hydrationReminder.skipped > 0
    }
}

struct HealthWeekSummary: Codable {
    var weekStartDate: Date
    var weekEndExclusiveDate: Date
    var eyeReminder: HealthReminderCounts
    var eyeReminderCompletionRate: Double
    var hydrationReminder: HealthReminderCounts
    var hydrationReminderCompletionRate: Double
    var workDuration: Int
    var focusCount: Int
    var focusDuration: Int
    var breakCount: Int
    var days: [HealthDaySummary]
    var breakDuration: Int = 0

    var onDutyDuration: Int {
        workDuration + focusDuration + breakDuration
    }

    var activeDayCount: Int {
        days.filter(\.hasActivity).count
    }
}

/// 本机上记下来的全部上班记录：上过班的天数、累计上班时长
struct HealthLifetimeSummary: Equatable {
    var workedDayCount: Int
    var onDutyDuration: Int

    static let empty = HealthLifetimeSummary(workedDayCount: 0, onDutyDuration: 0)
}

struct PersistedHealthReminder: Codable {
    var id: UUID
    var type: HealthReminderType
    var shownAt: Date
    var outcome: HealthReminderOutcome?
    var outcomeAt: Date?
}
