import Foundation

/// 现在桌宠身边的情形：决定低一级的打扰能不能出来
struct PetAttentionContext: Equatable {
    /// 你离开电脑了（一阵子没碰键盘鼠标）
    var userAway = false
    /// 前台 App 正全屏（看视频、演示）
    var fullscreen = false
    /// 有 Agent 在等你（L3）
    var agentWaiting = false
    /// 提醒卡片正挂着（L2）
    var reminderShowing = false
}

/// 打扰分级（02-响应设计）：L3 在等你 > L2 健康提醒 > L1 干完了 / 出错了 > L0 安静陪着。
/// 同一时间只表现最高的一级，低的排队；你不在、全屏时除了 L3 都先压着
enum PetAttention {
    enum AwayHandling: Equatable {
        /// 跳过这一次（计时器会接着算下一次）
        case skip
        /// 压着，等能出来了再出来
        case hold
    }

    /// 健康提醒到点时你不在：离开电脑本身就是休息，这一次跳过，不攒着等你回来补
    static let reminderWhileAway = AwayHandling.skip

    /// L2 健康提醒现在能不能弹（你不在时按 `reminderWhileAway` 处理，不走这里）
    static func reminderMayShow(_ context: PetAttentionContext) -> Bool {
        !context.userAway && !context.fullscreen && !context.agentWaiting && !context.reminderShowing
    }

    /// L1 干完了 / 出错了的一次性动作现在能不能演
    static func celebrationMayPlay(_ context: PetAttentionContext) -> Bool {
        !context.userAway && !context.fullscreen && !context.reminderShowing
    }
}

/// Agent 这边该演什么：在干活演小场景、在等你一直招手、干完了 / 出错了在合适的时候演一遍
struct AgentStage: Equatable {
    static let initial = AgentStage(kind: .idle, pending: nil, playing: nil)

    let kind: AgentSummary.Kind
    /// 排着队等演的一次性动作（干完了 / 出错了）
    let pending: PetScene?
    /// 正在演的一次性动作
    let playing: PetScene?

    /// Agent 状态变了。刚干完 / 出错就排一段动作；又开始干活或在等你时，排着的、在演的都不要了
    func receiving(_ next: AgentSummary.Kind) -> AgentStage {
        guard next != kind else { return self }
        switch next {
        case .done:
            return AgentStage(kind: next, pending: .done, playing: playing)
        case .failed:
            return AgentStage(kind: next, pending: .failed, playing: playing)
        case .working, .waiting:
            return AgentStage(kind: next, pending: nil, playing: nil)
        case .idle:
            return AgentStage(kind: next, pending: pending, playing: playing)
        }
    }

    /// 能演了就把排着的那段拿出来演（正在演别的就等它演完）
    func starting(allowed: Bool) -> AgentStage {
        guard allowed, playing == nil, let pending else { return self }
        return AgentStage(kind: kind, pending: nil, playing: pending)
    }

    func finished(_ scene: PetScene) -> AgentStage {
        guard playing == scene else { return self }
        return AgentStage(kind: kind, pending: pending, playing: nil)
    }

    /// 现在该演的场景：在等你 > 一次性动作 > 干活小场景；都没有就是 nil（平时的待机）
    func scene(work: AgentActivity?) -> PetScene? {
        if kind == .waiting { return .waiting }
        if let playing { return playing }
        guard kind == .working else { return nil }
        return work.map(PetScene.work)
    }
}
