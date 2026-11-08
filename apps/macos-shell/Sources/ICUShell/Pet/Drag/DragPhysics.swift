import CoreGraphics
import Foundation

/// 拖拽手感参数（屏幕坐标 pt，y 向上；时间秒）
struct DragPhysicsConfig {
    /// 按下后移动超过该距离才算拖拽，否则视为点击
    var dragThreshold: CGFloat = 3
    /// 拎着不动时的麻糬拉长量（相对原高度）
    var holdStretch: CGFloat = 0.10
    /// 向上甩时额外拉长的上限
    var maxExtraStretch: CGFloat = 0.06
    /// 每 1pt/s 向上速度带来的额外拉长
    var stretchPerUpwardVelocity: CGFloat = 0.0001
    /// 钟摆最大角度（度）
    var maxSwingDegrees: CGFloat = 18
    /// 每 1pt/s 横向速度对应的目标摆角（度）
    var swingPerVelocity: CGFloat = 0.03
    var swingStiffness: CGFloat = 140
    var swingDamping: CGFloat = 9
    var stretchStiffness: CGFloat = 200
    var stretchDamping: CGFloat = 16
    /// 没有新的移动事件时，指针速度的衰减速率（1/s）
    var velocityDecay: CGFloat = 10
    /// 横向速度超过它才算“甩”了一下
    var shakeSpeed: CGFloat = 350
    /// 在 dizzyWindow 秒内换向这么多次就甩晕
    var dizzyReversals = 4
    var dizzyWindow: TimeInterval = 1.0
    var dizzyDuration: TimeInterval = 1.5
    /// 松手后落地压扁的时长
    var landingDuration: TimeInterval = 0.45
    /// 松手后多久必须完全复位
    var settleDuration: TimeInterval = 0.8
    /// 落地最大压扁量
    var landingSquashAmount: CGFloat = 0.18
}

/// 拖拽期间需要显示的姿势帧
enum DragPose: Equatable {
    case none
    /// tilt: -2...2，负数表示身体下半往左摆
    case hold(tilt: Int)
    case dizzy(tilt: Int, twinkle: Int)
    case landing(frame: Int)
}

/// 每帧的渲染输出
struct DragOutput: Equatable {
    var pose: DragPose
    /// 以抓取点（顶部）为锚的纵向拉长，1 表示不变
    var stretchY: CGFloat
    /// 钟摆角度（度），负数表示下半身往左
    var swingDegrees: CGFloat
    /// 以脚底为锚的纵向压扁，1 表示不变
    var landingSquash: CGFloat

    static let rest = DragOutput(pose: .none, stretchY: 1, swingDegrees: 0, landingSquash: 1)
}

/// 拖拽物理：纯值类型，每个操作返回新状态，便于测试和回放
struct DragPhysics {
    enum Phase: Equatable {
        case resting
        case pressed(origin: CGPoint)
        case dragging
        case settling(releasedAt: TimeInterval)
    }

    let config: DragPhysicsConfig
    private(set) var phase: Phase = .resting
    /// 最近一次松手是否是拖拽（nil 表示还没松过手）
    private(set) var lastReleaseWasDrag: Bool?

    private var lastPoint: CGPoint = .zero
    private var lastEventTime: TimeInterval = 0
    private var lastStepTime: TimeInterval?
    private var velocity = CGVector(dx: 0, dy: 0)
    private var swingAngle: CGFloat = 0
    private var swingVelocity: CGFloat = 0
    private var stretch: CGFloat = 0
    private var stretchVelocity: CGFloat = 0
    private var shakeDirection = 0
    private var reversalTimes: [TimeInterval] = []
    private var dizzyUntil: TimeInterval?

    init(config: DragPhysicsConfig = DragPhysicsConfig()) {
        self.config = config
    }

    var isDragging: Bool { phase == .dragging }

