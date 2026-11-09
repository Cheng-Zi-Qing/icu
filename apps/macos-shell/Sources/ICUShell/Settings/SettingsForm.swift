import Foundation

/// 设置窗口里正在编辑的值（不可变：每次加减都返回新的表单）
struct SettingsForm: Equatable {
    enum Field: CaseIterable {
        case bodyWeight
        case cupVolume
        case workHours
        case eyeInterval
    }

    let profile: HealthProfile
    let timers: ReminderTimerSettings

    /// 护眼间隔可选的分钟数
    static let eyeIntervalChoicesMinutes: [Double] = [10, 15, 20, 25, 30, 45, 60]

    private static let bodyWeightStep = 1.0
    private static let bodyWeightRange: ClosedRange<Double> = 30...200
    private static let cupVolumeStep = 50.0
    private static let cupVolumeRange: ClosedRange<Double> = 100...1000
    private static let workHoursStep = 1.0
    private static let workHoursRange: ClosedRange<Double> = 1...16

    var hydrationPlan: HydrationPlan {
        HydrationPlan(profile: profile)
    }

    var cups: Int {
        hydrationPlan.cups
    }

    /// 「建议上班时喝 6 杯（约 2050 ml）」：体重 × 35 ml 是全天的量，上班时段喝其中 65%
    var hydrationHeadline: String {
        let workMl = Int((hydrationPlan.workWaterMl / 10).rounded()) * 10
        return "建议上班时喝 \(cups) 杯（约 \(workMl) ml）"
    }

    /// 「每 80 分钟提醒一次」
    var hydrationDetail: String {
        "每 \(Int((hydrationPlan.interval / 60).rounded())) 分钟提醒一次"
    }

    func valueText(_ field: Field) -> String {
        switch field {
        case .bodyWeight: return "\(Int(profile.bodyWeightKg.rounded())) kg"
        case .cupVolume: return "\(Int(profile.cupVolumeMl.rounded())) ml"
        case .workHours: return "\(Int(profile.workHours.rounded())) 小时"
        case .eyeInterval: return "\(Int((timers.eyeInterval / 60).rounded())) 分钟"
        }
    }

    /// 换护眼方式；切到自定义时从刚才在用的间隔开始调
    func with(eyeMode: EyeCareMode) -> SettingsForm {
        let custom = eyeMode == .custom ? timers.eyeInterval : timers.customEyeInterval
        return SettingsForm(profile: profile, timers: ReminderTimerSettings(eyeMode: eyeMode, customEyeInterval: custom))
    }

    func canStep(_ field: Field, by direction: Int) -> Bool {
        stepped(field, by: direction) != self
    }

    /// 往 `direction`（+1 / -1）方向走一格；到头了就原样返回
    func stepped(_ field: Field, by direction: Int) -> SettingsForm {
        let sign = Double(direction.signum())
        switch field {
        case .bodyWeight:
            let value = Self.clamped(profile.bodyWeightKg + sign * Self.bodyWeightStep, Self.bodyWeightRange)
            return SettingsForm(profile: HealthProfile(bodyWeightKg: value, cupVolumeMl: profile.cupVolumeMl, workHours: profile.workHours), timers: timers)
        case .cupVolume:
            let value = Self.clamped(profile.cupVolumeMl + sign * Self.cupVolumeStep, Self.cupVolumeRange)
            return SettingsForm(profile: HealthProfile(bodyWeightKg: profile.bodyWeightKg, cupVolumeMl: value, workHours: profile.workHours), timers: timers)
        case .workHours:
            let value = Self.clamped(profile.workHours + sign * Self.workHoursStep, Self.workHoursRange)
            return SettingsForm(profile: HealthProfile(bodyWeightKg: profile.bodyWeightKg, cupVolumeMl: profile.cupVolumeMl, workHours: value), timers: timers)
        case .eyeInterval:
            // 只有自定义模式能调间隔，预设模式锁住
            guard timers.eyeMode == .custom else { return self }
            return SettingsForm(profile: profile, timers: ReminderTimerSettings(eyeInterval: nextEyeInterval(direction: direction)))
        }
    }

    private func nextEyeInterval(direction: Int) -> TimeInterval {
        let current = timers.eyeInterval / 60
        let choices = Self.eyeIntervalChoicesMinutes
        let next = direction > 0 ? choices.first { $0 > current + 0.001 } : choices.last { $0 < current - 0.001 }
        return (next ?? current) * 60
    }

    private static func clamped(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
