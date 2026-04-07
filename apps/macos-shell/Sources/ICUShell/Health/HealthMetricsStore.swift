import Foundation

private struct PersistedSessionDayMetrics: Codable {
    var workDuration: Int
    var focusCount: Int
    var focusDuration: Int
    var breakCount: Int

    static let empty = PersistedSessionDayMetrics(workDuration: 0, focusCount: 0, focusDuration: 0, breakCount: 0)
}

private struct PersistedHealthMetricsDocument: Codable {
    var reminders: [PersistedHealthReminder]
    var sessionDays: [String: PersistedSessionDayMetrics]

    static let empty = PersistedHealthMetricsDocument(reminders: [], sessionDays: [:])

    private enum CodingKeys: String, CodingKey {
        case reminders
        case sessionDays = "session_days"
    }

    init(reminders: [PersistedHealthReminder], sessionDays: [String: PersistedSessionDayMetrics]) {
        self.reminders = reminders
        self.sessionDays = sessionDays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reminders = try container.decodeIfPresent([PersistedHealthReminder].self, forKey: .reminders) ?? []
        sessionDays = try container.decodeIfPresent([String: PersistedSessionDayMetrics].self, forKey: .sessionDays) ?? [:]
    }
}

private enum HealthDaySummarySessionCache {
    private static let lock = NSLock()
    private static var valuesByDate: [Date: PersistedSessionDayMetrics] = [:]

    static func store(_ value: PersistedSessionDayMetrics, for date: Date) {
        lock.lock()
        valuesByDate[date] = value
        lock.unlock()
    }

    static func value(for date: Date) -> PersistedSessionDayMetrics {
        lock.lock()
        let value = valuesByDate[date] ?? .empty
        lock.unlock()
        return value
    }
}

extension HealthDaySummary {
    var workDuration: Int {
        HealthDaySummarySessionCache.value(for: date).workDuration
    }

    var focusCount: Int {
        HealthDaySummarySessionCache.value(for: date).focusCount
    }

    var focusDuration: Int {
        HealthDaySummarySessionCache.value(for: date).focusDuration
    }

    var breakCount: Int {
        HealthDaySummarySessionCache.value(for: date).breakCount
    }
}

final class HealthMetricsStore {
    private let appPaths: AppPaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let calendar: Calendar
    private let queue: DispatchQueue
    private let diagnostics: (String) -> Void
    private let dayKeyFormatter: DateFormatter

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

        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utcCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayKeyFormatter = formatter

        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // TODO(health-metrics): Retention/compaction is intentionally deferred for Task 1.
        // Keep raw events for now until product policy defines archival window and report guarantees.

