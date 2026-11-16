import AppKit
import QuartzCore

/// 被拎起来时的大画框：透明、不接鼠标的子窗口，挂在桌宠窗口上跟着一起移动。
///
/// 桌宠窗口只有画布那么大，身体一拉长、一甩就会被窗口边裁掉；
/// 拎着的这段时间改在这里画，四周留够地方让它荡到最大角度也能整只露出来。
///
/// 画法：当前帧先还原成原像素格（一格 4pt），拉长、收细、甩动都在这张小图上按整格做
/// （见 PixelSpriteHanging），再整张最近邻放大上屏。位置也按整格对齐，所以屏幕上的方块
/// 和地上那只一样大、一样齐，不会半格错位或被拉成扁格。
final class PetLiftWindow: NSWindow {
    /// 左右各留多少：甩到 60° 时身体最远荡出画布约 88pt
    static let sideMargin: CGFloat = 112
    /// 头顶留白：拎着时身体抬高 liftHeight（56pt），甩到 60° 时脑袋那一角（柚子、叶子）还会翘出画布顶 32pt；
    /// 再多留一格，保持 4pt 对齐
    static let topMargin: CGFloat = 92
    /// 脚下留白：拉长后身体往下坠
    static let bottomMargin: CGFloat = 64

    /// 唯一上屏的图层：整窗一张低分辨率位图，一格放大成 4pt
    let rasterLayer = CALayer()
    /// 当前帧还原出的原像素格；nil 表示还没有可画的帧
    private(set) var sprite: PixelSpriteGrid?
    /// 原像素格在窗口里的位置（左下角，单位：格）
    private var spriteOrigin = (x: 0, y: 0)
    /// 后颈（画布顶边中点）在 sprite 里的位置，格子坐标、y 向下
    private var scruff = CGPoint.zero
    /// 某一帧拉长到某个行数后的样子和它的 8 倍平滑图。按帧的内容存，不随换帧清空：
    /// 甩起来歪向帧来回换、晕的时候星星一闪一闪，都是那几张图，换回来直接用，不用每次重算
    private var hangingCache: [HangingKey: (sprite: PixelSpriteGrid, oversampled: PixelSpriteGrid?)] = [:]
    /// 缓存最多留几份（一份 8 倍图约 400KB）；满了整个清掉重来，拖拽姿势帧一共也就二三十张
    private static let hangingCacheLimit = 32
    private var lastRenderedKey: RenderKey?
    private var lastDrag = DragOutput.rest

    private struct HangingKey: Hashable {
        let sprite: PixelSpriteGrid
        let bodyRows: Int
    }

