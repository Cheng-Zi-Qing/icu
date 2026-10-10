import QuartzCore
import Foundation

/// 表情覆盖层 — 眨眼、随机微动作等短时表情
final class ExpressionLayer {

    enum Expression {
        case blink
        case surprised
        case nod
        case shake
        case yawn
    }

    private var activeAction: ActiveAction?
    private var idleTimer: CFTimeInterval = 0
    private let yawnThreshold: CFTimeInterval = 60.0
    private var lastInteractionTime: CFTimeInterval = 0
    private var nextBlinkTime: CFTimeInterval = 0
    private var isIdle = true

    struct ActiveAction {
        var startTime: CFTimeInterval
        var duration: CFTimeInterval
        var keyframes: [(t: CGFloat, transform: LayerTransform)]
    }

    func setIdle(_ idle: Bool, at time: CFTimeInterval) {
        isIdle = idle
        if idle {
            scheduleNextBlink(at: time)
        }
    }

    func notifyInteraction(at time: CFTimeInterval) {
        lastInteractionTime = time
        idleTimer = 0
    }

    func play(_ expression: Expression, at time: CFTimeInterval) {
        switch expression {
        case .blink:
            activeAction = ActiveAction(
                startTime: time, duration: 0.15,
                keyframes: [
                    (0.0, .identity),
                    (0.4, LayerTransform(scaleX: 1.0, scaleY: 0.05)),
                    (1.0, .identity)
                ]
            )
        case .surprised:
            activeAction = ActiveAction(
                startTime: time, duration: 0.4,
                keyframes: [
                    (0.0, .identity),
                    (0.2, LayerTransform(scaleX: 1.12, scaleY: 1.12, translateY: 5)),
                    (1.0, .identity)
                ]
            )
        case .nod:
            activeAction = ActiveAction(
                startTime: time, duration: 0.3,
                keyframes: [
                    (0.0, .identity),
                    (0.35, LayerTransform(rotateZ: -6)),
                    (0.65, LayerTransform(rotateZ: 4)),
                    (1.0, .identity)
                ]
            )
        case .shake:
            activeAction = ActiveAction(
                startTime: time, duration: 0.4,
                keyframes: [
                    (0.0, .identity),
                    (0.2, LayerTransform(rotateZ: 8)),
                    (0.5, LayerTransform(rotateZ: -8)),
                    (0.8, LayerTransform(rotateZ: 4)),
                    (1.0, .identity)
                ]
            )
        case .yawn:
            activeAction = ActiveAction(
                startTime: time, duration: 0.8,
                keyframes: [
                    (0.0, .identity),
                    (0.3, LayerTransform(scaleX: 1.04, scaleY: 0.96, rotateZ: -4)),
                    (0.6, LayerTransform(scaleX: 0.97, scaleY: 1.03, rotateZ: 2)),
                    (1.0, .identity)
                ]
            )
        }
    }

    func evaluate(at time: CFTimeInterval) -> LayerTransform {
        // 自动眨眼
        if isIdle && time >= nextBlinkTime && activeAction == nil {
            play(.blink, at: time)
            scheduleNextBlink(at: time)
        }
        // 打哈欠
        if isIdle && time - lastInteractionTime > yawnThreshold && activeAction == nil {
            play(.yawn, at: time)
            lastInteractionTime = time
        }
        return evaluateAction(at: time)
    }

    private func scheduleNextBlink(at time: CFTimeInterval) {
        nextBlinkTime = time + CFTimeInterval.random(in: 4.0...8.0)
    }

    private func evaluateAction(at time: CFTimeInterval) -> LayerTransform {
        guard let action = activeAction else { return .identity }
        let rawT = CGFloat((time - action.startTime) / action.duration)
        if rawT >= 1.0 {
            activeAction = nil
            return .identity
        }
        let t = max(0, min(1, rawT))
        for i in 0..<(action.keyframes.count - 1) {
            let kf0 = action.keyframes[i]
            let kf1 = action.keyframes[i + 1]
            if t >= kf0.t && t <= kf1.t {
                let span = kf1.t - kf0.t
                let segT = span > 0 ? (t - kf0.t) / span : 1
                return kf0.transform.lerp(to: kf1.transform, t: AnimationCurve.easeInOut.evaluate(at: segT))
            }
        }
        return action.keyframes.last?.transform ?? .identity
    }
}
