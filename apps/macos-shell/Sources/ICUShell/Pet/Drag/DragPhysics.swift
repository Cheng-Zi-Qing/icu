import CoreGraphics
import Foundation

/// 拖拽手感参数（屏幕坐标 pt，y 向上；时间秒）
struct DragPhysicsConfig {
    /// 按下后移动超过该距离才算拖拽，否则视为点击
    var dragThreshold: CGFloat = 3
    /// 拎着不动时的麻糬拉长量（相对原高度）
    var holdStretch: CGFloat = 0.14
    /// 甩得快时额外拉长的上限
    var maxExtraStretch: CGFloat = 0.16
    /// 每 1pt/s 指针速度（任意方向）带来的额外拉长
    var stretchPerSpeed: CGFloat = 0.00025
    /// 钟摆最大角度（度）：夸张一点，甩起来整个身子荡出去
    var maxSwingDegrees: CGFloat = 40
    /// 每 1pt/s 横向速度对应的目标摆角（度）
    var swingPerVelocity: CGFloat = 0.07
    /// 摆的弹簧够硬（固有频率约 4Hz），鼠标晃多快身子就晃多快；
    /// 阻尼比约 0.4，鼠标一停还会来回荡两下
    var swingStiffness: CGFloat = 700
    var swingDamping: CGFloat = 22
    /// 波浪感：下半身是另一根更软的弹簧，追着上半身的摆角跑，慢半拍、还会甩过头。
    /// 两者之差就是身体弯的程度，挑对应歪向的像素帧
    var tailStiffness: CGFloat = 260
    var tailDamping: CGFloat = 8
    var maxBendDegrees: CGFloat = 16
    /// Q 弹感：拉长弹簧阻尼很小（阻尼比约 0.15），一拎起来先拉过头再缩回去，boing 两下
    var stretchStiffness: CGFloat = 260
    var stretchDamping: CGFloat = 5
    /// 甩得越猛身子越被甩长：每 1°/s 摆动速度带来的额外拉长
    var stretchPerSwingSpeed: CGFloat = 0.0008
    /// 没有新的移动事件时，指针速度的衰减速率（1/s）：鼠标一停就算停，身子才会往前荡过头
    var velocityDecay: CGFloat = 25
    /// 横向速度超过它才算“甩”了一下
    var shakeSpeed: CGFloat = 350
    /// 在 dizzyWindow 秒内换向这么多次就甩晕
    var dizzyReversals = 4
    var dizzyWindow: TimeInterval = 1.0
    var dizzyDuration: TimeInterval = 1.5
    /// 松手到完全站稳的总时长：前 fallDuration 是下落，剩下 0.4s 是落地压扁回弹
    var landingDuration: TimeInterval = 0.82
    /// 拎着时身体离地抬高多少（pt）：松手后从这里落回地面，才有「下落」的视觉效果
    var liftHeight: CGFloat = 56
    /// 松手后下落多久；这段时间身体还是拎着的样子，落地那一刻才换成地上姿势。
    /// 和高度一起按同样的重力算（高度 ∝ 时间²）：56pt 约 0.42s，不会变成慢动作
    var fallDuration: TimeInterval = 0.42
    /// 甩晕后落地，还要在地上晕多久（从落地帧播完起算）
    var groundedDizzyDuration: TimeInterval = 0.8
    /// 松手后多久必须完全复位（落地压扁回弹做完再留 0.1s）
    var settleDuration: TimeInterval = 0.92
    /// 落地最大压扁量
    var landingSquashAmount: CGFloat = 0.18
}

/// 拖拽期间需要显示的姿势帧
enum DragPose: Equatable {
    case none
    /// tilt: -2...2，负数表示身体下半往左摆
    case hold(tilt: Int)
    case dizzy(tilt: Int, twinkle: Int)
    /// 甩晕后已经落地的样子：单独一套坐姿帧（`drag/dizzy_grounded_<twinkle>.png`）。
    /// 拎着的那套 `.dizzy` 用的是 hold 姿势，身体是悬空下垂的，放到地上会像挂着。
    /// 松手后若接着用 `.dizzy`，DesktopPetView 还会按 `isLifted` 把它重新拎进拎起窗口，
    /// 甩晕的豚鼠就会「落地又飞回去」，所以落地这段必须单独一个 case
    case dizzyGrounded(twinkle: Int)
    case landing(frame: Int)
}

