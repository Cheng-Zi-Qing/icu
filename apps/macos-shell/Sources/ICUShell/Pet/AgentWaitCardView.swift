import AppKit

/// 在等你时桌宠头顶的卡片：谁在等、等什么，「跳过去」切回那个终端，「知道了」先收起来。
/// 和提醒卡一个样子（像素底板 + 指向桌宠的小尖角），挂着时不抢焦点
final class AgentWaitCardView: NSView {
    private enum Metrics {
        static let tailHeight: CGFloat = 6
        static let padding: CGFloat = 6
        static let textInset: CGFloat = 8
        static let titleHeight: CGFloat = 18
        static let detailTop: CGFloat = 24
        static let detailHeight: CGFloat = 16
        static let buttonsTop: CGFloat = 44
        static let buttonHeight: CGFloat = 22
        static let buttonGap: CGFloat = 4
    }

    static let height = Metrics.buttonsTop + Metrics.buttonHeight + Metrics.padding + Metrics.tailHeight

    let jumpButton = PixelButton(title: "跳过去", identifier: "desktopPet.waitCard.jump")
    let dismissButton = PixelButton(title: "知道了", identifier: "desktopPet.waitCard.dismiss")

    private(set) var content: AgentWaitCardContent?
    var onJump: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with content: AgentWaitCardContent) {
        self.content = content
        jumpButton.isHidden = content.appBundleID == nil
        setAccessibilityLabel("\(content.title)，\(content.detail)")
        needsLayout = true
        needsDisplay = true
    }

    // MARK: - 布局与绘制

    override func layout() {
        super.layout()
        let inner = bounds.width - Metrics.textInset * 2
        guard !jumpButton.isHidden else {
            dismissButton.frame = NSRect(x: Metrics.textInset, y: Metrics.buttonsTop, width: inner, height: Metrics.buttonHeight)
            return
        }
        let half = ((inner - Metrics.buttonGap) / 2 / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        jumpButton.frame = NSRect(x: Metrics.textInset, y: Metrics.buttonsTop, width: half, height: Metrics.buttonHeight)
        dismissButton.frame = NSRect(
            x: bounds.width - Metrics.textInset - half, y: Metrics.buttonsTop, width: half, height: Metrics.buttonHeight
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let content else { return }
        let plate = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - Metrics.tailHeight)
        PixelPaint.plate(plate, PixelPalette.paper, corner: 2)
        drawTail(below: plate)
        let width = bounds.width - Metrics.textInset * 2
        PixelPaint.text(content.title, in: NSRect(x: Metrics.textInset, y: Metrics.padding, width: width, height: Metrics.titleHeight))
        PixelPaint.text(
            content.detail,
            in: NSRect(x: Metrics.textInset, y: Metrics.detailTop, width: width, height: Metrics.detailHeight),
            color: PixelPalette.shade
        )
    }

    /// 底边正中往下的小尖角，指向桌宠
    private func drawTail(below plate: NSRect) {
        let unit = PixelPaint.unit
        for row in 0..<4 {
            let half = CGFloat(4 - row) * unit
            let y = plate.maxY - unit + CGFloat(row) * unit
            PixelPaint.fill(NSRect(x: bounds.midX - half, y: y, width: half * 2, height: unit), PixelPalette.outline)
            if half > unit {
                PixelPaint.fill(NSRect(x: bounds.midX - half + unit, y: y, width: half * 2 - unit * 2, height: unit), PixelPalette.paper)
            }
        }
    }

    // MARK: - 点击

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// 按钮优先；卡片其余部分吃掉点击，不让它掉到桌面上
    func interactiveHitView(at point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.001 else { return nil }
        for button in [jumpButton, dismissButton] where !button.isHidden {
            if button.bounds.contains(convert(point, to: button)) { return button }
        }
        return bounds.contains(point) ? self : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        interactiveHitView(at: convert(point, from: superview))
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}

    // MARK: - 私有

    private func setup() {
        wantsLayer = true
        jumpButton.fillColor = PixelPalette.yellow
        dismissButton.fillColor = PixelPalette.paper2
        jumpButton.target = self
        jumpButton.action = #selector(handleJump)
        dismissButton.target = self
        dismissButton.action = #selector(handleDismiss)
        addSubview(jumpButton)
        addSubview(dismissButton)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @objc private func handleJump() {
        guard let bundleID = content?.appBundleID else { return }
        onJump?(bundleID)
    }

    @objc private func handleDismiss() {
        onDismiss?()
    }
}
