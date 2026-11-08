import AppKit

/// 衣柜里的一格：穿着的铺浅黄、右上角打勾；有的是白底；没拿到的是问号剪影，不写是什么
final class WardrobeItemCell: NSControl {
    enum Look: Equatable {
        case equipped
        case owned
        case locked
    }

    static let size = NSSize(width: 80, height: 76)
    static let lockedHint = "完成任务掉落"
    static let lockedAccessibilityLabel = "还没拿到，完成提醒有机会掉落"
    private static let iconScale: CGFloat = 3

    let itemID: String
    private let name: String
    private let icon: NSImage?
    private var isHovered = false { didSet { needsDisplay = true } }
    private var trackingAreaRef: NSTrackingArea?

    var look: Look {
        didSet { refreshState() }
    }

    override var isFlipped: Bool { true }

    init(item: WardrobeItem, icon: NSImage?, look: Look) {
        itemID = item.id
        name = item.name
        self.icon = icon
        self.look = look
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        identifier = NSUserInterfaceItemIdentifier("wardrobe.item.\(item.id)")
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        refreshState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let box = bounds
        switch look {
        case .equipped:
            PixelPaint.plate(box, PixelPalette.wornCell, line: PixelPalette.yellow)
            PixelPaint.stepped(box.insetBy(dx: PixelPaint.unit, dy: PixelPaint.unit), corner: 1, PixelPalette.yellow)
            PixelPaint.stepped(box.insetBy(dx: 2 * PixelPaint.unit, dy: 2 * PixelPaint.unit), corner: 1, PixelPalette.wornCell)
            drawItem()
            drawTick()
        case .owned:
            PixelPaint.plate(box, isHovered ? PixelPalette.paper : PixelPalette.white)
            drawItem()
        case .locked:
            PixelPaint.plate(box, PixelPalette.paper3, line: PixelPalette.shade)
            PixelPaint.draw(.question, centeredIn: NSRect(x: 0, y: 12, width: box.width, height: 30))
            PixelPaint.text(Self.lockedHint, in: NSRect(x: 0, y: box.height - 26, width: box.width, height: 18), color: PixelPalette.shade, align: 0.5)
        }
    }

    private func drawItem() {
        if let icon {
            let side = 16 * Self.iconScale
            PixelPaint.image(icon, in: NSRect(x: (bounds.width - side) / 2, y: 4, width: side, height: side))
        }
        PixelPaint.text(name, in: NSRect(x: 0, y: bounds.height - 26, width: bounds.width, height: 18), align: 0.5)
    }

    /// 右上角的绿底小勾
    private func drawTick() {
        let badge = NSRect(x: bounds.width - 22, y: 6, width: 16, height: 14)
        PixelPaint.plate(badge, PixelPalette.grass, corner: 1)
        PixelPaint.draw(.check, centeredIn: badge)
    }

    private func refreshState() {
        isEnabled = look != .locked
        setAccessibilityLabel(look == .locked ? Self.lockedAccessibilityLabel : name)
        setAccessibilityValue(look == .equipped ? "穿着" : nil)
        toolTip = look == .locked ? Self.lockedAccessibilityLabel : nil
        needsDisplay = true
    }

    // MARK: - 点击

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = isEnabled }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        sendAction(action, to: target)
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