    /// 同一个 key 画出来的图完全一样：拉长按整行、角度按整度、抬高按整格
    private struct RenderKey: Equatable {
        let bodyRows: Int
        let degrees: Int
        let lift: Int
    }

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
        rasterLayer.anchorPoint = .zero
        rasterLayer.contentsGravity = .resize
        rasterLayer.magnificationFilter = .nearest
        rasterLayer.minificationFilter = .nearest
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
        rasterLayer.frame = CGRect(origin: .zero, size: frame.size)
        rasterLayer.contentsScale = parent.backingScaleFactor
        CATransaction.commit()
        if !isVisible { lastDrag = .rest }
        setImage(image, canvasSize: canvas.size)
        if self.parent !== parent {
            self.parent?.removeChildWindow(self)
            parent.addChildWindow(self, ordered: .above)
        }
        orderFront(nil)
    }

    /// 换一帧：还原成原像素格后按当前拎着的样子重画。帧缺失时保留上一张，不闪空
    func setImage(_ image: NSImage?) {
        setImage(image, canvasSize: CGSize(
            width: frame.width - 2 * Self.sideMargin,
            height: frame.height - Self.bottomMargin - Self.topMargin
        ))
    }

    private func setImage(_ image: NSImage?, canvasSize: CGSize) {
        guard let image, let placement = Self.placement(of: image, canvasSize: canvasSize) else { return }
        sprite = placement.sprite
        spriteOrigin = placement.origin
        scruff = placement.scruff
        lastRenderedKey = nil
        render(drag: lastDrag)
    }

    /// 按拖拽输出重画；和上一帧画出来一样时什么都不做
    func render(drag: DragOutput) {
        lastDrag = drag
        guard let sprite else { return }
        let pixel = InteractionLayer.spritePixel
        let headRows = sprite.height - Self.bodyRows(in: sprite)
        let key = RenderKey(
            bodyRows: PixelSpriteHanging.stretchedBodyRows(bodyRows: sprite.height - headRows, stretch: drag.stretchY),
            degrees: Int(drag.swingDegrees.rounded()),
            lift: Int((drag.fallOffset / pixel).rounded())
        )
        guard key != lastRenderedKey else { return }
        let hanging = hangingSprite(from: sprite, headRows: headRows, bodyRows: key.bodyRows, needsOversample: key.degrees != 0)
        let columns = Int((rasterLayer.bounds.width / pixel).rounded())
        let rows = Int((rasterLayer.bounds.height / pixel).rounded())
        // 网格第 0 行在上：原画布顶边（后颈所在行）抬高 lift 格
        let top = rows - (spriteOrigin.y + sprite.height + key.lift)
        let composed = PixelSpriteHanging.placed(
            hanging.sprite, oversampled: hanging.oversampled, degrees: key.degrees, pivot: scruff,
            origin: (spriteOrigin.x, top), canvasWidth: columns, canvasHeight: rows
        )
        guard let image = composed.makeImage() else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rasterLayer.contents = image
        CATransaction.commit()
        lastRenderedKey = key
    }

    private func hangingSprite(
        from sprite: PixelSpriteGrid, headRows: Int, bodyRows: Int, needsOversample: Bool
    ) -> (sprite: PixelSpriteGrid, oversampled: PixelSpriteGrid?) {
        let key = HangingKey(sprite: sprite, bodyRows: bodyRows)
        let cached = hangingCache[key] ?? (PixelSpriteHanging.hanging(
            sprite, headRows: headRows, stretchedBodyRows: bodyRows, slimming: PetAnimationEngine.liftedSlimming
        ), nil)
        let entry = needsOversample && cached.oversampled == nil
            ? (cached.sprite, PixelSpriteHanging.oversampled(cached.sprite))
            : cached
        if hangingCache[key] == nil, hangingCache.count >= Self.hangingCacheLimit {
            hangingCache.removeAll()
        }
        hangingCache[key] = entry
        return entry
    }

    /// 脖子以下有几行（按整行取整，不切开一格像素）
    static func bodyRows(in sprite: PixelSpriteGrid) -> Int {
        min(sprite.height - 1, max(1, Int((CGFloat(sprite.height) * PetAnimationEngine.liftedBodyShare).rounded())))
    }

    /// 帧图按原像素格还原，并算出它在拎起窗口里落在哪几格
    private static func placement(
        of image: NSImage, canvasSize: CGSize
    ) -> (sprite: PixelSpriteGrid, origin: (x: Int, y: Int), scruff: CGPoint)? {
        let pixel = InteractionLayer.spritePixel
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let fit = aspectFit(image.size, in: CGRect(origin: .zero, size: canvasSize))
        let columns = Int((fit.width / pixel).rounded())
        let rows = Int((fit.height / pixel).rounded())
        guard rows > 1, let sprite = PixelSpriteGrid.sampling(cg, columns: columns, rows: rows) else { return nil }
        let origin = (
            x: Int(((sideMargin + fit.minX) / pixel).rounded()),
            y: Int(((bottomMargin + fit.minY) / pixel).rounded())
        )
        // 后颈：画布顶边中点，换算到 sprite 自己的格子坐标里
        let scruff = CGPoint(
            x: (sideMargin + canvasSize.width / 2) / pixel - CGFloat(origin.x),
            y: CGFloat(origin.y + rows) - (bottomMargin + canvasSize.height) / pixel
        )
        return (sprite, origin, scruff)
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
