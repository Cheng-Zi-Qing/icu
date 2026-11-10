import QuartzCore
import AppKit

/// 交互反馈层 — 点一下蹦一格、双击蹦两格；场景也可以要求抛高几格。
///
/// 像素桌宠（Shimeji、oneko、VPet 都是逐帧动画）的动作只按整像素走：
/// 不缩放、不旋转、不做 3D 偏头——那些补间会把像素糊掉，偏头还会让身体盖住状态标签。
/// 悬停、摸头、打盹这些「表情」由逐帧素材负责（见 PetBehaviorCoordinator）。
final class InteractionLayer {
    /// 1 个素材像素 = 4pt（32px 素材放进 128pt 画布）
    static let spritePixel: CGFloat = 4

    private struct Hop {
        var startTime: CFTimeInterval
        var duration: CFTimeInterval
        var pixels: CGFloat
    }

    private var hop: Hop?

    func handleMouseDown(at time: CFTimeInterval) {
        hop = Hop(startTime: time, duration: 0.2, pixels: 1)
    }

    func handleDoubleClick(at time: CFTimeInterval) {
        hop = Hop(startTime: time, duration: 0.32, pixels: 2)
    }

    /// 场景里要求的起跳（干完了开心跳）：抛 `pixels` 个素材像素高，`duration` 秒落地
    func hop(pixels: Int, duration: CFTimeInterval, at time: CFTimeInterval) {
        guard pixels > 0, duration > 0 else { return }
        hop = Hop(startTime: time, duration: duration, pixels: CGFloat(pixels))
    }

    func evaluate(at time: CFTimeInterval) -> LayerTransform {
        guard let hop else { return .identity }
        let progress = (time - hop.startTime) / hop.duration
        guard progress >= 0, progress < 1 else {
            if progress >= 1 { self.hop = nil }
            return .identity
        }
        // 抛物线起落，高度取整到整像素
        let arc = 4 * progress * (1 - progress)
        let height = (CGFloat(arc) * hop.pixels).rounded() * Self.spritePixel
        return LayerTransform(translateY: height)
    }
}
