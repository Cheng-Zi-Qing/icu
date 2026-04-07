import Foundation

enum HealthReminderType: String, Codable {
    case eyeCare = "eye_care"
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
}

struct HealthDaySummary: Codable {
    var date: Date
    var eyeReminder: HealthReminderCounts
    var workDuration: Int
    var focusCount: Int
    var focusDuration: Int
    var breakCount: Int

    var eyeReminderCompletionRate: Double {
        guard eyeReminder.shown > 0 else {
            return 0
        }

        return Double(eyeReminder.completed) / Double(eyeReminder.shown)
    }

    var hasActivity: Bool {
        workDuration > 0
            || focusDuration > 0
            || focusCount > 0
            || breakCount > 0
            || eyeReminder.shown > 0
            || eyeReminder.completed > 0
            || eyeReminder.snoozed > 0
            || eyeReminder.skipped > 0
    }
}

struct HealthWeekSummary: Codable {
    var weekStartDate: Date
    var weekEndExclusiveDate: Date
    var eyeReminder: HealthReminderCounts
    var eyeReminderCompletionRate: Double
    var workDuration: Int
    var focusCount: Int
    var focusDuration: Int
    var breakCount: Int
    var days: [HealthDaySummary]

    var activeDayCount: Int {
        days.filter(\.hasActivity).count
    }
}

struct PersistedHealthReminder: Codable {
    var id: UUID
    var type: HealthReminderType
    var shownAt: Date
    var outcome: HealthReminderOutcome?
    var outcomeAt: Date?
}
