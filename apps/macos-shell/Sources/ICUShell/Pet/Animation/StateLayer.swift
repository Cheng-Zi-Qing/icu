import QuartzCore
import Foundation

/// 状态动作层 — 响应工作状态切换，播放过渡动画到目标姿态
final class StateLayer {

    struct Posture {
        var baseScale: CGFloat
        var tiltDegrees: CGFloat
        var verticalShift: CGFloat
        var transitionDuration: CFTimeInterval
        var transitionCurve: AnimationCurve
    }

    static func posture(for stateID: String) -> Posture {
        switch stateID {
        case "working":
            return Posture(baseScale: 1.02, tiltDegrees: -2.0, verticalShift: 1.0,
                           transitionDuration: 0.5, transitionCurve: .spring(stiffness: 280, damping: 22))
        case "focus":
            return Posture(baseScale: 0.98, tiltDegrees: -1.0, verticalShift: -1.0,
                           transitionDuration: 0.6, transitionCurve: .easeInOut)
        case "alert":
            return Posture(baseScale: 1.04, tiltDegrees: 2.0, verticalShift: 2.0,
                           transitionDuration: 0.45, transitionCurve: .spring(stiffness: 260, damping: 20))
        default: // idle
            return Posture(baseScale: 1.00, tiltDegrees: 0.0, verticalShift: 0.0,
                           transitionDuration: 0.4, transitionCurve: .easeOut)
        }
    }

    private var fromTransform = LayerTransform.identity
    private var targetTransform = LayerTransform.identity
    private var transitionStart: CFTimeInterval = 0
    private var transitionDuration: CFTimeInterval = 0
    private var transitionCurve: AnimationCurve = .easeOut

    func setStateID(_ stateID: String, at time: CFTimeInterval, currentTransform: LayerTransform) {
        let posture = StateLayer.posture(for: stateID)
        fromTransform = currentTransform
        targetTransform = LayerTransform(
            scaleX: posture.baseScale,
            scaleY: posture.baseScale,
            rotateZ: posture.tiltDegrees,
            translateY: posture.verticalShift
        )
        transitionStart = time
        transitionDuration = posture.transitionDuration
        transitionCurve = posture.transitionCurve
    }

    func evaluate(at time: CFTimeInterval) -> LayerTransform {
        guard transitionDuration > 0 else { return targetTransform }
        let rawT = CGFloat((time - transitionStart) / transitionDuration)
        let t = transitionCurve.evaluate(at: rawT)
        return fromTransform.lerp(to: targetTransform, t: t)
    }
}
