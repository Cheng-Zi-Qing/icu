import AppKit
import CoreGraphics

/// 摸头、打盹、待机小动作：把鼠标动作、用户离开时长、随机节奏变成要叠在待机动画上的逐帧画面。
///
/// 画面优先级由视图决定：拖拽 > 贴边探头 > 这里的片段 > 待机动画。
/// `onImageChanged(nil)` 表示没有片段在放，视图回到待机动画。
final class PetBehaviorCoordinator {
    /// 用户最后一次键盘 / 鼠标输入距今的秒数（不需要辅助功能权限）
    static func systemUserIdleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// 没片段在放时多久查一次用户是否离开
    private static let idleCheckInterval: TimeInterval = 1

    var onImageChanged: ((NSImage?) -> Void)?
    /// 现在能不能打盹 / 做待机小动作：贴边探头、被拎着、正显示提醒 / 气泡时不行
    var isAvailable: () -> Bool = { true }

    private(set) var activeClip: PetActionClip?
    /// 你离开电脑了（和开始犯困用同一个时长）
    private(set) var isUserAway = false
    var onUserLeft: (() -> Void)?
    /// 你回来了；桌宠睡着的话，等醒来那段放完才报
    var onUserReturned: (() -> Void)?

    private let sprites: (PetActionClip) -> PetPoseSprites?
    private let userIdle: () -> TimeInterval
    private let now: () -> TimeInterval
    private let random: () -> Double
    private let startsTimer: Bool

    private var stroke = PetStrokeDetector()
    private var napPhase = PetNapPhase.awake
    private var clipStartedAt: TimeInterval = 0
    private var nextIdleActionAt: TimeInterval = 0
    /// 离开后动过键盘鼠标了，等醒来动画放完就算回来
    private var userCameBack = false
    private var shownFrame: String?
    private var timer: Timer?

    init(
        sprites: @escaping (PetActionClip) -> PetPoseSprites?,
        userIdle: @escaping () -> TimeInterval = PetBehaviorCoordinator.systemUserIdleSeconds,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        random: @escaping () -> Double = { Double.random(in: 0..<1) },
        startsTimer: Bool = true
    ) {
        self.sprites = sprites
        self.userIdle = userIdle
        self.now = now
        self.random = random
        self.startsTimer = startsTimer
        scheduleNextIdleAction()
        reschedule()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 输入

    /// 鼠标在桌宠上移动；`overHead` 为 false 时（摸肚子、在旁边晃）不算摸头
    func pointerMoved(x: CGFloat, overHead: Bool) {
        guard overHead else {
            stroke = PetStrokeDetector()
            return
        }
        let (next, stroked) = stroke.feeding(x: x, at: now())
        stroke = next
        // 睡着时先醒（用户一动鼠标打盹节奏就会叫醒它），醒着才冒爱心
        guard stroked, napPhase == .awake else { return }
        play(.petted)
    }

    func pointerExited() {
        stroke = PetStrokeDetector()
    }

    /// 推进一拍：更新打盹阶段、片段播到哪一帧、该不该做个小动作
    func tick() {
        let time = now()
        let available = isAvailable()
        let idle = userIdle()
        let phase = PetNapSchedule.next(napPhase, userIdle: idle, canNap: available, now: time)
        if phase != napPhase {
            napPhase = phase
            applyNapPhase(phase)
        }
        showCurrentFrame()
        updatePresence(userIdle: idle)
        playIdleActionIfDue(available: available, at: time)
    }

    /// 离开 / 回来各报一次；回来时正在放醒来那段就等它放完
    private func updatePresence(userIdle idle: TimeInterval) {
        guard isUserAway else {
            guard idle >= PetNapSchedule.napAfterIdle else { return }
            isUserAway = true
            userCameBack = false
            onUserLeft?()
            return
        }
        if idle < PetNapSchedule.userReturnedIdle {
            userCameBack = true
        }
        guard userCameBack else { return }
        if case .waking = napPhase { return }
        isUserAway = false
        userCameBack = false
        onUserReturned?()
    }

    /// 醒着、闲着、到点了就随机做个小动作；到点时正忙就往后推
    private func playIdleActionIfDue(available: Bool, at time: TimeInterval) {
        guard time >= nextIdleActionAt, activeClip == nil else { return }
        guard available, napPhase == .awake else {
            scheduleNextIdleAction()
            return
        }
        play(PetIdleActionSchedule.pick(random: random()))
    }

    /// 下一个小动作从现在（上一个片段结束时）起算
    private func scheduleNextIdleAction() {
        nextIdleActionAt = now() + PetIdleActionSchedule.nextDelay(random: random())
    }

    // MARK: - 播放

    private func applyNapPhase(_ phase: PetNapPhase) {
        switch phase {
        case .dozing: play(.doze)
        case .napping: play(.nap)
        case .waking: play(.wake)
        case .awake:
            if activeClip != .petted { stop() }
        }
    }

    private func play(_ clip: PetActionClip) {
        activeClip = clip
        clipStartedAt = now()
        shownFrame = nil
        showCurrentFrame()
        reschedule()
    }

    private func stop() {
        guard activeClip != nil else { return }
        activeClip = nil
        shownFrame = nil
        scheduleNextIdleAction()
        onImageChanged?(nil)
        reschedule()
    }

    private func showCurrentFrame() {
        guard let clip = activeClip else { return }
        guard let name = clip.frameName(after: now() - clipStartedAt) else {
            stop()
            return
        }
        guard name != shownFrame else { return }
        guard let image = sprites(clip)?.image(named: name) else {
            // 这只宠物没有这段素材：当作没放
            stop()
            return
        }
        shownFrame = name
        onImageChanged?(image)
    }

    /// 放片段时按帧率走，空闲时每秒看一眼用户在不在
    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard startsTimer else { return }
        let interval = activeClip.map { 1 / $0.framesPerSecond } ?? Self.idleCheckInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