/// 每帧的渲染输出
struct DragOutput: Equatable {
    var pose: DragPose
    /// 以抓取点（顶部）为锚的纵向拉长，1 表示不变
    var stretchY: CGFloat
    /// 钟摆角度（度），负数表示下半身往左
    var swingDegrees: CGFloat
    /// 下半身相对上半身多弯了多少（度），负数表示更往左；拿来挑歪向帧，做出波浪
    var bendDegrees: CGFloat = 0
    /// 以脚底为锚的纵向压扁，1 表示不变
    var landingSquash: CGFloat
    /// 身体离地抬高多少（pt），0 表示贴地；正值表示悬在空中
    var fallOffset: CGFloat = 0

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
    private var tailAngle: CGFloat = 0
    private var tailVelocity: CGFloat = 0
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
            // 晕劲儿是从甩的过程中开始计的，松手时往往已经剩不了多少，扣掉落地帧只剩零点几秒，
            // 用户根本看不到星星；松手时补到落地帧播完之后，让它在地上明显地再晕一会。
            // 必须先判断松手这一刻还晕着：dizzyUntil 只要设过就一直是 non-nil（只有复位才整个清掉），
            // 不判断的话星星早熄了再松手，也会凭空多出一段待地晕
            if isDizzy(at: time), let dizzyUntil, dizzyUntil < time + config.landingDuration + config.groundedDizzyDuration {
                next.dizzyUntil = time + config.landingDuration + config.groundedDizzyDuration
            }
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
            return DragOutput(pose: pose, stretchY: 1 + stretch, swingDegrees: swingAngle, bendDegrees: bend, landingSquash: 1, fallOffset: config.liftHeight)
        case let .settling(releasedAt):
            let elapsed = time - releasedAt
            let pose: DragPose
            // 前 fallDuration 是下落：姿势还是拎着那套，位置从抬高处往地面掉，
            // 落地那一刻才换成地上姿势——中间不换窗口，下落才是连续的
            if elapsed < config.fallDuration {
                pose = isDizzy(at: time)
                    ? .dizzy(tilt: tilt, twinkle: twinkle(at: time))
                    : .hold(tilt: tilt)
            } else if isDizzy(at: time) {
                // 晕着落地不能播正常落地帧：那是坐姿 + 灰尘的「趴下」，看着像没晕，
                // 落地瞬间就该趴在地上冒星星（压扁照走 landingSquash，照样是先墩一下再晕）
                pose = .dizzyGrounded(twinkle: twinkle(at: time))
            } else if elapsed < config.landingDuration {
                pose = .landing(frame: elapsed < config.landingDuration / 2 ? 0 : 1)
            } else {
                pose = .none
            }
            // 自由落体：剩余高度 ∝ (1 - t²)，起步慢、落地快
            let progress = elapsed / config.fallDuration
            let fallOffset = elapsed < config.fallDuration ? config.liftHeight * (1 - progress * progress) : 0
            return DragOutput(
                pose: pose,
                stretchY: 1 + stretch,
                swingDegrees: swingAngle,
                bendDegrees: bend,
                landingSquash: landingSquash(elapsed: elapsed),
                fallOffset: fallOffset
            )
        }
    }

    // MARK: - Private

    private var bend: CGFloat {
        max(-config.maxBendDegrees, min(config.maxBendDegrees, tailAngle - swingAngle))
    }

    private var tilt: Int {
        let normalized = bend / max(config.maxBendDegrees, 1) * 2
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
        // 悬空时不能压扁：压扁是落地那一下的事，从 fallDuration 之后才开始
        guard elapsed >= config.fallDuration, elapsed < config.landingDuration else { return 1 }
        // 衰减余弦：先压扁、轻微回弹，到 landingDuration 时归零
        let progress = CGFloat((elapsed - config.fallDuration) / (config.landingDuration - config.fallDuration))
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
        let swingVelocity = swingVelocity + swingAcceleration * dt
        let swingAngle = swingAngle + swingVelocity * dt
        next.swingAngle = max(-config.maxSwingDegrees, min(config.maxSwingDegrees, swingAngle))
        // 顶到最大角度就停在那里，不攒着速度（否则松开限位时会猛地弹回来）
        next.swingVelocity = next.swingAngle == swingAngle ? swingVelocity : 0

        let tailAcceleration = config.tailStiffness * (next.swingAngle - tailAngle) - config.tailDamping * tailVelocity
        next.tailVelocity = tailVelocity + tailAcceleration * dt
        next.tailAngle = tailAngle + next.tailVelocity * dt

        let speed = hypot(next.velocity.dx, next.velocity.dy)
        let fling = speed * config.stretchPerSpeed + abs(next.swingVelocity) * config.stretchPerSwingSpeed
        let stretchTarget = dragging ? config.holdStretch + min(config.maxExtraStretch, fling) : 0
        // 放下后不再弹：临界阻尼，落地前干脆地缩回原样
        let damping = dragging ? config.stretchDamping : 2 * config.stretchStiffness.squareRoot()
        let stretchAcceleration = config.stretchStiffness * (stretchTarget - stretch) - damping * stretchVelocity
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
        next.tailAngle = 0
        next.tailVelocity = 0
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
    /// 悬在半空（拎着、甩晕）：这时整只画在更大的拎起窗口里，跟着摆角转
    var isLifted: Bool {
        switch self {
        case .hold, .dizzy: return true
        case .none, .landing, .dizzyGrounded: return false
        }
    }

    /// 镜像显示（朝右）时，画出来的歪向也反过来，所以要取反方向的那张帧
    var mirrored: DragPose {
        switch self {
        case let .hold(tilt): return .hold(tilt: -tilt)
        case let .dizzy(tilt, twinkle): return .dizzy(tilt: -tilt, twinkle: twinkle)
        case let .dizzyGrounded(twinkle): return .dizzyGrounded(twinkle: twinkle)
        case .none, .landing: return self
        }
    }
}
