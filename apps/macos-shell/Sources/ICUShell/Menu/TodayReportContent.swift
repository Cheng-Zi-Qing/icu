import Foundation

/// 今日报告要显示的东西：顶上的结论、一行一项的数、底下的本机累计。不碰 AppKit，方便测
struct TodayReportContent: Equatable {
    enum RowKind: Equatable {
        case onDuty
        case span
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

    let advice: [TodayAdvice]
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
        calendar: Calendar = .current
    ) {
        let goal = max(0, cupsGoal)
        advice = TodayAdvice.advise(day: day, cupsGoal: goal, workHours: workHours)
        rows = Self.rows(for: day, cupsGoal: goal, isOnDuty: isOnDuty, calendar: calendar)
        footer = lifetime.flatMap { $0.workedDayCount > 0 ? "累计 \($0.workedDayCount) 天 · \(Self.duration($0.onDutyDuration))" : nil }
        hasActivity = day.hasActivity
    }

    /// 读屏用：结论在前，数在后
    var accessibilityText: String {
        let parts = advice.map(\.text) + rows.map { "\($0.label) \($0.value)" } + [footer].compactMap { $0 }
        return "今日报告：" + parts.joined(separator: "，")
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
            onDuty += " · \(day.shiftCount) 段"
        }
        var rows = [Row(kind: .onDuty, label: "上班", value: onDuty)]

        if let span = spanText(day: day, isOnDuty: isOnDuty, calendar: calendar) {
            rows.append(Row(kind: .span, label: "时段", value: span))
        }
        if day.focusCount > 0 || day.focusDuration > 0 {
            rows.append(Row(kind: .focus, label: "专注", value: "\(day.focusCount) 次 · \(duration(day.focusDuration))"))
        }
        if day.breakCount > 0 || day.breakDuration > 0 {
            rows.append(Row(kind: .rest, label: "休息", value: "\(day.breakCount) 次 · \(duration(day.breakDuration))"))
        }
        if day.eyeReminder.shown > 0 {
            rows.append(Row(kind: .eyes, label: "护眼", value: "\(day.eyeReminder.completed)/\(day.eyeReminder.shown) 次"))
        }
        rows.append(Row(kind: .water, label: "喝水", value: "\(day.hydrationReminder.completed)/\(cupsGoal) 杯"))
        return rows
    }

    /// 「09:12–18:30」：第一次上班到最后一次下班；还在上班就是「09:12–现在」
    private static func spanText(day: HealthDaySummary, isOnDuty: Bool, calendar: Calendar) -> String? {
        guard let start = day.firstClockInAt else { return nil }
        let end: String
        if isOnDuty {
            end = "现在"
        } else if let clockOut = day.lastClockOutAt {
            end = clock(clockOut, calendar: calendar)
        } else {
            return nil
        }
        return "\(clock(start, calendar: calendar))–\(end)"
    }

    private static func clock(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
