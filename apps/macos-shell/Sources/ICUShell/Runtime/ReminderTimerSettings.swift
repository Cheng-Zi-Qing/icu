import Foundation

/// 护眼方式：两种按研究推荐的预设 + 自定义
enum EyeCareMode: String, CaseIterable, Equatable {
    /// 每 20 分钟看 6 米外 20 秒。美国验光协会 / 美国眼科学会推荐；
    /// Talens-Estarelles et al. 2023（Contact Lens & Anterior Eye 46:101744）：用提醒执行后眼疲劳和干眼症状减轻
    case rule202020 = "20-20-20"
    /// 每工作约一小时离开屏幕歇 5 分钟。NIOSH 现场研究 Galinsky et al. 2000（Ergonomics 43:622）：
    /// 加上短休息后眼酸、视物模糊更少，产出不降
    case hourlyBreak = "hourly_break"
    case custom

    var title: String {
        switch self {
        case .rule202020: return "20-20-20 推荐"
        case .hourlyBreak: return "每小时歇歇"
        case .custom: return "自定义"
        }
    }

    /// 预设的提醒间隔；自定义时为 nil
    var presetInterval: TimeInterval? {
        switch self {
        case .rule202020: return 20 * 60
        case .hourlyBreak: return 60 * 60
        case .custom: return nil
        }
    }

    /// 每次提醒要休息多久（提醒卡倒计时）
    var restSeconds: TimeInterval {
        self == .hourlyBreak ? 5 * 60 : 20
    }

    /// 设置窗口里模式下面那句说明
    var explanation: String {
        switch self {
        case .rule202020:
            return "推荐：每 20 分钟看 6 米外 20 秒。眼科协会推荐，2023 年研究显示能减轻眼疲劳和干眼症状。"
        case .hourlyBreak:
            return "每小时离开屏幕歇 5 分钟。NIOSH 研究：眼酸、视物模糊更少，效率不降。"
        case .custom:
            return "自己定间隔，每次看 6 米外 20 秒。"
        }
    }
}

/// settings.json 里的 `timers`：护眼方式 + 自定义间隔（秒）
struct ReminderTimerSettings: Equatable {
    var eyeMode: EyeCareMode
    /// 自定义模式用的间隔；切到预设时也记着，切回来还在
    var customEyeInterval: TimeInterval

    static let defaultCustomInterval: TimeInterval = 20 * 60
    static let `default` = ReminderTimerSettings(eyeMode: .rule202020)
    static let eyeIntervalRange: ClosedRange<Double> = 60...(4 * 3600)

    init(eyeMode: EyeCareMode, customEyeInterval: TimeInterval = defaultCustomInterval) {
        self.eyeMode = eyeMode
        self.customEyeInterval = customEyeInterval
    }

    /// 自定义间隔
    init(eyeInterval: TimeInterval) {
        self.init(eyeMode: .custom, customEyeInterval: eyeInterval)
    }

    var eyeInterval: TimeInterval {
        eyeMode.presetInterval ?? customEyeInterval
    }

    var eyeRestSeconds: TimeInterval {
        eyeMode.restSeconds
    }

    /// 没写 `eye_mode` 的旧配置：间隔是 20 分钟就当推荐模式，否则当自定义
    init(settingsObject: [String: Any]?) {
        let object = settingsObject?["timers"] as? [String: Any] ?? [:]
        let interval = SettingsValue.number(object["eye_interval"], in: Self.eyeIntervalRange)
        let storedMode = (object["eye_mode"] as? String).flatMap(EyeCareMode.init(rawValue:))
        let legacyMode: EyeCareMode = (interval != nil && interval != Self.defaultCustomInterval) ? .custom : .rule202020
        let hasModeKey = object["eye_mode"] != nil
        self.init(
            eyeMode: storedMode ?? (hasModeKey ? .rule202020 : legacyMode),
            customEyeInterval: interval ?? Self.defaultCustomInterval
        )
    }
}
