import AppKit
import QuartzCore

/// 被拎起来时的大画框：透明、不接鼠标的子窗口，挂在桌宠窗口上跟着一起移动。
///
/// 桌宠窗口只有画布那么大，身体一拉长、一甩就会被窗口边裁掉；
/// 拎着的这段时间改在这里画，四周留够地方让它荡到最大角度也能整只露出来。
final class PetLiftWindow: NSWindow {
    /// 左右各留多少：最大摆角时脚能荡出画布约 90pt
    static let sideMargin: CGFloat = 112
    /// 头顶留白：转起来时画布上角会翘到后颈上方
    static let topMargin: CGFloat = 48
    /// 脚下留白：拉长后身体往下坠
    static let bottomMargin: CGFloat = 64

    let spriteLayer = CALayer()

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        let content = NSView()
        content.wantsLayer = true
        contentView = content
        spriteLayer.anchorPoint = .zero
        spriteLayer.contentsGravity = .resizeAspect
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.minificationFilter = .nearest
        content.layer?.addSublayer(spriteLayer)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// 画布（屏幕坐标）外扩一圈
    static func frame(around canvas: NSRect) -> NSRect {
        NSRect(
            x: canvas.minX - sideMargin,
            y: canvas.minY - bottomMargin,
            width: canvas.width + 2 * sideMargin,
            height: canvas.height + bottomMargin + topMargin
        )
    }

    /// 盖在桌宠画布上显示；`canvas` 是画布的屏幕坐标
    func show(image: NSImage?, canvas: NSRect, over parent: NSWindow) {
        setFrame(Self.frame(around: canvas), display: false)
        level = parent.level
        collectionBehavior = parent.collectionBehavior
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.transform = CATransform3DIdentity
        spriteLayer.frame = NSRect(x: Self.sideMargin, y: Self.bottomMargin, width: canvas.width, height: canvas.height)
        spriteLayer.contentsScale = parent.backingScaleFactor
        CATransaction.commit()
        setImage(image)
        if self.parent !== parent {
            self.parent?.removeChildWindow(self)
            parent.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    func setImage(_ image: NSImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.contents = image
        CATransaction.commit()
    }

    func hide() {
        guard isVisible || parent != nil else { return }
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
}
