import Foundation

/// 提醒卡上的俏皮话：每次弹卡随机抽一句标题和按钮文字，同一个提醒不会天天一个腔调。
/// 长度有上限：卡片只有 124pt 宽，12px 像素字标题最多 6 个字，按钮最多 3 个字
enum ReminderQuips {
    struct Pool: Equatable {
        /// 卡片标题
        let lines: [String]
        /// 「做到了」按钮
        let done: [String]
    }

    static let maxLineLength = 6
    static let maxButtonLength = 3

    static let hydration = Pool(
        lines: [
            "咕嘟时间到！",
            "嘴巴干了吧？",
            "来，干一杯！",
            "你的杯子在哭",
            "吨吨吨走起！",
            "水豚盯着你喝",
            "喝口水再忙嘛",
            "给自己浇浇水",
        ],
        done: ["我喝了", "吨吨吨", "喝完啦", "干了！"]
    )

    /// 20-20-20：看远处 20 秒
    static let lookAway = Pool(
        lines: [
            "眼睛喊累啦",
            "看看远处嘛",
            "窗外有朵云",
            "别盯屏幕啦",
            "眼珠子放个假",
            "远处有风景",
            "望远一下下",
        ],
        done: ["看过了", "好嘞", "看完啦"]
    )

    /// 每小时歇 5 分钟：起身离开屏幕
    static let standUp = Pool(
        lines: [
            "屁股坐麻了吧",
            "起来晃一晃",
            "去走两步嘛",
            "伸个大懒腰",
            "水豚陪你歇会",
            "站起来扭一扭",
        ],
        done: ["动过了", "好嘞", "歇好啦"]
    )

    /// 「稍后」按钮
    static let later = ["等会儿", "再忙下", "一会儿"]

    /// 「跳过」按钮
    static let nope = ["我就不", "不要", "偏不"]
}
