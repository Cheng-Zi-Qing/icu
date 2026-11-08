import AppKit
import QuartzCore

/// 动画引擎主入口 — 驱动 CADisplayLink，把点击蹦跳和拖拽效果写入 imageView.layer。
///
/// 呼吸、眨眼、嚼草这些「活着」的感觉全在逐帧素材里；这里不再叠加漂浮 / 摇摆 / 压扁眨眼。
final class PetAnimationEngine {

    private let interactionLayer = InteractionLayer()
    private let groundShadow = GroundShadowController()

    private weak var targetLayer: CALayer?
    private var displayLink: CVDisplayLink?
    private var lastDragPose: DragPose = .none

    /// 每帧拉取拖拽输出（由 PetDragController 提供）
    var dragOutputProvider: ((CFTimeInterval) -> DragOutput)?
    /// 拖拽姿势变化时回调（用于切换像素姿势帧）
    var onDragPoseChanged: ((DragPose) -> Void)?

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

    // MARK: - 交互事件

    func handleMouseDown() {
        interactionLayer.handleMouseDown(at: CACurrentMediaTime())
    }

    func handleDoubleClick() {
        interactionLayer.handleDoubleClick(at: CACurrentMediaTime())
    }

    // MARK: - 布局

    func layoutShadow(petCanvasBounds: CGRect) {
        groundShadow.layout(petCanvasBounds: petCanvasBounds)
    }

    // MARK: - Tick

    private func tick() {
        guard let layer = targetLayer else { return }
        let t = CACurrentMediaTime()
        let base = baseTransform(at: t)
        let drag = dragOutputProvider?(t) ?? .rest

        if drag.pose != lastDragPose {
            lastDragPose = drag.pose
            onDragPoseChanged?(drag.pose)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.transform = Self.composedTransform(base: base, drag: drag, layerBounds: layer.bounds, anchorPoint: layer.anchorPoint)
        CATransaction.commit()

        let lifted = drag.pose == .none || drag.pose.isLanding ? 0 : Self.liftedShadowHeight
        groundShadow.update(floatHeight: base.translateY / InteractionLayer.spritePixel + lifted)
    }

    /// 拎起来时阴影按“浮高”这么多来缩小变淡
    private static let liftedShadowHeight: CGFloat = 3.5

    /// 合成最终 transform：
    /// - 常规效果与落地压扁以脚底中点为轴（站在地上缩放，不会往右上角长）
    /// - 麻糬拉长以头顶中点为轴（像被拎着往下坠），横向按体积守恒收窄
    static func composedTransform(
        base: LayerTransform,
        drag: DragOutput,
        layerBounds: CGRect,
        anchorPoint: CGPoint
    ) -> CATransform3D {
        let anchor = CGPoint(x: layerBounds.width * anchorPoint.x, y: layerBounds.height * anchorPoint.y)
        let bottomCenter = CGPoint(x: layerBounds.width / 2 - anchor.x, y: -anchor.y)
        let topCenter = CGPoint(x: layerBounds.width / 2 - anchor.x, y: layerBounds.height - anchor.y)

        let squash = drag.landingSquash
        let landing = LayerTransform(scaleX: 1 + (1 - squash) * 0.8, scaleY: squash)
        let stretchY = max(drag.stretchY, 0.01)
        let stretch = LayerTransform(scaleX: 1 / stretchY.squareRoot(), scaleY: stretchY)

        let baseMatrix = pivoted(base.caTransform, around: bottomCenter)
        let landingMatrix = pivoted(landing.caTransform, around: bottomCenter)
        let stretchMatrix = pivoted(stretch.caTransform, around: topCenter)
        return CATransform3DConcat(CATransform3DConcat(stretchMatrix, landingMatrix), baseMatrix)
    }

    private static func pivoted(_ transform: CATransform3D, around pivot: CGPoint) -> CATransform3D {
        let toPivot = CATransform3DMakeTranslation(-pivot.x, -pivot.y, 0)
        let back = CATransform3DMakeTranslation(pivot.x, pivot.y, 0)
        return CATransform3DConcat(CATransform3DConcat(toPivot, transform), back)
    }

    /// 除拖拽以外的变换：只有点击蹦跳（整像素）
    func baseTransform(at t: CFTimeInterval) -> LayerTransform {
        interactionLayer.evaluate(at: t)
    }
}