    /// 还有效果在播放（需要继续逐帧推进）
    var isActive: Bool {
        switch phase {
        case .resting, .pressed: return false
        case .dragging, .settling: return true
        }
    }

    // MARK: - 输入事件

    func pressed(at point: CGPoint, at time: TimeInterval) -> DragPhysics {
        var next = DragPhysics(config: config)
        next.phase = .pressed(origin: point)
        next.lastPoint = point
        next.lastEventTime = time
        next.lastStepTime = time
        next.lastReleaseWasDrag = lastReleaseWasDrag
        return next
    }

    func moved(to point: CGPoint, at time: TimeInterval) -> DragPhysics {
        var next = self
        switch phase {
        case .resting, .settling:
            return self
        case let .pressed(origin):
            guard hypot(point.x - origin.x, point.y - origin.y) >= config.dragThreshold else {
                return self
            }
            next.phase = .dragging
        case .dragging:
            break
        }

        let dt = max(time - lastEventTime, 1.0 / 240)
        let instant = CGVector(dx: (point.x - lastPoint.x) / dt, dy: (point.y - lastPoint.y) / dt)
        // 轻度平滑，避免单个抖动事件造成突变
        next.velocity = CGVector(dx: velocity.dx * 0.3 + instant.dx * 0.7, dy: velocity.dy * 0.3 + instant.dy * 0.7)
        next.lastPoint = point
        next.lastEventTime = time
        return next.registeringShake(at: time)
    }

    func released(at time: TimeInterval) -> DragPhysics {
        var next = self
        switch phase {
        case .pressed:
            next.phase = .resting
            next.lastReleaseWasDrag = false
        case .dragging:
            next.phase = .settling(releasedAt: time)
            next.lastReleaseWasDrag = true
            next.velocity = CGVector(dx: 0, dy: 0)
        case .resting, .settling:
            break
        }
        return next
    }

    // MARK: - 逐帧推进

    func stepped(to time: TimeInterval) -> DragPhysics {
        guard isActive else {
            var next = self
            next.lastStepTime = time
            return next
        }

        if case let .settling(releasedAt) = phase, time >= settleDeadline(releasedAt: releasedAt) {
            return restingCopy(at: time)
        }

        var next = self
        let start = lastStepTime ?? time
        let elapsed = max(time - start, 0)
        var remaining = min(elapsed, Self.maxSimulatedGap)
        // 半隐式欧拉，固定小步长保证弹簧稳定
        let maxSubstep: TimeInterval = 1.0 / 240
        while remaining > 0 {
            let dt = CGFloat(min(remaining, maxSubstep))
            next = next.integrated(dt: dt)
            remaining -= Double(dt)
        }
        if elapsed > Self.maxSimulatedGap {
            // 长时间没刷新（卡顿 / 休眠）：剩余时间里弹簧早已停稳，直接落到目标值
            next = next.snappedToTargets()
        }
        next.lastStepTime = time
        return next
    }

    func output(at time: TimeInterval) -> DragOutput {
        switch phase {
        case .resting, .pressed:
            return .rest
        case .dragging:
            let pose: DragPose = isDizzy(at: time)
                ? .dizzy(tilt: tilt, twinkle: twinkle(at: time))
                : .hold(tilt: tilt)
            return DragOutput(pose: pose, stretchY: 1 + stretch, swingDegrees: swingAngle, landingSquash: 1)
        case let .settling(releasedAt):
            let elapsed = time - releasedAt
            let pose: DragPose
            if elapsed < config.landingDuration {
                pose = .landing(frame: elapsed < config.landingDuration / 2 ? 0 : 1)
            } else if isDizzy(at: time) {
                pose = .dizzy(tilt: 0, twinkle: twinkle(at: time))
            } else {
                pose = .none
            }
            return DragOutput(
                pose: pose,
                stretchY: 1 + stretch,
                swingDegrees: swingAngle,
                landingSquash: landingSquash(elapsed: elapsed)
            )
        }
    }

    // MARK: - Private

