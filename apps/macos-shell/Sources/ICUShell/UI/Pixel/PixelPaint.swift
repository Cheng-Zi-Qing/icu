import AppKit

/// 在 flipped 视图里画像素风的板子、按钮、图标和字。一格像素 = `unit` pt。
enum PixelPaint {
    static let unit: CGFloat = 2

    static func fill(_ rect: NSRect, _ color: NSColor) {
        color.setFill()
        rect.fill(using: .sourceOver)
    }

    /// 阶梯圆角矩形：`corner` 是圆角占几格
    static func stepped(_ rect: NSRect, corner: Int, _ color: NSColor) {
        for k in 0...corner {
            let dx = CGFloat(k) * unit
            let dy = CGFloat(corner - k) * unit
            fill(NSRect(x: rect.minX + dx, y: rect.minY + dy, width: rect.width - 2 * dx, height: rect.height - 2 * dy), color)
        }
    }

    /// 描边的板子，可选往下的硬投影
    static func plate(_ rect: NSRect, _ background: NSColor, corner: Int = 2, shadow: Int = 0, line: NSColor = PixelPalette.outline) {
        if shadow > 0 {
            stepped(rect.offsetBy(dx: 0, dy: CGFloat(shadow) * unit), corner: corner, PixelPalette.shadow)
        }
        stepped(rect, corner: corner, line)
        stepped(rect.insetBy(dx: unit, dy: unit), corner: max(1, corner - 1), background)
    }

    /// 立体按钮：上沿一道高光、下沿一道暗边；按下时反过来
    static func bevel(_ rect: NSRect, _ background: NSColor, pressed: Bool = false) {
        plate(rect, background, corner: 1)
        let inner = rect.insetBy(dx: unit, dy: unit)
        let top = NSRect(x: inner.minX + unit, y: inner.minY, width: inner.width - 2 * unit, height: unit)
        let bottom = NSRect(x: inner.minX + unit, y: inner.maxY - unit, width: inner.width - 2 * unit, height: unit)
        fill(top, pressed ? PixelPalette.lowlight : PixelPalette.highlight)
        fill(bottom, pressed ? PixelPalette.highlight : PixelPalette.lowlight)
    }

    /// 点状分隔线
    static func dottedLine(from x0: CGFloat, to x1: CGFloat, y: CGFloat, _ color: NSColor = PixelPalette.paper3) {
        var x = x0
        while x < x1 {
            fill(NSRect(x: x, y: y, width: unit, height: unit), color)
            x += 2 * unit
        }
    }

    static func iconSize(_ icon: PixelIcon) -> NSSize {
        NSSize(width: CGFloat(icon.rows.first?.count ?? 0) * unit, height: CGFloat(icon.rows.count) * unit)
    }

    static func draw(_ icon: PixelIcon, at origin: NSPoint) {
        for (y, row) in icon.rows.enumerated() {
            for (x, character) in row.enumerated() {
                guard let color = PixelIcon.ink[character] else { continue }
                fill(NSRect(x: origin.x + CGFloat(x) * unit, y: origin.y + CGFloat(y) * unit, width: unit, height: unit), color)
            }
        }
    }

    static func draw(_ icon: PixelIcon, centeredIn rect: NSRect) {
        let size = iconSize(icon)
        let x = ((rect.midX - size.width / 2) / unit).rounded() * unit
        let y = ((rect.midY - size.height / 2) / unit).rounded() * unit
        draw(icon, at: NSPoint(x: x, y: y))
    }

    /// 像素图放大不糊：最近邻插值
    static func image(_ image: NSImage, in rect: NSRect) {
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSNumber(value: NSImageInterpolation.none.rawValue)])
    }

    static func textSize(_ text: String, font: NSFont = PixelFont.font()) -> NSSize {
        (text as NSString).size(withAttributes: [.font: font])
    }

    /// 在矩形里垂直居中画字；`align` 0 左、0.5 中、1 右。像素字关掉抗锯齿
    static func text(_ text: String, in rect: NSRect, color: NSColor = PixelPalette.outline, align: CGFloat = 0, font: NSFont = PixelFont.font()) {
        let size = textSize(text, font: font)
        let origin = NSPoint(x: (rect.minX + (rect.width - size.width) * align).rounded(), y: (rect.midY - size.height / 2).rounded())
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.shouldAntialias = !PixelFont.isAvailable
        (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: color])
        context.restoreGraphicsState()
    }

    /// 多行文字：从矩形左上角开始，按宽度自动换行
    static func wrappedText(_ text: String, in rect: NSRect, color: NSColor = PixelPalette.outline, font: NSFont = PixelFont.font()) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.lineBreakMode = .byWordWrapping
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.shouldAntialias = !PixelFont.isAvailable
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
        context.restoreGraphicsState()
    }
}
