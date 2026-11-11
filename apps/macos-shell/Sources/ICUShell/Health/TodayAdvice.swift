import Foundation

/// 今日报告顶上的一句小结论：该补水了、眼睛该放松了……
struct TodayAdvice: Equatable {
    enum Topic: Equatable {
        case water
        case eyes
        case rest
        case overtime
        /// 提醒总是「等会儿」
        case snoozing
        case allGood
    }

    enum Tone: Equatable {
        /// 该做点什么
        case act
        /// 做得不错
        case good
    }

    let topic: Topic
    let tone: Tone
    let text: String

    /// 最多给几句：再多就没人看了
    static let maxCount = 3
    /// 「做得好」最多列几条
    static let maxPraise = 2
    /// 提醒推迟这么多次就说一句
    static let snoozedOften = 3

    /// 上班多久以后才开始评（刚上班几分钟，什么都说不准）
    static let warmUp: TimeInterval = 30 * 60
    /// 盯屏这么久一次护眼都没做，就提醒
    static let eyeStretch: TimeInterval = 2 * 3600
    /// 上班这么久一次没休息，就提醒
    static let restStretch: TimeInterval = 2 * 3600
    /// 超过计划工时这么久算加班
    static let overtimeGrace: TimeInterval = 30 * 60
    /// 护眼完成率低于这个就提醒
    static let lowEyeRate = 0.5
    /// 护眼完成率到这个算做得好
    static let goodEyeRate = 0.8

    /// 按今天的数给结论：先说该做的（补水 → 护眼 → 休息 → 加班），没有就说做得好的
    static func advise(day: HealthDaySummary, cupsGoal: Int, workHours: Double) -> [TodayAdvice] {
        let onDuty = TimeInterval(day.onDutyDuration)
        let plannedSeconds = max(1, workHours) * 3600
        let actions = [
            water(day: day, cupsGoal: cupsGoal, onDuty: onDuty, plannedSeconds: plannedSeconds),
            eyes(day: day, onDuty: onDuty),
            rest(day: day),
            overtime(onDuty: onDuty, plannedSeconds: plannedSeconds),
            snoozing(day: day),
        ].compactMap { $0 }
        if !actions.isEmpty {
            return Array(actions.prefix(maxCount))
        }

        let praise = praise(day: day, cupsGoal: cupsGoal, workHours: workHours)
        return praise.isEmpty
            ? [TodayAdvice(topic: .allGood, tone: .good, text: TextCatalog.shared.text("advice.all_good"))]
            : praise
    }

    /// 今天做得好的地方（有该做的事时也照样列出来，报告里单独一栏）
    static func praise(day: HealthDaySummary, cupsGoal: Int, workHours: Double) -> [TodayAdvice] {
        let onDuty = TimeInterval(day.onDutyDuration)
        let plannedSeconds = max(1, workHours) * 3600
        let busy = TimeInterval(day.workDuration + day.focusDuration)
        func good(_ topic: Topic, _ key: String) -> TodayAdvice {
            TodayAdvice(topic: topic, tone: .good, text: TextCatalog.shared.text(key))
        }
        let praise = [
            day.hydrationReminder.completed >= cupsGoal && cupsGoal > 0 ? good(.water, "advice.water_done") : nil,
            day.eyeReminder.shown > 0 && day.eyeReminder.completionRate >= goodEyeRate ? good(.eyes, "advice.eyes_done") : nil,
            busy >= restStretch && day.breakCount >= Int(busy / restStretch) ? good(.rest, "advice.rest_done") : nil,
            onDuty >= plannedSeconds * 0.75 && onDuty <= plannedSeconds + overtimeGrace ? good(.overtime, "advice.hours_done") : nil,
        ].compactMap { $0 }
        return Array(praise.prefix(maxPraise))
    }

    /// 按上班进度该喝几杯（上班一半就该喝一半），比这少就提醒
    static func expectedCups(cupsGoal: Int, onDuty: TimeInterval, plannedSeconds: TimeInterval) -> Int {
        let progress = min(1, max(0, onDuty / plannedSeconds))
        return Int((Double(max(0, cupsGoal)) * progress).rounded(.down))
    }

    private static func water(day: HealthDaySummary, cupsGoal: Int, onDuty: TimeInterval, plannedSeconds: TimeInterval) -> TodayAdvice? {
        guard onDuty >= warmUp else { return nil }
        let behind = expectedCups(cupsGoal: cupsGoal, onDuty: onDuty, plannedSeconds: plannedSeconds) - day.hydrationReminder.completed
        guard behind > 0 else { return nil }
        return TodayAdvice(topic: .water, tone: .act, text: TextCatalog.shared.format("advice.water_behind", behind))
    }

    private static func eyes(day: HealthDaySummary, onDuty: TimeInterval) -> TodayAdvice? {
        let eye = day.eyeReminder
        let skippedMost = eye.shown >= 2 && eye.completionRate < lowEyeRate
        let neverRested = onDuty >= eyeStretch && eye.completed == 0
        guard skippedMost || neverRested else { return nil }
        return TodayAdvice(topic: .eyes, tone: .act, text: TextCatalog.shared.text("advice.eyes_rest"))
    }

    private static func rest(day: HealthDaySummary) -> TodayAdvice? {
        let busy = TimeInterval(day.workDuration + day.focusDuration)
        guard busy >= restStretch, day.breakCount == 0 else { return nil }
        return TodayAdvice(topic: .rest, tone: .act, text: TextCatalog.shared.text("advice.rest_break"))
    }

    private static func snoozing(day: HealthDaySummary) -> TodayAdvice? {
        let snoozed = day.eyeReminder.snoozed + day.hydrationReminder.snoozed
        guard snoozed >= snoozedOften else { return nil }
        return TodayAdvice(topic: .snoozing, tone: .act, text: TextCatalog.shared.format("advice.snoozed_often", snoozed))
    }

    private static func overtime(onDuty: TimeInterval, plannedSeconds: TimeInterval) -> TodayAdvice? {
        guard onDuty > plannedSeconds + overtimeGrace else { return nil }
        return TodayAdvice(topic: .overtime, tone: .act, text: TextCatalog.shared.text("advice.overtime"))
    }
}
