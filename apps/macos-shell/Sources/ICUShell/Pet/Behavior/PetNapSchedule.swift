import Foundation

/// 打盹的阶段（参考 oneko 的犯困 → 睡觉 → 被吵醒）
enum PetNapPhase: Equatable {
    case awake
    /// 闭眼低头，还没睡熟（这时动一下鼠标只是睁开眼）
    case dozing(until: TimeInterval)
    case napping
    /// 被吵醒：头上冒个「!」
    case waking(until: TimeInterval)
}

/// 打盹节奏：用户离开电脑一阵子，桌宠也跟着打个盹；用户回来就醒。纯函数。
enum PetNapSchedule {
    /// 用户多久没碰键盘鼠标后开始犯困
    static let napAfterIdle: TimeInterval = 180
    static let dozeDuration: TimeInterval = 1.5
    static let wakeDuration: TimeInterval = 1.2
    /// 最近一次输入在这么短之前，就当用户回来了
    static let userReturnedIdle: TimeInterval = 2

    /// - Parameters:
    ///   - userIdle: 距离用户最后一次键盘 / 鼠标输入的秒数
    ///   - canNap: 桌宠现在能不能睡（贴边探头、被拎着、正显示提醒时都不行）
    static func next(_ phase: PetNapPhase, userIdle: TimeInterval, canNap: Bool, now: TimeInterval) -> PetNapPhase {
        let userReturned = userIdle < userReturnedIdle
        switch phase {
        case .awake:
            return canNap && userIdle >= napAfterIdle ? .dozing(until: now + dozeDuration) : .awake
        case let .dozing(until):
            if !canNap || userReturned { return .awake }
            return now >= until ? .napping : phase
        case .napping:
            if !canNap { return .awake }
            return userReturned ? .waking(until: now + wakeDuration) : .napping
        case let .waking(until):
            if !canNap { return .awake }
            return now >= until ? .awake : phase
        }
    }
}
