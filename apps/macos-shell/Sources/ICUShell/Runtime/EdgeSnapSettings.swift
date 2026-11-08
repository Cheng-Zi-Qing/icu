import CoreGraphics
import Foundation

/// settings.json 里的 `edge_snap`：贴边吸附与自动藏边
struct EdgeSnapSettings: Equatable {
    var isEnabled: Bool
    /// 身体离屏幕边多近（pt）松手就吸过去
    var snapDistance: CGFloat
    /// 藏边后还露在屏幕上的身体宽度（pt）
    var peekWidth: CGFloat
    /// 贴边后多久没碰它就藏进去（秒）
    var autoHideDelay: TimeInterval

    static let `default` = EdgeSnapSettings(isEnabled: true, snapDistance: 20, peekWidth: 40, autoHideDelay: 2)

    private static let snapDistanceRange: ClosedRange<Double> = 0...200
    private static let peekWidthRange: ClosedRange<Double> = 4...128
    private static let autoHideDelayRangeMs: ClosedRange<Double> = 0...600_000

    init(isEnabled: Bool, snapDistance: CGFloat, peekWidth: CGFloat, autoHideDelay: TimeInterval) {
        self.isEnabled = isEnabled
        self.snapDistance = snapDistance
        self.peekWidth = peekWidth
        self.autoHideDelay = autoHideDelay
    }

    /// 从 settings.json 的根对象解析；缺失或非法的字段逐项回退到默认值
    init(settingsObject: [String: Any]?) {
        let fallback = Self.default
        let object = settingsObject?["edge_snap"] as? [String: Any] ?? [:]

        isEnabled = object["enabled"] as? Bool ?? fallback.isEnabled
        snapDistance = SettingsValue.number(object["snap_distance"], in: Self.snapDistanceRange).map { CGFloat($0) }
            ?? fallback.snapDistance
        peekWidth = SettingsValue.number(object["peek_width"], in: Self.peekWidthRange).map { CGFloat($0) }
            ?? fallback.peekWidth
        autoHideDelay = SettingsValue.number(object["auto_hide_delay"], in: Self.autoHideDelayRangeMs).map { $0 / 1000 }
            ?? fallback.autoHideDelay
    }
}
