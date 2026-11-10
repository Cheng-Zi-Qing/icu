import AppKit

/// 「今日报告」浮层：顶上一两句结论（该补水了 / 眼睛该放松了），下面一行一项的数，底下本机累计
final class MenuTodayReportView: NSView {
    private enum Layout {
        static let panelWidth: CGFloat = 232
        static let padding: CGFloat = 8
        static let titleHeight: CGFloat = 20
        static let separatorHeight: CGFloat = 10
        static let rowHeight: CGFloat = 22
        static let adviceHeight: CGFloat = 24
        static let adviceGap: CGFloat = 4
        static let shadow = 2
        /// 图标列：按最宽的图标（护眼）留宽，图标在这一列里居中
        static let iconColumnWidth: CGFloat = 22
        static let iconGap: CGFloat = 4
        /// 标签都是两个字，像素字下一个字 12pt，整列 24
        static let labelColumnWidth: CGFloat = 24
        static let valueGap: CGFloat = 8

        static var labelX: CGFloat { padding + iconColumnWidth + iconGap }
        static var valueX: CGFloat { labelX + labelColumnWidth + valueGap }
        static var valueWidth: CGFloat { panelWidth - padding - valueX }
    }

    let content: TodayReportContent

    override var isFlipped: Bool { true }

    init(content: TodayReportContent) {
        self.content = content
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize(for: content)))
        identifier = NSUserInterfaceItemIdentifier("menu-today-report")
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel(content.accessibilityText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func preferredSize(for content: TodayReportContent) -> NSSize {
        let adviceBlock = CGFloat(content.advice.count) * Layout.adviceHeight + Layout.adviceGap
        let footer = content.footer == nil ? 0 : Layout.separatorHeight + Layout.rowHeight
        let height = 2 * Layout.padding + Layout.titleHeight + adviceBlock + Layout.separatorHeight
            + CGFloat(content.rows.count) * Layout.rowHeight + footer + CGFloat(Layout.shadow) * PixelPaint.unit
        return NSSize(width: Layout.panelWidth, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        PixelPaint.plate(
            NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - CGFloat(Layout.shadow) * PixelPaint.unit),
            PixelPalette.paper,
            shadow: Layout.shadow
        )

        let innerWidth = bounds.width - 2 * Layout.padding
        PixelPaint.text(
            "今日报告",
            in: NSRect(x: Layout.padding, y: Layout.padding, width: innerWidth, height: Layout.titleHeight),
            color: PixelPalette.shade
        )

        var y = Layout.padding + Layout.titleHeight
        for advice in content.advice {
            drawAdvice(advice, in: NSRect(x: Layout.padding, y: y, width: innerWidth, height: Layout.adviceHeight - 2))
            y += Layout.adviceHeight
        }
        y += Layout.adviceGap

        y = drawSeparator(at: y)
        for row in content.rows {
            drawRow(row, at: y)
            y += Layout.rowHeight
        }

        if let footer = content.footer {
            y = drawSeparator(at: y)
            PixelPaint.text(footer, in: NSRect(x: Layout.padding, y: y, width: innerWidth, height: Layout.rowHeight), color: PixelPalette.shade)
        }
    }

    /// 结论一句一块底色：该做的铺浅黄，做得好的铺浅绿
    private func drawAdvice(_ advice: TodayAdvice, in rect: NSRect) {
        let background = advice.tone == .act ? PixelPalette.wornCell : PixelPalette.summaryBackground
        PixelPaint.stepped(rect, corner: 1, background)
        PixelPaint.draw(Self.icon(for: advice.topic), centeredIn: NSRect(x: rect.minX, y: rect.minY, width: Layout.iconColumnWidth, height: rect.height))
        PixelPaint.text(advice.text, in: NSRect(x: Layout.labelX, y: rect.minY, width: rect.maxX - Layout.labelX, height: rect.height))
    }

    private func drawRow(_ row: TodayReportContent.Row, at y: CGFloat) {
        if let icon = Self.icon(for: row.kind) {
            PixelPaint.draw(icon, centeredIn: NSRect(x: Layout.padding, y: y, width: Layout.iconColumnWidth, height: Layout.rowHeight))
        }
        PixelPaint.text(row.label, in: NSRect(x: Layout.labelX, y: y, width: Layout.labelColumnWidth + 2, height: Layout.rowHeight))
        PixelPaint.text(row.value, in: NSRect(x: Layout.valueX, y: y, width: Layout.valueWidth, height: Layout.rowHeight))
    }

    /// 点状线落在整格上，不然会画出半个像素点；返回线下面内容的起点
    private func drawSeparator(at top: CGFloat) -> CGFloat {
        let lineY = ((top + Layout.separatorHeight / 2) / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        PixelPaint.dottedLine(from: Layout.padding + 4, to: bounds.width - Layout.padding - 4, y: lineY)
        return top + Layout.separatorHeight
    }

    private static func icon(for topic: TodayAdvice.Topic) -> PixelIcon {
        switch topic {
        case .water: return .drop
        case .eyes: return .eye
        case .rest, .overtime: return .clock
        case .allGood: return .check
        }
    }

    private static func icon(for kind: TodayReportContent.RowKind) -> PixelIcon? {
        switch kind {
        case .onDuty: return .clock
        case .eyes: return .eye
        case .water: return .drop
        case .span, .focus, .rest: return nil
        }
    }
}
