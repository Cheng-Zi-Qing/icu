import AppKit

/// 像素风的立体按钮：可以放字或图标；按下时凹下去，禁用时变淡
final class PixelButton: NSControl {
    var title: String? { didSet { needsDisplay = true; setAccessibilityLabel(title) } }
    var icon: PixelIcon? { didSet { needsDisplay = true } }
    var fillColor: NSColor = PixelPalette.paper2 { didSet { needsDisplay = true } }
    var textColor: NSColor = PixelPalette.outline { didSet { needsDisplay = true } }
    /// 不画立体边框（菜单行用），只在鼠标悬停时铺一层底色
    var isFlat = false { didSet { needsDisplay = true } }
    var textAlignment: CGFloat = 0.5 { didSet { needsDisplay = true } }

    private var isPressed = false { didSet { needsDisplay = true } }
    private var isHovered = false { didSet { needsDisplay = true } }
    private var trackingAreaRef: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var isEnabled: Bool { didSet { needsDisplay = true } }

    init(title: String? = nil, icon: PixelIcon? = nil, identifier: String) {
        self.title = title
        self.icon = icon
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = isEnabled ? 1 : 0.4
        NSGraphicsContext.current?.saveGraphicsState()
        defer { NSGraphicsContext.current?.restoreGraphicsState() }
        if alpha < 1 { NSGraphicsContext.current?.cgContext.setAlpha(alpha) }

        if isFlat {
            if (isHovered || isPressed) && isEnabled {
                PixelPaint.stepped(bounds, corner: 1, fillColor)
            }
        } else {
            PixelPaint.bevel(bounds, fillColor, pressed: isPressed)
        }
        let content = bounds.offsetBy(dx: 0, dy: isPressed && !isFlat ? 1 : 0)
        switch (title, icon) {
        case let (title?, icon?):
            // 字在前、图标跟在后面（比如锁着的套装「程序员 🔒」）
            let iconWidth = PixelPaint.iconSize(icon).width
            let gap: CGFloat = 4
            let total = PixelPaint.textSize(title).width + gap + iconWidth
            let startX = (content.midX - total / 2).rounded()
            PixelPaint.text(title, in: NSRect(x: startX, y: content.minY, width: total, height: content.height), color: textColor)
            PixelPaint.draw(icon, centeredIn: NSRect(x: startX + total - iconWidth, y: content.minY, width: iconWidth, height: content.height))
        case let (nil, icon?):
            PixelPaint.draw(icon, centeredIn: content)
        case let (title?, nil):
            let inset = content.insetBy(dx: isFlat || textAlignment == 0 ? 8 : 4, dy: 0)
            PixelPaint.text(title, in: inset, color: textColor, align: textAlignment)
        case (nil, nil):
            break
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        if inside { sendAction(action, to: target) }
    }

    override func performClick(_ sender: Any?) {
        guard isEnabled else { return }
        sendAction(action, to: target)
    }

    override func accessibilityPerformPress() -> Bool {
        performClick(nil)
        return true
    }
}
