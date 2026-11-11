import AppKit

/// 菜单顶上的今日小结：「今天」+ 喝水 / 护眼 / 工作时长
final class MenuTodayHeaderView: NSView {
    static let height: CGFloat = 56

    private let summary: MenuTodaySummary

    override var isFlipped: Bool { true }

    init(summary: MenuTodaySummary) {
        self.summary = summary
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("menu-today")
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(TextCatalog.shared.format("menu.today_accessibility", summary.cupsText, summary.eyeText, summary.workText))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        PixelPaint.text(TextCatalog.shared.text("menu.today"), in: NSRect(x: 8, y: 4, width: bounds.width - 16, height: 20), color: PixelPalette.shade)
        let items: [(PixelIcon, String)] = [(.drop, summary.cupsText), (.eye, summary.eyeText), (.clock, summary.workText)]
        var x: CGFloat = 8
        let row = NSRect(x: 0, y: 28, width: bounds.width, height: 22)
        for (icon, text) in items {
            let iconWidth = PixelPaint.iconSize(icon).width
            PixelPaint.draw(icon, centeredIn: NSRect(x: x, y: row.minY, width: iconWidth, height: row.height))
            x += iconWidth + 4
            let width = PixelPaint.textSize(text).width
            PixelPaint.text(text, in: NSRect(x: x, y: row.minY, width: width + 2, height: row.height))
            x += width + 12
        }
    }
}
