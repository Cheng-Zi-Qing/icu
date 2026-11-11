import Foundation

/// 屏幕中央的提醒卡放哪、没人理多久收起、全屏休息提前结束算不算做了。纯计算，方便单测
enum ReminderStageRules {
    /// 提醒卡挂着没人点：这么久以后自己收起，记成跳过（人在但没空理它）
    static let unansweredTimeout: TimeInterval = 120
    /// 全屏休息提前结束：歇够这个比例就算做了，不够算跳过
    static let completedShare = 0.5
    /// 卡片中心在屏幕可用区域里偏上一点（视觉上的正中）
    static let verticalBias: CGFloat = 0.56

    /// 卡片在屏幕可用区域里的位置：左右居中，上下略偏上，不出屏幕
    static func frame(size: CGSize, in visible: CGRect) -> CGRect {
        let x = visible.midX - size.width / 2
        let y = visible.minY + visible.height * verticalBias - size.height / 2
        return CGRect(
            x: clamp(x, visible.minX, visible.maxX - size.width).rounded(),
            y: clamp(y, visible.minY, visible.maxY - size.height).rounded(),
            width: size.width,
            height: size.height
        )
    }

    /// 全屏休息结束时记什么：走完了算完成；提前结束看歇了多少
    static func restOutcome(rested: TimeInterval, total: TimeInterval) -> HealthReminderOutcome {
        guard total > 0 else { return .completed }
        return rested / total >= completedShare ? .completed : .skipped
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        max(lower, min(value, max(lower, upper)))
    }
}