    private var tilt: Int {
        let normalized = swingAngle / max(config.maxSwingDegrees, 1) * 2
        return max(-2, min(2, Int(normalized.rounded())))
    }

    private func twinkle(at time: TimeInterval) -> Int {
        Int(time * 6) % 2
    }

    private func isDizzy(at time: TimeInterval) -> Bool {
        guard let dizzyUntil else { return false }
        return time < dizzyUntil
    }

    private func settleDeadline(releasedAt: TimeInterval) -> TimeInterval {
        max(releasedAt + config.settleDuration, dizzyUntil ?? 0)
    }

    private func landingSquash(elapsed: TimeInterval) -> CGFloat {
        guard elapsed >= 0, elapsed < config.landingDuration else { return 1 }
        // 衰减余弦：先压扁、轻微回弹，到 landingDuration 时归零
        let progress = CGFloat(elapsed / config.landingDuration)
        let envelope = (1 - progress) * exp(-3 * progress)
        return 1 - config.landingSquashAmount * envelope * cos(progress * .pi * 2.5)
    }

    private func registeringShake(at time: TimeInterval) -> DragPhysics {
        guard abs(velocity.dx) >= config.shakeSpeed else { return self }
        var next = self
        let direction = velocity.dx > 0 ? 1 : -1
        if shakeDirection != 0, direction != shakeDirection {
            next.reversalTimes = (reversalTimes + [time]).filter { time - $0 <= config.dizzyWindow }
            if next.reversalTimes.count >= config.dizzyReversals {
                next.dizzyUntil = time + config.dizzyDuration
                next.reversalTimes = []
            }
        }
        next.shakeDirection = direction
        return next
    }

    private func integrated(dt: CGFloat) -> DragPhysics {
        var next = self
        let dragging = phase == .dragging

        next.velocity = CGVector(
            dx: velocity.dx * exp(-config.velocityDecay * dt),
            dy: velocity.dy * exp(-config.velocityDecay * dt)
        )

        let swingTarget = dragging
            ? max(-config.maxSwingDegrees, min(config.maxSwingDegrees, -next.velocity.dx * config.swingPerVelocity))
            : 0
        let swingAcceleration = config.swingStiffness * (swingTarget - swingAngle) - config.swingDamping * swingVelocity
        next.swingVelocity = swingVelocity + swingAcceleration * dt
        next.swingAngle = max(-config.maxSwingDegrees, min(config.maxSwingDegrees, swingAngle + next.swingVelocity * dt))

        let upwardExtra = max(0, min(config.maxExtraStretch, next.velocity.dy * config.stretchPerUpwardVelocity))
        let stretchTarget = dragging ? config.holdStretch + upwardExtra : 0
        let stretchAcceleration = config.stretchStiffness * (stretchTarget - stretch) - config.stretchDamping * stretchVelocity
        next.stretchVelocity = stretchVelocity + stretchAcceleration * dt
        let maxStretch = config.holdStretch + config.maxExtraStretch
        next.stretch = max(-maxStretch, min(maxStretch, stretch + next.stretchVelocity * dt))
        return next
    }

    private static let maxSimulatedGap: TimeInterval = 0.5

    private func snappedToTargets() -> DragPhysics {
        var next = self
        next.velocity = CGVector(dx: 0, dy: 0)
        next.swingAngle = 0
        next.swingVelocity = 0
        next.stretch = phase == .dragging ? config.holdStretch : 0
        next.stretchVelocity = 0
        return next
    }

    /// 复位：所有效果精确回到初始值（避免“拉长后回不去”）
    private func restingCopy(at time: TimeInterval) -> DragPhysics {
        var next = DragPhysics(config: config)
        next.lastReleaseWasDrag = lastReleaseWasDrag
        next.lastStepTime = time
        return next
    }
}

extension DragPose {
    var isLanding: Bool {
        if case .landing = self { return true }
        return false
    }
}