        try appPaths.ensureDirectories(fileManager: fileManager)
    }

    func recordReminderShown(id: UUID, type: HealthReminderType, at date: Date) throws {
        var pendingDiagnostics: [String] = []
        try queue.sync {
            var metrics = try loadMetrics(pendingDiagnostics: &pendingDiagnostics)
            guard !metrics.reminders.contains(where: { $0.id == id }) else {
                pendingDiagnostics.append("Ignoring duplicate shown event for reminder id \(id.uuidString)")
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
        emitDiagnostics(pendingDiagnostics)
    }

    func recordReminderOutcome(id: UUID, outcome: HealthReminderOutcome, at date: Date) throws {
        var pendingDiagnostics: [String] = []
        try queue.sync {
            var metrics = try loadMetrics(pendingDiagnostics: &pendingDiagnostics)
            guard let reminderIndex = metrics.reminders.firstIndex(where: { $0.id == id }) else {
                pendingDiagnostics.append("Ignoring outcome for unknown reminder id \(id.uuidString)")
                return
            }

            guard metrics.reminders[reminderIndex].outcome == nil else {
                pendingDiagnostics.append("Ignoring duplicate outcome for reminder id \(id.uuidString)")
                return
            }

            metrics.reminders[reminderIndex].outcome = outcome
            metrics.reminders[reminderIndex].outcomeAt = date
            try saveMetrics(metrics)
        }
        emitDiagnostics(pendingDiagnostics)
    }

    func settleWorkDuration(seconds: TimeInterval, at date: Date) throws {
        try mutateSessionDay(at: date) { day in
            day.workDuration += durationSeconds(from: seconds)
        }
    }

    func settleFocusDuration(seconds: TimeInterval, at date: Date) throws {
        try mutateSessionDay(at: date) { day in
            day.focusDuration += durationSeconds(from: seconds)
        }
    }

    func recordFocusSessionStart(at date: Date) throws {
        try mutateSessionDay(at: date) { day in
            day.focusCount += 1
        }
    }

    func recordBreakStart(at date: Date) throws {
        try mutateSessionDay(at: date) { day in
            day.breakCount += 1
        }
    }

    func daySummary(for date: Date) throws -> HealthDaySummary {
        var pendingDiagnostics: [String] = []
        let summary = try queue.sync {
            let startOfDay = calendar.startOfDay(for: date)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                HealthDaySummarySessionCache.store(.empty, for: startOfDay)
                return HealthDaySummary(date: startOfDay, eyeReminder: .empty)
            }

            let metrics = try loadMetrics(pendingDiagnostics: &pendingDiagnostics)
            let counts = aggregateReminderCounts(from: startOfDay, to: nextDay, metrics: metrics)
            let sessionMetrics = aggregateSessionTotals(from: startOfDay, to: nextDay, metrics: metrics)
            HealthDaySummarySessionCache.store(sessionMetrics, for: startOfDay)

            return HealthDaySummary(date: startOfDay, eyeReminder: counts)
        }
        emitDiagnostics(pendingDiagnostics)
        return summary
    }

    func weekSummary(containing date: Date) throws -> HealthWeekSummary {
        var pendingDiagnostics: [String] = []
        let summary = try queue.sync {
            let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            let weekStart = calendar.date(from: weekComponents) ?? calendar.startOfDay(for: date)
            let weekEndExclusive = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let metrics = try loadMetrics(pendingDiagnostics: &pendingDiagnostics)
            let counts = aggregateReminderCounts(from: weekStart, to: weekEndExclusive, metrics: metrics)

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
        emitDiagnostics(pendingDiagnostics)
        return summary
    }

    private var metricsFileURL: URL {
        appPaths.stateDirectory.appendingPathComponent("health_metrics.json", isDirectory: false)
    }

    private func mutateSessionDay(at date: Date, _ mutate: (inout PersistedSessionDayMetrics) -> Void) throws {
        var pendingDiagnostics: [String] = []
        try queue.sync {
            var metrics = try loadMetrics(pendingDiagnostics: &pendingDiagnostics)
            let key = dayKey(for: date)
            var dayMetrics = metrics.sessionDays[key] ?? .empty
            mutate(&dayMetrics)
            metrics.sessionDays[key] = dayMetrics
            try saveMetrics(metrics)
        }
        emitDiagnostics(pendingDiagnostics)
    }

    private func aggregateReminderCounts(from start: Date, to end: Date, metrics: PersistedHealthMetricsDocument) -> HealthReminderCounts {
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

    private func aggregateSessionTotals(from start: Date, to end: Date, metrics: PersistedHealthMetricsDocument) -> PersistedSessionDayMetrics {
        var aggregate = PersistedSessionDayMetrics.empty
        var day = start

        while day < end {
            let key = dayKey(for: day)
            if let value = metrics.sessionDays[key] {
                aggregate.workDuration += value.workDuration
                aggregate.focusCount += value.focusCount
                aggregate.focusDuration += value.focusDuration
                aggregate.breakCount += value.breakCount
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return aggregate
    }

    private func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: calendar.startOfDay(for: date))
    }

    private func durationSeconds(from interval: TimeInterval) -> Int {
        max(0, Int(interval.rounded(.down)))
    }

    private func loadMetrics(pendingDiagnostics: inout [String]) throws -> PersistedHealthMetricsDocument {
        guard fileManager.fileExists(atPath: metricsFileURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: metricsFileURL)
            return try decoder.decode(PersistedHealthMetricsDocument.self, from: data)
        } catch {
            let backupURL = appPaths.stateDirectory.appendingPathComponent(
                "health_metrics.corrupt-\(UUID().uuidString).json",
                isDirectory: false
            )
            do {
                try fileManager.moveItem(at: metricsFileURL, to: backupURL)
                pendingDiagnostics.append(
                    "Recovered from corrupt health metrics; moved file to \(backupURL.lastPathComponent)"
                )
            } catch {
                pendingDiagnostics.append(
                    "Recovered from corrupt health metrics without quarantine: \(error.localizedDescription)"
                )
            }
            return .empty
        }
    }

    private func saveMetrics(_ metrics: PersistedHealthMetricsDocument) throws {
        let data = try encoder.encode(metrics)
        try data.write(to: metricsFileURL, options: .atomic)
    }

    private func emitDiagnostics(_ pendingDiagnostics: [String]) {
        for message in pendingDiagnostics {
            diagnostics(message)
        }
    }

    private static func defaultDiagnostics(_ message: String) {
        NSLog("[HealthMetricsStore] %@", message)
    }
}
