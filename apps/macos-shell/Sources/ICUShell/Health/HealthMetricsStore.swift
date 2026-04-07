import Foundation

final class HealthMetricsStore {
    private let appPaths: AppPaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let calendar: Calendar
    private let queue: DispatchQueue
    private let diagnostics: (String) -> Void

    init(
        appPaths: AppPaths,
        fileManager: FileManager = .default,
        diagnostics: @escaping (String) -> Void = HealthMetricsStore.defaultDiagnostics
    ) throws {
        self.appPaths = appPaths
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.queue = DispatchQueue(label: "icu.health-metrics-store")
        self.diagnostics = diagnostics

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        self.calendar = utcCalendar

        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try appPaths.ensureDirectories(fileManager: fileManager)
    }

    func recordReminderShown(id: UUID, type: HealthReminderType, at date: Date) throws {
        try queue.sync {
            var metrics = try loadMetrics()
            guard !metrics.reminders.contains(where: { $0.id == id }) else {
                diagnostics("Ignoring duplicate shown event for reminder id \(id.uuidString)")
                return
            }

            metrics.reminders.append(
                PersistedHealthReminder(
                    id: id,
                    type: type,
                    shownAt: date,
                    outcome: nil,
                    outcomeAt: nil
                )
            )
            try saveMetrics(metrics)
        }
    }

    func recordReminderOutcome(id: UUID, outcome: HealthReminderOutcome, at date: Date) throws {
        try queue.sync {
            var metrics = try loadMetrics()
            guard let reminderIndex = metrics.reminders.firstIndex(where: { $0.id == id }) else {
                diagnostics("Ignoring outcome for unknown reminder id \(id.uuidString)")
                return
            }

            guard metrics.reminders[reminderIndex].outcome == nil else {
                diagnostics("Ignoring duplicate outcome for reminder id \(id.uuidString)")
                return
            }

            metrics.reminders[reminderIndex].outcome = outcome
            metrics.reminders[reminderIndex].outcomeAt = date
            try saveMetrics(metrics)
        }
    }

    func daySummary(for date: Date) throws -> HealthDaySummary {
        try queue.sync {
            let startOfDay = calendar.startOfDay(for: date)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return HealthDaySummary(date: startOfDay, eyeReminder: .empty)
            }

            let counts = try aggregateReminderCounts(from: startOfDay, to: nextDay)
            return HealthDaySummary(date: startOfDay, eyeReminder: counts)
        }
    }

    func weekSummary(containing date: Date) throws -> HealthWeekSummary {
        try queue.sync {
            let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let weekStart = calendar.date(from: weekComponents) ?? calendar.startOfDay(for: date)
            let weekEndExclusive = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let counts = try aggregateReminderCounts(from: weekStart, to: weekEndExclusive)

            let completionRate: Double
            if counts.shown > 0 {
                completionRate = Double(counts.completed) / Double(counts.shown)
            } else {
                completionRate = 0
            }

            return HealthWeekSummary(
                weekStartDate: weekStart,
                weekEndExclusiveDate: weekEndExclusive,
                eyeReminder: counts,
                eyeReminderCompletionRate: completionRate
            )
        }
    }

    private var metricsFileURL: URL {
        appPaths.stateDirectory.appendingPathComponent("health_metrics.json", isDirectory: false)
    }

    private func aggregateReminderCounts(from start: Date, to end: Date) throws -> HealthReminderCounts {
        let metrics = try loadMetrics()
        let filtered = metrics.reminders.filter { reminder in
            reminder.type == .eyeCare && reminder.shownAt >= start && reminder.shownAt < end
        }

        var counts = HealthReminderCounts.empty
        counts.shown = filtered.count

        for reminder in filtered {
            switch reminder.outcome {
            case .shown:
                break
            case .completed:
                counts.completed += 1
            case .snoozed:
                counts.snoozed += 1
            case .skipped:
                counts.skipped += 1
            case .none:
                break
            }
        }

        return counts
    }

    private func loadMetrics() throws -> PersistedHealthMetrics {
        guard fileManager.fileExists(atPath: metricsFileURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: metricsFileURL)
            return try decoder.decode(PersistedHealthMetrics.self, from: data)
        } catch {
            let backupURL = appPaths.stateDirectory.appendingPathComponent(
                "health_metrics.corrupt-\(UUID().uuidString).json",
                isDirectory: false
            )
            do {
                try fileManager.moveItem(at: metricsFileURL, to: backupURL)
                diagnostics(
                    "Recovered from corrupt health metrics; moved file to \(backupURL.lastPathComponent)"
                )
                return .empty
            } catch {
                diagnostics("Failed to quarantine corrupt health metrics: \(error.localizedDescription)")
                throw error
            }
        }
    }

    private func saveMetrics(_ metrics: PersistedHealthMetrics) throws {
        let data = try encoder.encode(metrics)
        try data.write(to: metricsFileURL, options: .atomic)
    }

    private static func defaultDiagnostics(_ message: String) {
        fputs("[HealthMetricsStore] \(message)\n", stderr)
    }
}
