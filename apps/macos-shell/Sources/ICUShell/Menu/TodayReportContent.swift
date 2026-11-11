import Foundation

/// 今日报告要显示的东西：评分、进度条、明细、本周趋势、建议和做得好的地方、本机累计。不碰 AppKit，方便测
struct TodayReportContent: Equatable {
    enum RowKind: Equatable {
        case onDuty
        case span
        /// 一段上下班打卡
        case shift
        case focus
        case rest
        case eyes
        case water
    }

    struct Row: Equatable {
        let kind: RowKind
        let label: String
        let value: String
    }

    let score: TodayScore
    let meters: [TodayReportMeter]
    let advice: [TodayAdvice]
    /// 有该做的事时，做得好的地方单独列一栏（没有该做的事时，`advice` 本身就是夸奖）
    let praise: [TodayAdvice]
    let week: TodayReportWeek?
    let rows: [Row]
    /// 「累计 12 天 · 86:30」；没读到累计就没有
    let footer: String?
    let hasActivity: Bool

    init(
        day: HealthDaySummary,
        lifetime: HealthLifetimeSummary?,
        cupsGoal: Int,
        workHours: Double,
        isOnDuty: Bool,
        week: HealthWeekSummary? = nil,
        calendar: Calendar = .current
    ) {
        let goal = max(0, cupsGoal)
        score = TodayScore(day: day, cupsGoal: goal, workHours: workHours)
        meters = TodayReportMeter.meters(for: day, cupsGoal: goal, workHours: workHours)
        advice = TodayAdvice.advise(day: day, cupsGoal: goal, workHours: workHours)
        praise = advice.contains { $0.tone == .act } ? TodayAdvice.praise(day: day, cupsGoal: goal, workHours: workHours) : []
        self.week = week.flatMap { TodayReportWeek(week: $0, today: day.date, calendar: calendar) }
        rows = Self.rows(for: day, cupsGoal: goal, isOnDuty: isOnDuty, calendar: calendar)
        footer = lifetime.flatMap {
            $0.workedDayCount > 0
                ? TextCatalog.shared.format("report.footer_lifetime", $0.workedDayCount, Self.duration($0.onDutyDuration))
                : nil
        }
        hasActivity = day.hasActivity
    }

    /// 明细里画哪几行：喝水、护眼已经有进度条了，不再重复
    var detailRows: [Row] {
        rows.filter { $0.kind != .water && $0.kind != .eyes }
    }

    /// 读屏用：评分和结论在前，数在后
    var accessibilityText: String {
        let headline = [score.pointsText, score.title].compactMap { $0 }
        let trend = [week?.caption, week?.comparison].compactMap { $0 }
        let parts = headline + (advice + praise).map(\.text) + rows.map { "\($0.label) \($0.value)" } + trend + [footer].compactMap { $0 }
        let separator = TextCatalog.shared.text("common.accessibility_separator")
        return TextCatalog.shared.text("report.accessibility_prefix") + parts.joined(separator: separator)
    }

    /// 「3:20」= 3 小时 20 分
    static func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// 没数据的行不画：上班和喝水两行永远在
    private static func rows(for day: HealthDaySummary, cupsGoal: Int, isOnDuty: Bool, calendar: Calendar) -> [Row] {
        var onDuty = duration(day.onDutyDuration)
        if day.shiftCount > 1 {
            onDuty += " · " + TextCatalog.shared.format("report.shift_segments", day.shiftCount)
        }
        var rows = [Row(kind: .onDuty, label: TextCatalog.shared.text("report.row_on_duty"), value: onDuty)]

        // 每段都有打卡记录就逐段列；老版本记的段没有逐段打卡，先留着「最早上班–最晚下班」那一行
        if day.shifts.count < day.shiftCount, let span = spanText(day: day, isOnDuty: isOnDuty, calendar: calendar) {
            rows.append(Row(kind: .span, label: TextCatalog.shared.text("report.row_span"), value: span))
        }
        rows += shiftRows(day.shifts, isOnDuty: isOnDuty, calendar: calendar)
        if day.focusCount > 0 || day.focusDuration > 0 {
            rows.append(Row(
                kind: .focus,
                label: TextCatalog.shared.text("report.row_focus"),
                value: TextCatalog.shared.format("report.count_and_duration", day.focusCount, duration(day.focusDuration))
            ))
        }
        if day.breakCount > 0 || day.breakDuration > 0 {
            rows.append(Row(
                kind: .rest,
                label: TextCatalog.shared.text("report.row_rest"),
                value: TextCatalog.shared.format("report.count_and_duration", day.breakCount, duration(day.breakDuration))
            ))
        }
        if day.eyeReminder.shown > 0 {
            rows.append(Row(
                kind: .eyes,
                label: TextCatalog.shared.text("report.row_eyes"),
                value: TextCatalog.shared.format("report.eye_ratio", day.eyeReminder.completed, day.eyeReminder.shown)
            ))
        }
        rows.append(Row(
            kind: .water,
            label: TextCatalog.shared.text("report.row_water"),
            value: TextCatalog.shared.format("report.cup_ratio", day.hydrationReminder.completed, cupsGoal)
        ))
        return rows
    }

    /// 老版本记的天没有逐段打卡：「09:12–18:30」第一次上班到最后一次下班；还在上班就是「09:12–现在」，
    /// 下班没记上（意外退出）就只写几点上的班
    private static func spanText(day: HealthDaySummary, isOnDuty: Bool, calendar: Calendar) -> String? {
        guard let start = day.firstClockInAt else { return nil }
        let startText = clock(start, calendar: calendar)
        if isOnDuty {
            return "\(startText)–\(TextCatalog.shared.text("report.now"))"
        }
        guard let clockOut = day.lastClockOutAt else {
            return TextCatalog.shared.format("report.span_since", startText)
        }
        return "\(startText)–\(clock(clockOut, calendar: calendar))"
    }

    /// 每段上下班一行：「09:12–12:01」「13:04–现在」；意外退出补的下班后面注一句。标签只写在第一行
    private static func shiftRows(_ shifts: [WorkShift], isOnDuty: Bool, calendar: Calendar) -> [Row] {
        shifts.sorted { $0.clockInAt < $1.clockInAt }.enumerated().map { index, shift in
            Row(
                kind: .shift,
                label: index == 0 ? TextCatalog.shared.text("report.row_shifts") : "",
                value: shiftText(shift, isOnDuty: isOnDuty, calendar: calendar)
            )
        }
    }

    private static func shiftText(_ shift: WorkShift, isOnDuty: Bool, calendar: Calendar) -> String {
        let start = clock(shift.clockInAt, calendar: calendar)
        guard let clockOut = shift.clockOutAt else {
            // 正在上的这段；没在上班却还开着（还没补上下班）就写到最后确认的时刻
            let end = isOnDuty ? TextCatalog.shared.text("report.now") : clock(shift.lastSeenAt, calendar: calendar)
            return "\(start)–\(end)"
        }
        let range = "\(start)–\(clock(clockOut, calendar: calendar))"
        return shift.endedUnexpectedly ? TextCatalog.shared.format("report.shift_interrupted", range) : range
    }

    private static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
