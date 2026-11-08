import Foundation

/// 待机小动作的节奏（参考 Shimeji 按权重随机挑动作）：隔一阵子随机做一件小事。纯函数。
enum PetIdleActionSchedule {
    /// 两次小动作之间隔多久（秒）
    static let delayRange: ClosedRange<TimeInterval> = 25...60

    /// 动作和权重：柚子摇摇常见，小鸟来访少见一点
    static let weightedActions: [(clip: PetActionClip, weight: Double)] = [
        (.yuzuWobble, 2),
        (.birdVisit, 1),
    ]

    /// - Parameter random: [0, 1) 之间的随机数
    static func nextDelay(random: Double) -> TimeInterval {
        delayRange.lowerBound + (delayRange.upperBound - delayRange.lowerBound) * min(max(random, 0), 1)
    }

    /// - Parameter random: [0, 1) 之间的随机数
    static func pick(random: Double) -> PetActionClip {
        let total = weightedActions.reduce(0) { $0 + $1.weight }
        var threshold = min(max(random, 0), 0.999_999) * total
        for action in weightedActions {
            if threshold < action.weight { return action.clip }
            threshold -= action.weight
        }
        return weightedActions[weightedActions.count - 1].clip
    }
}
