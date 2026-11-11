import Foundation

/// 桌宠可以演的一段场景：Agent 在干活时的小场景、Agent 状态的三段动作，或者健康提醒的配套动作。
/// `name` 就是 `work/scenes.json` 里的场景名
enum PetScene: Equatable {
    case work(AgentActivity)
    /// 在等你：举爪招手，背上「!」一闪一闪（循环）
    case waiting
    /// 干完了：开心跳一下（只放一遍）
    case done
    /// 出错了：歪头冒问号（只放一遍）
    case failed
    /// 健康提醒挂着时跟着做：该喝水了捧杯子喝，该护眼了抬头望远处（循环到提醒关掉）
    case remind(HealthReminderType)

    var name: String {
        switch self {
        case let .work(activity): return activity.rawValue
        case .waiting: return "wait"
        case .done: return "done"
        case .failed: return "fail"
        case .remind(.hydration): return "drink"
        case .remind(.eyeCare): return "look_away"
        }
    }

    var activity: AgentActivity? {
        guard case let .work(activity) = self else { return nil }
        return activity
    }

    /// 只放一遍的动作；这只宠物没有素材时马上算演完（不然一直挡着打盹）
    var isOneShot: Bool {
        self == .done || self == .failed
    }

    /// 侧身坐着演（和待机一样），可以转头看鼠标；干活小场景是正脸的，派子 Agent 放小鸟除外（侧身）
    var facesSideways: Bool {
        activity == nil || activity == .delegate
    }
}

/// 场景放到某一拍时整只往上抛一下（整像素，见 InteractionLayer）
struct PetSceneHop: Equatable {
    /// 开演后多少秒起跳
    let startsAfter: TimeInterval
    /// 抛多高（素材像素）
    let pixels: Int
    /// 起跳到落地多少秒
    let duration: TimeInterval
}
