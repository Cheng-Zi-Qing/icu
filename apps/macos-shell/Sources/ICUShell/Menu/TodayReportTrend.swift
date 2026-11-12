import Foundation

/// 今日报告里的进度条：喝水、护眼、工时各一条，10 格
struct TodayReportMeter: Equatable {
    enum Kind: Equatable {
        case water
        case eyes
        case hours
    }

    static let segments = 10

    let kind: Kind
    let label: String
    let value: String
    /// 亮几格（0...segments）
    let filled: Int
    /// 超了（工时超出计划）：进度条换成提醒色
    let isOver: Bool

    init(kind: Kind, label: String, value: String, done: Double, goal: Double) {
        self.kind = kind
        self.label = label
        self.value = value
        let share = goal > 0 ? done / goal : 0
        // 做了一点就至少亮一格；没做满不亮满
        let raw = Int((min(1, max(0, share)) * Double(Self.segments)).rounded(.down))
        filled = share > 0 ? max(1, raw) : 0
        isOver = share > 1
    }

    static func meters(for day: HealthDaySummary, cupsGoal: Int, workHours: Double) -> [TodayReportMeter] {
        let text = TextCatalog.shared
        var meters = [TodayReportMeter(
            kind: .water,
            label: text.text("report.meter_water"),
            value: text.format("report.cup_ratio", day.hydrationReminder.completed, cupsGoal),
            done: Double(day.hydrationReminder.completed),
            goal: Double(cupsGoal)
        )]
        if day.eyeReminder.shown > 0 {
            meters.append(TodayReportMeter(
                kind: .eyes,
                label: text.text("report.meter_eyes"),
                value: text.format("report.eye_ratio", day.eyeReminder.completed, day.eyeReminder.shown),
                done: Double(day.eyeReminder.completed),
                goal: Double(day.eyeReminder.shown)
            ))
        }
        let planned = max(1, workHours) * 3600
        meters.append(TodayReportMeter(
            kind: .hours,
            label: text.text("report.meter_hours"),
            value: text.format(
                "report.meter_hours_value",
                TodayReportContent.duration(day.onDutyDuration),
                TodayReportContent.duration(Int(planned))
            ),
            done: Double(day.onDutyDuration),
            goal: planned
        ))
        return meters
    }
}

/// 今日报告里的「本周」：一天一根柱子（上班时长），今天那根高亮，旁边写日均和今天比日均多还是少
struct TodayReportWeek: Equatable {
    struct Bar: Equatable {
        let label: String
        /// 柱子高几格（0...maxLevel）；上过班至少 1 格
        let level: Int
        let isToday: Bool
    }

    static let maxLevel = 8
    /// 今天和日均差不到这么多就不说
    static let noticeableGap = 10 * 60

    let bars: [Bar]
    /// 「4 天 · 日均 7:10」
    let caption: String
    /// 「今天比日均多 0:40」；没有别的天可比、或者差得不多时没有
    let comparison: String?

    /// 这周一天班都没上过就没有这一栏
    init?(week: HealthWeekSummary, today: Date, calendar: Calendar = .current) {
        let active = week.days.filter { $0.onDutyDuration > 0 }
        guard !active.isEmpty else { return nil }
        let longest = active.map(\.onDutyDuration).max() ?? 1
        let labels = TextCatalog.shared.texts("report.weekdays")
        bars = week.days.map { day in
            // 文案里的星期从周一排起；Calendar 的 weekday 周日是 1
            let index = (calendar.component(.weekday, from: day.date) + 5) % 7
            let share = Double(day.onDutyDuration) / Double(longest)
            return Bar(
                label: labels.indices.contains(index) ? labels[index] : "",
                level: day.onDutyDuration > 0 ? max(1, Int((share * Double(Self.maxLevel)).rounded())) : 0,
                isToday: calendar.isDate(day.date, inSameDayAs: today)
            )
        }
        let average = active.map(\.onDutyDuration).reduce(0, +) / active.count
        caption = TextCatalog.shared.format("report.week_caption", active.count, TodayReportContent.duration(average))
        comparison = Self.comparison(active: active, today: today, calendar: calendar)
    }

    /// 今天和这周其他上班日的日均比
    private static func comparison(active: [HealthDaySummary], today: Date, calendar: Calendar) -> String? {
        let others = active.filter { !calendar.isDate($0.date, inSameDayAs: today) }
        guard
            !others.isEmpty,
            let todayDuration = active.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.onDutyDuration
        else { return nil }
        let gap = todayDuration - others.map(\.onDutyDuration).reduce(0, +) / others.count
        guard abs(gap) >= noticeableGap else { return nil }
        return TextCatalog.shared.format(gap > 0 ? "report.week_above" : "report.week_below", TodayReportContent.duration(abs(gap)))
    }
}
