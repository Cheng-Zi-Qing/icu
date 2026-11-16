import AppKit
import QuartzCore

/// 被拎起来时的大画框：透明、不接鼠标的子窗口，挂在桌宠窗口上跟着一起移动。
///
/// 桌宠窗口只有画布那么大，身体一拉长、一甩就会被窗口边裁掉；
/// 拎着的这段时间改在这里画，四周留够地方让它荡到最大角度也能整只露出来。
final class PetLiftWindow: NSWindow {
    /// 左右各留多少：最大摆角时脚能荡出画布约 90pt
    static let sideMargin: CGFloat = 112
    /// 头顶留白：拎着时身体抬高 liftHeight，转起来时画布上角还会再翘 20pt
    static let topMargin: CGFloat = 76
    /// 脚下留白：拉长后身体往下坠
    static let bottomMargin: CGFloat = 64

    /// 原图与几何数据；实际显示统一由 rasterLayer 在原像素格合成
    let spriteLayer = CALayer()
    let rasterLayer = CALayer()
    private var lastRenderedDrag: DragOutput?
    private var lastDrag = DragOutput.rest
    /// 脖子以上：拎着时不变形
    let headLayer = CALayer()
    /// 脖子以下：锚点在上沿（脖子），往下拉长
    let bodyLayer = CALayer()

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
        spriteLayer.isHidden = true
        rasterLayer.anchorPoint = .zero
        rasterLayer.contentsGravity = .resize
        rasterLayer.magnificationFilter = .nearest
        rasterLayer.minificationFilter = .nearest
        for part in [bodyLayer, headLayer] {
            part.contentsGravity = .resize
            part.magnificationFilter = .nearest
            part.minificationFilter = .nearest
            spriteLayer.addSublayer(part)
        }
        bodyLayer.anchorPoint = CGPoint(x: 0.5, y: 1)
        content.layer?.addSublayer(spriteLayer)
        content.layer?.addSublayer(rasterLayer)
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
        bodyLayer.transform = CATransform3DIdentity
        spriteLayer.frame = NSRect(x: Self.sideMargin, y: Self.bottomMargin, width: canvas.width, height: canvas.height)
        rasterLayer.frame = CGRect(origin: .zero, size: frame.size)
        rasterLayer.contentsScale = parent.backingScaleFactor
        lastRenderedDrag = nil
        for part in [headLayer, bodyLayer] {
            part.contentsScale = parent.backingScaleFactor
        }
        CATransaction.commit()
        if !isVisible { lastDrag = .rest }
        setImage(image)
        if self.parent !== parent {
            self.parent?.removeChildWindow(self)
            parent.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    /// 换一帧：按脖子那一行切成脑袋、身体两块，各自摆在画布里原来的位置（拼起来就是整张图）
    func setImage(_ image: NSImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let halves = image.flatMap(Self.split)
        guard let halves, let image else {
            CATransaction.commit()
            return
        }
        lastRenderedDrag = nil
        headLayer.contents = halves.head
        bodyLayer.contents = halves.body
        let fit = Self.aspectFit(image.size, in: spriteLayer.bounds)
        let bodyHeight = fit.height * halves.bodyShare
        headLayer.frame = CGRect(x: fit.minX, y: fit.minY + bodyHeight, width: fit.width, height: fit.height - bodyHeight)
        bodyLayer.frame = CGRect(x: fit.minX, y: fit.minY, width: fit.width, height: bodyHeight)
        CATransaction.commit()
        render(drag: lastDrag)
    }

    /// 先在 4pt 原像素格摆动、拉伸，再用单张位图整数放大，变形不再打碎像素边缘。
    func render(drag: DragOutput) {
        lastDrag = drag
        guard lastRenderedDrag != drag,
              let head = headLayer.contents,
              let body = bodyLayer.contents else { return }
        let pixel = InteractionLayer.spritePixel
        let width = Int(rasterLayer.bounds.width / pixel)
        let height = Int(rasterLayer.bounds.height / pixel)
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: 1 / pixel, y: 1 / pixel)
        context.translateBy(x: spriteLayer.frame.minX, y: spriteLayer.frame.minY)
        context.concatenate(CATransform3DGetAffineTransform(PetAnimationEngine.liftedTransform(
            drag: drag, layerBounds: spriteLayer.bounds, anchorPoint: spriteLayer.anchorPoint
        )))
        context.saveGState()
        let bodyFrame = bodyLayer.frame
        context.translateBy(x: bodyFrame.midX, y: bodyFrame.maxY)
        context.concatenate(CATransform3DGetAffineTransform(PetAnimationEngine.liftedBodyTransform(stretchY: drag.stretchY)))
        context.draw(body as! CGImage, in: CGRect(x: -bodyFrame.width / 2, y: -bodyFrame.height, width: bodyFrame.width, height: bodyFrame.height))
        context.restoreGState()
        context.draw(head as! CGImage, in: headLayer.frame)
        guard let image = context.makeImage() else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rasterLayer.contents = image
        CATransaction.commit()
        lastRenderedDrag = drag
    }

    /// 切在脖子那一行（按像素行取整，不切开一格像素）
    private static func split(_ image: NSImage) -> (head: CGImage, body: CGImage, bodyShare: CGFloat)? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), cg.height > 1 else { return nil }
        let bodyRows = min(cg.height - 1, max(1, Int((CGFloat(cg.height) * PetAnimationEngine.liftedBodyShare).rounded())))
        let headRows = cg.height - bodyRows
        guard
            let head = cg.cropping(to: CGRect(x: 0, y: 0, width: cg.width, height: headRows)),
            let body = cg.cropping(to: CGRect(x: 0, y: headRows, width: cg.width, height: bodyRows))
        else { return nil }
        return (head, body, CGFloat(bodyRows) / CGFloat(cg.height))
    }

    private static func aspectFit(_ size: NSSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - fitted.width / 2, y: bounds.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
    }

    func hide() {
        guard isVisible || parent != nil else { return }
        parent?.removeChildWindow(self)
        orderOut(nil)
    }
}
