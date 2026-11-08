import Foundation

/// 喝水建议：每天喝多少、工作时段分几杯、多久提醒一次
struct HydrationPlan: Equatable {
    /// 每公斤体重每天需要的水（ml）
    static let waterPerKgMl = 35.0
    /// 工作时段应该喝掉全天的多少
    static let workShare = 0.65

    let dailyWaterMl: Double
    let workWaterMl: Double
    let cups: Int
    let interval: TimeInterval

    init(profile: HealthProfile) {
        let daily = profile.bodyWeightKg * Self.waterPerKgMl
        let work = daily * Self.workShare
        let cups = max(1, Int((work / profile.cupVolumeMl).rounded(.up)))

        dailyWaterMl = daily
        workWaterMl = work
        self.cups = cups
        interval = profile.workHours * 3600 / Double(cups)
    }
}
