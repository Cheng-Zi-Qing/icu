import Foundation

/// settings.json 里的 `timers`：护眼提醒间隔（秒）
struct ReminderTimerSettings: Equatable {
    var eyeInterval: TimeInterval

    /// 20-20-20 法则：每 20 分钟看一次远处
    static let `default` = ReminderTimerSettings(eyeInterval: 20 * 60)

    static let eyeIntervalRange: ClosedRange<Double> = 60...(4 * 3600)

    init(eyeInterval: TimeInterval) {
        self.eyeInterval = eyeInterval
    }

    init(settingsObject: [String: Any]?) {
        let object = settingsObject?["timers"] as? [String: Any] ?? [:]
        eyeInterval = SettingsValue.number(object["eye_interval"], in: Self.eyeIntervalRange)
            ?? Self.default.eyeInterval
    }
}
