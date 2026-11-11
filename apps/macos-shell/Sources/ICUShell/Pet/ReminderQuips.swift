import Foundation

/// 提醒卡上的俏皮话：每次弹卡随机抽一句标题和按钮文字，同一个提醒不会天天一个腔调。
/// 文案池在 `config/copy/` 里写成数组（`quips.hydration.lines`、`quips.hydration.done`…）。
/// 长度有上限：屏幕中央的提醒卡标题用两倍大的像素字，中文最多 6 个字；按钮最多 4 个字
enum ReminderQuips {
    struct Pool: Equatable {
        /// 卡片标题
        let lines: [String]
        /// 「做到了」按钮
        let done: [String]
        /// 「开始休息」按钮（护眼才有：点了以后全屏挡住屏幕倒计时）
        let start: [String]
    }

    static let maxLineLength = 6
    static let maxButtonLength = 4

    private static func pool(_ name: String) -> Pool {
        Pool(
            lines: TextCatalog.shared.texts("quips.\(name).lines"),
            done: TextCatalog.shared.texts("quips.\(name).done"),
            start: TextCatalog.shared.texts("quips.\(name).start")
        )
    }

    static var hydration: Pool { pool("hydration") }

    /// 20-20-20：看远处 20 秒
    static var lookAway: Pool { pool("look_away") }

    /// 每小时歇 5 分钟：起身离开屏幕
    static var standUp: Pool { pool("stand_up") }

    /// 「稍后」按钮
    static var later: [String] { TextCatalog.shared.texts("quips.later") }

    /// 「跳过」按钮
    static var nope: [String] { TextCatalog.shared.texts("quips.nope") }
}
