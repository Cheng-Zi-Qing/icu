import AppKit
import QuartzCore

/// 动画引擎主入口 — 统一调度四层，驱动 CADisplayLink，写入 imageView.layer
final class PetAnimationEngine {

    private let lifeLayer = LifeLayer()
    private let stateLayer = StateLayer()
    private let interactionLayer = InteractionLayer()
    private let expressionLayer = ExpressionLayer()
    private let groundShadow = GroundShadowController()

    private weak var targetLayer: CALayer?
    private var displayLink: CVDisplayLink?
    private var currentStateID = "idle"

    var groundShadowLayer: CALayer { groundShadow.shadowLayer }

    // MARK: - 生命周期

    func attachTo(layer: CALayer) {
        self.targetLayer = layer
    }

    func start() {
        guard displayLink == nil else { return }
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.tick() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
    }

    func stop() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
    }

    func pause() { if let link = displayLink { CVDisplayLinkStop(link) } }
    func resume() { if let link = displayLink { CVDisplayLinkStart(link) } }

    // MARK: - 状态输入

    func setWorkState(_ state: ShellWorkState) {
        let stateID: String
        switch state {
        case .idle:       stateID = "idle"
        case .working:    stateID = "working"
        case .focus:      stateID = "focus"
        case .breakState: stateID = "alert"
        }
        guard stateID != currentStateID else { return }
        currentStateID = stateID
        let t = CACurrentMediaTime()
        let current = evaluateAll(at: t)
        lifeLayer.setStateID(stateID, at: t)
        stateLayer.setStateID(stateID, at: t, currentTransform: current)
        expressionLayer.setIdle(state == .idle, at: t)
        if state == .working {
            expressionLayer.play(.surprised, at: t)
        }
    }

    // MARK: - 交互事件

    func handleMouseEntered() {
        let t = CACurrentMediaTime()
        interactionLayer.handleMouseEntered(at: t)
        expressionLayer.notifyInteraction(at: t)
    }

    func handleMouseMoved(localPosition: CGPoint, petBounds: CGRect) {
        interactionLayer.handleMouseMoved(localPosition: localPosition, petBounds: petBounds, at: CACurrentMediaTime())
    }

    func handleMouseExited() {
        interactionLayer.handleMouseExited(at: CACurrentMediaTime())
    }

    func handleMouseDown() {
        let t = CACurrentMediaTime()
        interactionLayer.handleMouseDown(at: t)
        expressionLayer.notifyInteraction(at: t)
    }

    func handleMouseUp() {
        interactionLayer.handleMouseUp(at: CACurrentMediaTime())
    }

    func handleDoubleClick() {
        let t = CACurrentMediaTime()
        interactionLayer.handleDoubleClick(at: t)
        expressionLayer.notifyInteraction(at: t)
    }

    func handleDragBegan() {
        interactionLayer.handleDragBegan(at: CACurrentMediaTime())
    }

    func handleDragEnded() {
        interactionLayer.handleDragEnded(at: CACurrentMediaTime())
    }

    func playExpression(_ expression: ExpressionLayer.Expression) {
        expressionLayer.play(expression, at: CACurrentMediaTime())
    }

    // MARK: - 布局

    func layoutShadow(petCanvasBounds: CGRect) {
        groundShadow.layout(petCanvasBounds: petCanvasBounds)
    }

    // MARK: - Tick

    private func tick() {
        guard let layer = targetLayer else { return }
        let t = CACurrentMediaTime()
        let transform = evaluateAll(at: t)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = transform.caTransform
        CATransaction.commit()
        groundShadow.update(floatHeight: lifeLayer.currentTranslateY)
    }

    private func evaluateAll(at t: CFTimeInterval) -> LayerTransform {
        lifeLayer.evaluate(at: t)
            + stateLayer.evaluate(at: t)
            + interactionLayer.evaluate(at: t)
            + expressionLayer.evaluate(at: t)
    }
}
