import Foundation

/// 今日报告顶上的评分：喝水、护眼、休息、工时四项各占一份，加起来 0–100 分
struct TodayScore: Equatable {
    enum Grade: String, Equatable {
        case great
        case good
        case okay
        case tired
        /// 刚上班不到半小时，什么都说不准，先不打分
        case warmingUp = "warming_up"
    }

    /// 四项的权重（加起来 100）
    enum Weight {
        static let water = 35.0
        static let eyes = 30.0
        static let rest = 20.0
        static let hours = 15.0
    }

    static let greatFrom = 85
    static let goodFrom = 70
    static let okayFrom = 50
    /// 干多久该休息一次
    static let restEvery: TimeInterval = 2 * 3600
    /// 超过计划工时这么久，工时那一项扣到 0
    static let overtimeToZero: TimeInterval = 3 * 3600

    /// 0–100；还没开始评时为 nil
    let points: Int?
    let grade: Grade

    var title: String { TextCatalog.shared.text("report.score_\(grade.rawValue)") }
    var caption: String { TextCatalog.shared.text("report.score_caption_\(grade.rawValue)") }
    var pointsText: String? { points.map { TextCatalog.shared.format("report.score_points", $0) } }

    init(day: HealthDaySummary, cupsGoal: Int, workHours: Double) {
        let onDuty = TimeInterval(day.onDutyDuration)
        guard onDuty >= TodayAdvice.warmUp else {
            points = nil
            grade = .warmingUp
            return
        }
        let planned = max(1, workHours) * 3600
        let total = Weight.water * Self.waterShare(day: day, cupsGoal: cupsGoal, onDuty: onDuty, planned: planned)
            + Weight.eyes * Self.eyeShare(day: day, onDuty: onDuty)
            + Weight.rest * Self.restShare(day: day)
            + Weight.hours * Self.hoursShare(onDuty: onDuty, planned: planned)
        let rounded = Int(total.rounded())
        points = rounded
        grade = rounded >= Self.greatFrom ? .great : rounded >= Self.goodFrom ? .good : rounded >= Self.okayFrom ? .okay : .tired
    }

    /// 按上班进度该喝的杯数喝到了多少（还不到该喝第一杯的时候算满分）
    static func waterShare(day: HealthDaySummary, cupsGoal: Int, onDuty: TimeInterval, planned: TimeInterval) -> Double {
        let expected = TodayAdvice.expectedCups(cupsGoal: cupsGoal, onDuty: onDuty, plannedSeconds: planned)
        guard expected > 0 else { return 1 }
        return min(1, Double(day.hydrationReminder.completed) / Double(expected))
    }

    /// 护眼提醒做了几成；一次都没提醒过时，盯屏太久算 0，否则算满分
    static func eyeShare(day: HealthDaySummary, onDuty: TimeInterval) -> Double {
        let eye = day.eyeReminder
        guard eye.shown > 0 else { return onDuty >= TodayAdvice.eyeStretch ? 0 : 1 }
        return min(1, eye.completionRate)
    }

    /// 每干两小时该休息一次，休息了几成
    static func restShare(day: HealthDaySummary) -> Double {
        let expected = Int(TimeInterval(day.workDuration + day.focusDuration) / restEvery)
        guard expected > 0 else { return 1 }
        return min(1, Double(day.breakCount) / Double(expected))
    }

    /// 没超计划工时满分；超出越多越低，超 3 小时扣完
    static func hoursShare(onDuty: TimeInterval, planned: TimeInterval) -> Double {
        let over = onDuty - planned - TodayAdvice.overtimeGrace
        guard over > 0 else { return 1 }
        return max(0, 1 - over / overtimeToZero)
    }
}
