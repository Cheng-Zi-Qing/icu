import Foundation

/// 把打扰分级落到实处：Agent 状态、健康提醒、你在不在、是不是全屏汇到这里，
/// 决定现在演什么、提醒弹不弹、回来时说什么（规则见 PetAttention）
@MainActor
final class PetAttentionCoordinator {
    /// 回来时那句话挂多久；这段时间里压着的提醒先别弹，不然卡片会把话盖掉
    static let digestDuration: TimeInterval = 4

    /// 该演的场景可能变了（控制器重新挑一次）
    var onStageChanged: (() -> Void)?
    /// 弹这张提醒卡
    var onReminderReady: ((ReminderPresentationPayload) -> Void)?
    /// 有 Agent 在等你，正挂着的提醒卡先收起来（之后再弹）
    var onReminderWithdrawn: (() -> Void)?
    /// 回来时冒的那句话
    var onDigest: ((String) -> Void)?

    private(set) var stage = AgentStage.initial
    private(set) var context = PetAttentionContext()
    private(set) var digest = AwayDigest.empty
    /// 压着没弹的提醒，先来的先弹；同一种只留最新的
    private(set) var heldReminders: [ReminderPresentationPayload] = []
    private var showingReminder: ReminderPresentationPayload?
    /// 正挂着的提醒卡是哪一张
    var showingReminderID: UUID? { showingReminder?.id }
    private var agentWorkingSince: TimeInterval?
    private var remindersPausedUntil: TimeInterval = 0
    private let now: () -> TimeInterval
    private let schedulesRecheck: Bool

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, schedulesRecheck: Bool = true) {
        self.now = now
        self.schedulesRecheck = schedulesRecheck
    }

    // MARK: - 输入

    func agentChanged(_ summary: AgentSummary) {
        stage = stage.receiving(summary.kind)
        context.agentWaiting = summary.kind == .waiting
        agentWorkingSince = summary.kind == .working ? (agentWorkingSince ?? now()) : nil
        if context.userAway {
            digest = digest.recording(summary)
        }
        if context.agentWaiting, let showing = showingReminder {
            // L3 盖过 L2：卡片收起来，排回队头
            showingReminder = nil
            context.reminderShowing = false
            heldReminders = [showing] + heldReminders.filter { $0.type != showing.type }
            onReminderWithdrawn?()
        }
        advance()
    }

    /// 健康提醒到点了
    func reminderDue(_ payload: ReminderPresentationPayload) {
        // 你不在：离开电脑本身就是休息，这一次跳过（计时器会接着算下一次）
        guard !context.userAway else { return }
        let text = AgentReminderCopy.text(for: payload.type, agentWorkingFor: agentWorkingSince.map { now() - $0 })
        let adjusted = text.map {
            ReminderPresentationPayload(id: payload.id, type: payload.type, text: $0, restSeconds: payload.restSeconds)
        } ?? payload
        heldReminders = heldReminders.filter { $0.type != adjusted.type } + [adjusted]
        advance()
    }

    /// 提醒卡关掉了（点了按钮 / 倒计时走完）。不是正挂着的那张就不算（被收起的旧卡迟到的回调）
    func reminderClosed(_ id: UUID?) {
        guard let id, id == showingReminder?.id else { return }
        showingReminder = nil
        context.reminderShowing = false
        advance()
    }

    func userLeft() {
        context.userAway = true
        digest = .empty
        advance()
    }

    /// 你回来了（醒来动画已经放完）：排着的一次性动作接着演，离开时的事合成一句话
    func userReturned() {
        guard context.userAway else { return }
        context.userAway = false
        let message = digest.message
        digest = .empty
        if let message {
            remindersPausedUntil = now() + Self.digestDuration
            onDigest?(message)
            scheduleRecheck(after: Self.digestDuration)
        }
        advance()
    }

    func fullscreenChanged(_ fullscreen: Bool) {
        guard fullscreen != context.fullscreen else { return }
        context.fullscreen = fullscreen
        advance()
    }

    /// 只放一遍的动作演完了
    func sceneFinished(_ scene: PetScene) {
        stage = stage.finished(scene)
        advance()
    }

    // MARK: - 推进

    /// 先放高一级的（L2 提醒），再看低一级的（L1 一次性动作）还能不能演
    private func advance() {
        releaseHeldReminder()
        stage = stage.starting(allowed: PetAttention.celebrationMayPlay(context))
        onStageChanged?()
    }

    private func releaseHeldReminder() {
        guard
            !heldReminders.isEmpty,
            PetAttention.reminderMayShow(context),
            now() >= remindersPausedUntil
        else { return }
        let next = heldReminders.removeFirst()
        showingReminder = next
        context.reminderShowing = true
        onReminderReady?(next)
    }

    private func scheduleRecheck(after delay: TimeInterval) {
        guard schedulesRecheck else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated { self?.advance() }
        }
    }
}
