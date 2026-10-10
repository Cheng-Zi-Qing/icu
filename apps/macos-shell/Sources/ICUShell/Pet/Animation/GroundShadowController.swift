import AppKit
import QuartzCore

/// 落地阴影控制器 — 在桌宠下方渲染椭圆软阴影，随浮动高度动态变化
final class GroundShadowController {

    private(set) var shadowLayer: CALayer = {
        let layer = CALayer()
        layer.cornerRadius = 6
        layer.backgroundColor = NSColor.black.withAlphaComponent(0.28).cgColor
        layer.shadowRadius = 0
        return layer
    }()

    private let baseOpacity: Float = 0.28
    private let baseScaleX: CGFloat = 1.0

    /// 根据桌宠 canvas 大小更新阴影 frame（在 layout 时调用）
    func layout(petCanvasBounds: CGRect) {
        let shadowW = petCanvasBounds.width * 0.55
        let shadowH: CGFloat = 10
        shadowLayer.frame = CGRect(
            x: petCanvasBounds.midX - shadowW / 2,
            y: petCanvasBounds.minY - shadowH / 2 + 2,
            width: shadowW,
            height: shadowH
        )
        shadowLayer.cornerRadius = shadowH / 2
    }

    /// 每帧调用，根据当前浮动高度更新阴影外观
    func update(floatHeight: CGFloat) {
        // floatHeight 约 -2.5 ~ +2.5px；越高阴影越小越淡
        let normalized = floatHeight / 3.5   // -1 ~ 1
        let opacity = baseOpacity - Float(normalized) * 0.07
        let scaleX = baseScaleX - normalized * 0.05
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadowLayer.opacity = max(0.05, min(0.35, opacity))
        shadowLayer.transform = CATransform3DMakeScale(max(0.8, scaleX), 1, 1)
        CATransaction.commit()
    }
}
