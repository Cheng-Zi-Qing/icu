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
    /// 拎在半空时实际显示桌宠的图层（拎起窗口里的那张）；nil 表示还在原窗口里画
    var liftedLayer: (() -> CALayer?)?

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
        if drag.pose.isLifted, let lifted = liftedLayer?() {
            lifted.transform = Self.liftedTransform(drag: drag, layerBounds: lifted.bounds, anchorPoint: lifted.anchorPoint)
            layer.transform = CATransform3DIdentity
        } else {
            layer.transform = Self.composedTransform(base: base, drag: drag, layerBounds: layer.bounds, anchorPoint: layer.anchorPoint)
        }
        CATransaction.commit()

        // 阴影按实际离地高度浮高：贴地时不含偏移（和贴地待机一致），拎着和下落时跟着下沉
        groundShadow.update(floatHeight: base.translateY / InteractionLayer.spritePixel + drag.fallOffset / InteractionLayer.spritePixel)
    }

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
        let lifted = CATransform3DConcat(CATransform3DConcat(stretchMatrix, landingMatrix), baseMatrix)
        // 离地抬高放最后一手：压扁、拉长都按贴地的脚底/头顶算，抬多少再整体搬多少
        return CATransform3DConcat(lifted, CATransform3DMakeTranslation(0, drag.fallOffset, 0))
    }

    /// 拎在半空：先以后颈（头顶中点）为轴往下拉长，再绕后颈按摆角甩出去。
    /// 摆角为负 = 下半身往左（图层坐标 y 向上，逆时针转脚往右，所以角度直接用）
    static func liftedTransform(drag: DragOutput, layerBounds: CGRect, anchorPoint: CGPoint) -> CATransform3D {
        let anchor = CGPoint(x: layerBounds.width * anchorPoint.x, y: layerBounds.height * anchorPoint.y)
        let scruff = CGPoint(x: layerBounds.width / 2 - anchor.x, y: layerBounds.height - anchor.y)
        let stretchY = max(drag.stretchY, 0.01)
        let stretch = LayerTransform(scaleX: 1 / stretchY.squareRoot(), scaleY: stretchY)
        let swing = CATransform3DMakeRotation(drag.swingDegrees * .pi / 180, 0, 0, 1)
        let hanging = CATransform3DConcat(pivoted(stretch.caTransform, around: scruff), pivoted(swing, around: scruff))
        // 离地抬高放最后一手：摆动的支点（后颈）跟着身体一起抬，视觉上是整只被拎高
        return CATransform3DConcat(hanging, CATransform3DMakeTranslation(0, drag.fallOffset, 0))
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
