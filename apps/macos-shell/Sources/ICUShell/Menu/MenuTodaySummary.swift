import Foundation

/// 菜单顶上的今日小结：喝了几杯 / 护眼几次 / 工作多久
struct MenuTodaySummary: Equatable {
    let cupsDone: Int
    let cupsGoal: Int
    let eyeBreaks: Int
    let workSeconds: Int

    init(day: HealthDaySummary, cupsGoal: Int) {
        cupsDone = day.hydrationReminder.completed
        self.cupsGoal = cupsGoal
        eyeBreaks = day.eyeReminder.completed
        // 上班到下班一共多久（含专注和休息），和今日报告的「上班」一致
        workSeconds = day.onDutyDuration
    }

    var cupsText: String { "\(cupsDone)/\(cupsGoal) 杯" }
    var eyeText: String { "\(eyeBreaks) 次" }

    /// 「3:20」= 3 小时 20 分
    var workText: String {
        let minutes = max(0, workSeconds) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
