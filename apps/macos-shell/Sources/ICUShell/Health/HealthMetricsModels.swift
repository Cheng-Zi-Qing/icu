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
}

struct HealthWeekSummary: Codable {
    var weekStartDate: Date
    var weekEndExclusiveDate: Date
    var eyeReminder: HealthReminderCounts
    var eyeReminderCompletionRate: Double
}

struct PersistedHealthMetrics: Codable {
    var reminders: [PersistedHealthReminder]

    static let empty = PersistedHealthMetrics(reminders: [])
}

struct PersistedHealthReminder: Codable {
    var id: UUID
    var type: HealthReminderType
    var shownAt: Date
    var outcome: HealthReminderOutcome?
    var outcomeAt: Date?
}
