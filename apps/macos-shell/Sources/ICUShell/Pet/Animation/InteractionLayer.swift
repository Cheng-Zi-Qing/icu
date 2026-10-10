import QuartzCore
import AppKit

/// 交互反馈层 — 点击/悬停/拖拽的即时动画反馈
final class InteractionLayer {

    private var activeAction: ActiveAction?
    private var hoverTransform = LayerTransform.identity
    private var hoverTarget = LayerTransform.identity
    private var hoverTransitionStart: CFTimeInterval = 0
    private let hoverTransitionDuration: CFTimeInterval = 0.2
    private var isDragging = false

    struct ActiveAction {
        var startTime: CFTimeInterval
        var duration: CFTimeInterval
        var keyframes: [(t: CGFloat, transform: LayerTransform)]
        var curve: AnimationCurve
    }

    // MARK: - 鼠标悬停（视差偏头）

    func handleMouseEntered(at time: CFTimeInterval) {
        hoverTransitionStart = time
        hoverTarget = LayerTransform(scaleX: 1.05, scaleY: 1.05)
    }

    func handleMouseMoved(localPosition: CGPoint, petBounds: CGRect, at time: CFTimeInterval) {
        guard !isDragging else { return }
        let cx = petBounds.midX, cy = petBounds.midY
        let dx = (localPosition.x - cx) / max(petBounds.width / 2, 1)
        let dy = (localPosition.y - cy) / max(petBounds.height / 2, 1)
        hoverTarget = LayerTransform(
            scaleX: 1.05, scaleY: 1.05,
            rotateX: CGFloat(dy) * 5,
            rotateY: CGFloat(dx) * 8,
            perspective: -1.0 / 500
        )
    }

    func handleMouseExited(at time: CFTimeInterval) {
        hoverTransitionStart = time
        hoverTarget = LayerTransform.identity
    }

    // MARK: - 点击（squash & stretch）

    func handleMouseDown(at time: CFTimeInterval) {
        guard !isDragging else { return }
        playAction(ActiveAction(
            startTime: time,
            duration: 0.25,
            keyframes: [
                (t: 0.0, transform: LayerTransform.identity),
                (t: 0.24, transform: LayerTransform(scaleX: 1.18, scaleY: 0.82)),
                (t: 0.55, transform: LayerTransform(scaleX: 0.95, scaleY: 1.05)),
                (t: 1.0,  transform: LayerTransform.identity)
            ],
            curve: .spring(stiffness: 280, damping: 22)
        ))
    }

    func handleMouseUp(at time: CFTimeInterval) {}

    func handleDoubleClick(at time: CFTimeInterval) {
        playAction(ActiveAction(
            startTime: time,
            duration: 0.4,
            keyframes: [
                (t: 0.0,  transform: LayerTransform.identity),
                (t: 0.25, transform: LayerTransform(scaleX: 1.1, scaleY: 1.1, translateY: 8)),
                (t: 0.55, transform: LayerTransform(scaleX: 1.05, scaleY: 0.9, translateY: 0)),
                (t: 1.0,  transform: LayerTransform.identity)
            ],
            curve: .spring(stiffness: 260, damping: 18)
        ))
    }

    // MARK: - 拖拽

    func handleDragBegan(at time: CFTimeInterval) {
        isDragging = true
        playAction(ActiveAction(
            startTime: time,
            duration: 0.3,
            keyframes: [
                (t: 0.0, transform: LayerTransform.identity),
                (t: 1.0, transform: LayerTransform(scaleX: 1.06, scaleY: 1.06, rotateZ: 12))
            ],
            curve: .easeOut
        ))
    }

    func handleDragEnded(at time: CFTimeInterval) {
        isDragging = false
        playAction(ActiveAction(
            startTime: time,
            duration: 0.5,
            keyframes: [
                (t: 0.0,  transform: LayerTransform(scaleX: 1.06, scaleY: 0.88, translateY: -2)),
                (t: 0.3,  transform: LayerTransform(scaleX: 0.97, scaleY: 1.03)),
                (t: 0.65, transform: LayerTransform(scaleX: 1.01, scaleY: 0.99)),
                (t: 1.0,  transform: LayerTransform.identity)
            ],
            curve: .spring(stiffness: 240, damping: 18)
        ))
    }

    // MARK: - Evaluate

    func evaluate(at time: CFTimeInterval) -> LayerTransform {
        let actionTransform = evaluateAction(at: time)
        let hover = evaluateHover(at: time)
        return actionTransform + hover
    }

    // MARK: - Private

    private func playAction(_ action: ActiveAction) {
        activeAction = action
    }

    private func evaluateAction(at time: CFTimeInterval) -> LayerTransform {
        guard let action = activeAction else { return .identity }
        let rawT = CGFloat((time - action.startTime) / action.duration)
        if rawT >= 1.0 {
            activeAction = nil
            return .identity
        }
        let t = max(0, min(1, rawT))
        // 按 keyframe 段插值
        for i in 0..<(action.keyframes.count - 1) {
            let kf0 = action.keyframes[i]
            let kf1 = action.keyframes[i + 1]
            if t >= kf0.t && t <= kf1.t {
                let span = kf1.t - kf0.t
                let segT = span > 0 ? (t - kf0.t) / span : 1
                let easedT = action.curve.evaluate(at: segT)
                return kf0.transform.lerp(to: kf1.transform, t: easedT)
            }
        }
        return action.keyframes.last?.transform ?? .identity
    }

    private func evaluateHover(at time: CFTimeInterval) -> LayerTransform {
        let rawT = CGFloat((time - hoverTransitionStart) / hoverTransitionDuration)
        let t = AnimationCurve.easeOut.evaluate(at: rawT)
        return hoverTransform.lerp(to: hoverTarget, t: t)
    }
}
