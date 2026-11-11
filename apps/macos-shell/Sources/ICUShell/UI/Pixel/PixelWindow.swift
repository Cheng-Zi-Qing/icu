import AppKit

/// 无边框、透明底的窗口：像素边框全部自己画；可以成为 key window，Esc 关闭。设置、衣柜共用
final class PixelWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    convenience init(size: NSSize, title: String, content: NSView) {
        self.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        self.title = title
        contentView = content
    }

    override func cancelOperation(_ sender: Any?) {
        performClose(sender)
    }

    override func performClose(_ sender: Any?) {
        if delegate?.windowShouldClose?(self) ?? true {
            close()
        }
    }

    /// 第一次打开时居中；再次打开时留在原地，并把 app 提到前面
    func present() {
        if !isVisible { center() }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }
}

/// 像素窗口的外框：纸色面板 + 棕色标题栏 + 标题栏上趴着的水豚（`ui/bar_peek.png`，爪子压住标题栏上沿）。
/// 视图坐标要是翻转的（y 向下），最上面 `decorationHeight` 是给水豚脑袋留的透明区域
enum PixelPanelChrome {
    static let decorationHeight: CGFloat = 54
    static let titleHeight: CGFloat = 32
    static let shadow = 2
    static let decorationScale: CGFloat = 3

    static func titleBarRect(in bounds: NSRect) -> NSRect {
        NSRect(x: 0, y: decorationHeight, width: bounds.width, height: titleHeight)
    }

    static func panelRect(in bounds: NSRect) -> NSRect {
        NSRect(x: 0, y: decorationHeight, width: bounds.width, height: bounds.height - decorationHeight - CGFloat(shadow) * PixelPaint.unit)
    }

    /// 关闭按钮放在标题栏左边
    static func closeButtonFrame() -> NSRect {
        NSRect(x: 8, y: decorationHeight + 7, width: 18, height: 18)
    }

    static func makeCloseButton(identifier: String) -> PixelButton {
        let button = PixelButton(icon: .crossWhite, identifier: identifier)
        button.frame = closeButtonFrame()
        button.fillColor = PixelPalette.blush
        button.setAccessibilityLabel(TextCatalog.shared.text("common.close"))
        return button
    }

    static func draw(in bounds: NSRect, title: String, decoration: NSImage?) {
        let unit = PixelPaint.unit
        PixelPaint.plate(panelRect(in: bounds), PixelPalette.paper, shadow: shadow)
        let bar = titleBarRect(in: bounds)
        // 标题栏：棕色，跟水豚一个颜色；下面一道描边
        PixelPaint.stepped(NSRect(x: bar.minX + unit, y: bar.minY + unit, width: bar.width - 2 * unit, height: bar.height - unit), corner: 1, PixelPalette.body)
        PixelPaint.fill(NSRect(x: bar.minX + unit, y: bar.maxY - unit, width: bar.width - 2 * unit, height: unit), PixelPalette.outline)
        PixelPaint.fill(NSRect(x: bar.minX + 2 * unit, y: bar.minY + 2 * unit, width: bar.width - 4 * unit, height: unit), PixelPalette.highlight)
        PixelPaint.text(title, in: bar.offsetBy(dx: 0, dy: 1), color: PixelPalette.paper, align: 0.5)
        guard let decoration else { return }
        let side = 32 * decorationScale
        let rect = NSRect(x: bounds.width - 40 - side, y: decorationHeight + 6 - side, width: side, height: side)
        PixelPaint.image(decoration, in: rect)
    }

    /// 拖标题栏移动窗口
    static func handleMouseDown(_ event: NSEvent, in view: NSView) {
        let point = view.convert(event.locationInWindow, from: nil)
        if titleBarRect(in: view.bounds).contains(point) {
            view.window?.performDrag(with: event)
        }
    }

    /// 透明的上沿（水豚以外）不接鼠标，点下去落到后面的窗口
    static func passesThrough(_ point: NSPoint, in view: NSView) -> Bool {
        view.convert(point, from: view.superview).y < decorationHeight
    }
}
