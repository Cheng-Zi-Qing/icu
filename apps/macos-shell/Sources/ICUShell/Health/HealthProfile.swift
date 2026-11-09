import Foundation

/// settings.json 里的 `user`：算喝水建议用的个人信息
struct HealthProfile: Equatable {
    var bodyWeightKg: Double
    var cupVolumeMl: Double
    var workHours: Double

    static let `default` = HealthProfile(bodyWeightKg: 70, cupVolumeMl: 300, workHours: 8)

    static let bodyWeightRange: ClosedRange<Double> = 20...300
    static let cupVolumeRange: ClosedRange<Double> = 50...2000
    static let workHoursRange: ClosedRange<Double> = 1...16

    init(bodyWeightKg: Double, cupVolumeMl: Double, workHours: Double) {
        self.bodyWeightKg = bodyWeightKg
        self.cupVolumeMl = cupVolumeMl
        self.workHours = workHours
    }

    /// 从 settings.json 的根对象解析；缺失或非法的字段逐项回退到默认值
    init(settingsObject: [String: Any]?) {
        let fallback = Self.default
        let object = settingsObject?["user"] as? [String: Any] ?? [:]

        bodyWeightKg = SettingsValue.number(object["body_weight"], in: Self.bodyWeightRange) ?? fallback.bodyWeightKg
        cupVolumeMl = SettingsValue.number(object["cup_volume"], in: Self.cupVolumeRange) ?? fallback.cupVolumeMl
        workHours = SettingsValue.number(object["work_hours"], in: Self.workHoursRange) ?? fallback.workHours
    }
}
