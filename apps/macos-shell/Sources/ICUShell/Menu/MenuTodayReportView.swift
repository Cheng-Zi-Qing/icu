import AppKit

/// 「今日报告」浮层，从上到下：评分和一句总评 → 喝水 / 护眼 / 工时的进度条 → 明细 →
/// 本周每天的上班时长 → 建议和做得好的地方 → 本机累计
final class MenuTodayReportView: NSView {
    private enum Layout {
        static let panelWidth: CGFloat = 300
        static let padding: CGFloat = 10
        static let titleHeight: CGFloat = 20
        static let scoreHeight: CGFloat = 52
        static let scoreGap: CGFloat = 6
        static let scorePointsWidth: CGFloat = 92
        static let separatorHeight: CGFloat = 10
        static let rowHeight: CGFloat = 22
        static let sectionTitleHeight: CGFloat = 20
        static let adviceHeight: CGFloat = 24
        static let shadow = 2
        /// 图标列：按最宽的图标（护眼）留宽，图标在这一列里居中
        static let iconColumnWidth: CGFloat = 22
        static let iconGap: CGFloat = 4
        /// 标签列：中文都是两个字（像素字下一个字 12pt），英文按实际长度放宽
        static let minLabelColumnWidth: CGFloat = 24
        static let valueGap: CGFloat = 8
        static let meterHeight: CGFloat = 10
        static let meterSegmentGap: CGFloat = 2
        static let meterValueWidth: CGFloat = 84
        static let weekBarUnit: CGFloat = 4
        static let weekBarWidth: CGFloat = 16
        static let weekLabelHeight: CGFloat = 16
        static let weekHeight = CGFloat(TodayReportWeek.maxLevel) * weekBarUnit + weekLabelHeight + 4

        static var labelX: CGFloat { padding + iconColumnWidth + iconGap }
        static var innerWidth: CGFloat { panelWidth - 2 * padding }
    }

    let content: TodayReportContent

    private var labelColumnWidth: CGFloat {
        let labels = content.detailRows.map(\.label) + content.meters.map(\.label)
        let widest = labels.map { PixelPaint.textSize($0).width }.max() ?? 0
        return max(Layout.minLabelColumnWidth, widest.rounded(.up))
    }

    private var valueX: CGFloat { Layout.labelX + labelColumnWidth + Layout.valueGap }

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
        let head = Layout.titleHeight + Layout.scoreHeight + Layout.scoreGap
        let meters = CGFloat(content.meters.count) * Layout.rowHeight
        let details = content.detailRows.isEmpty ? 0 : Layout.separatorHeight + CGFloat(content.detailRows.count) * Layout.rowHeight
        let week = content.week == nil ? 0 : Layout.separatorHeight + Layout.sectionTitleHeight + Layout.weekHeight
            + (content.week?.comparison == nil ? 0 : Layout.rowHeight)
        let advice = Layout.separatorHeight + adviceBlockHeight(content.advice) + adviceBlockHeight(content.praise)
        let footer = content.footer == nil ? 0 : Layout.separatorHeight + Layout.rowHeight
        let height = 2 * Layout.padding + head + meters + details + week + advice + footer + CGFloat(Layout.shadow) * PixelPaint.unit
        return NSSize(width: Layout.panelWidth, height: height)
    }

    private static func adviceBlockHeight(_ advice: [TodayAdvice]) -> CGFloat {
        advice.isEmpty ? 0 : Layout.sectionTitleHeight + CGFloat(advice.count) * Layout.adviceHeight
    }

    override func draw(_ dirtyRect: NSRect) {
        PixelPaint.plate(
            NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - CGFloat(Layout.shadow) * PixelPaint.unit),
            PixelPalette.paper,
            shadow: Layout.shadow
        )
        PixelPaint.text(
            TextCatalog.shared.text("report.title"),
            in: NSRect(x: Layout.padding, y: Layout.padding, width: Layout.innerWidth, height: Layout.titleHeight),
            color: PixelPalette.shade
        )

        var y = Layout.padding + Layout.titleHeight
        drawScore(at: y)
        y += Layout.scoreHeight + Layout.scoreGap
        for meter in content.meters {
            drawMeter(meter, at: y)
            y += Layout.rowHeight
        }
        if !content.detailRows.isEmpty {
            y = drawSeparator(at: y)
            for row in content.detailRows {
                drawRow(row, at: y)
                y += Layout.rowHeight
            }
        }
        if let week = content.week {
            y = drawWeek(week, at: drawSeparator(at: y))
        }
        y = drawSeparator(at: y)
        y = drawAdviceBlock(content.advice, title: adviceTitle, at: y)
        y = drawAdviceBlock(content.praise, title: TextCatalog.shared.text("report.section_praise"), at: y)
        if let footer = content.footer {
            y = drawSeparator(at: y)
            PixelPaint.text(footer, in: NSRect(x: Layout.padding, y: y, width: Layout.innerWidth, height: Layout.rowHeight), color: PixelPalette.shade)
        }
    }

    /// 第一栏结论的小标题：有该做的事叫「建议」，全是夸奖就叫「做得好」
    private var adviceTitle: String {
        TextCatalog.shared.text(content.advice.contains { $0.tone == .act } ? "report.section_advice" : "report.section_praise")
    }

    // MARK: - 评分

    /// 左边大字分数，右边一句状态和一行说明；底色跟着状态走
    private func drawScore(at y: CGFloat) {
        let score = content.score
        let rect = NSRect(x: Layout.padding, y: y, width: Layout.innerWidth, height: Layout.scoreHeight)
        PixelPaint.plate(rect, Self.background(for: score.grade), corner: 2)
        let textX: CGFloat
        if let points = score.pointsText {
            PixelPaint.text(
                points,
                in: NSRect(x: rect.minX, y: rect.minY, width: Layout.scorePointsWidth, height: rect.height),
                align: 0.5, font: PixelFont.font(scale: 2)
            )
            textX = rect.minX + Layout.scorePointsWidth
        } else {
            PixelPaint.draw(.clock, centeredIn: NSRect(x: rect.minX, y: rect.minY, width: 36, height: rect.height))
            textX = rect.minX + 36
        }
        let textWidth = rect.maxX - textX - 6
        PixelPaint.text(score.title, in: NSRect(x: textX, y: rect.minY + 6, width: textWidth, height: 20))
        PixelPaint.text(score.caption, in: NSRect(x: textX, y: rect.minY + 26, width: textWidth, height: 20), color: PixelPalette.shade)
    }

    private static func background(for grade: TodayScore.Grade) -> NSColor {
        switch grade {
        case .great, .good: return PixelPalette.summaryBackground
        case .okay: return PixelPalette.wornCell
        case .tired: return PixelPalette.reportTired
        case .warmingUp: return PixelPalette.paper2
        }
    }

    // MARK: - 进度条和明细

    private func drawMeter(_ meter: TodayReportMeter, at y: CGFloat) {
        PixelPaint.draw(Self.icon(for: meter.kind), centeredIn: NSRect(x: Layout.padding, y: y, width: Layout.iconColumnWidth, height: Layout.rowHeight))
        PixelPaint.text(meter.label, in: NSRect(x: Layout.labelX, y: y, width: labelColumnWidth + 2, height: Layout.rowHeight))
        let valueRect = NSRect(
            x: bounds.width - Layout.padding - Layout.meterValueWidth, y: y, width: Layout.meterValueWidth, height: Layout.rowHeight
        )
        PixelPaint.text(meter.value, in: valueRect, align: 1)

        let barX = valueX
        let barWidth = valueRect.minX - Layout.valueGap - barX
        let count = TodayReportMeter.segments
        let segment = ((barWidth - Layout.meterSegmentGap * CGFloat(count - 1)) / CGFloat(count) / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        let barY = ((y + (Layout.rowHeight - Layout.meterHeight) / 2) / PixelPaint.unit).rounded() * PixelPaint.unit
        let lit = meter.isOver ? PixelPalette.danger : Self.color(for: meter.kind)
        for index in 0..<count {
            let x = barX + CGFloat(index) * (segment + Layout.meterSegmentGap)
            PixelPaint.fill(NSRect(x: x, y: barY, width: segment, height: Layout.meterHeight), index < meter.filled ? lit : PixelPalette.paper3)
        }
    }

    private func drawRow(_ row: TodayReportContent.Row, at y: CGFloat) {
        if let icon = Self.icon(for: row.kind) {
            PixelPaint.draw(icon, centeredIn: NSRect(x: Layout.padding, y: y, width: Layout.iconColumnWidth, height: Layout.rowHeight))
        }
        PixelPaint.text(row.label, in: NSRect(x: Layout.labelX, y: y, width: labelColumnWidth + 2, height: Layout.rowHeight))
        PixelPaint.text(row.value, in: NSRect(x: valueX, y: y, width: bounds.width - Layout.padding - valueX, height: Layout.rowHeight))
    }

    // MARK: - 本周

    /// 小标题 + 右边的日均；下面一天一根柱子，今天那根用黄色；再下面一行今天和日均的比较。返回下面内容的起点
    private func drawWeek(_ week: TodayReportWeek, at top: CGFloat) -> CGFloat {
        let header = NSRect(x: Layout.padding, y: top, width: Layout.innerWidth, height: Layout.sectionTitleHeight)
        PixelPaint.text(TextCatalog.shared.text("report.section_week"), in: header, color: PixelPalette.shade)
        PixelPaint.text(week.caption, in: header, color: PixelPalette.shade, align: 1)

        let chartTop = top + Layout.sectionTitleHeight
        let baseline = chartTop + CGFloat(TodayReportWeek.maxLevel) * Layout.weekBarUnit + 2
        let slot = Layout.innerWidth / CGFloat(max(1, week.bars.count))
        for (index, bar) in week.bars.enumerated() {
            let x = ((Layout.padding + slot * (CGFloat(index) + 0.5) - Layout.weekBarWidth / 2) / PixelPaint.unit).rounded() * PixelPaint.unit
            let height = CGFloat(bar.level) * Layout.weekBarUnit
            let color = bar.isToday ? PixelPalette.yellow : PixelPalette.body
            if bar.level > 0 {
                PixelPaint.fill(NSRect(x: x, y: baseline - height, width: Layout.weekBarWidth, height: height), color)
            } else {
                PixelPaint.fill(NSRect(x: x, y: baseline - PixelPaint.unit, width: Layout.weekBarWidth, height: PixelPaint.unit), PixelPalette.paper3)
            }
            PixelPaint.text(
                bar.label,
                in: NSRect(x: x - 8, y: baseline, width: Layout.weekBarWidth + 16, height: Layout.weekLabelHeight),
                color: bar.isToday ? PixelPalette.outline : PixelPalette.shade,
                align: 0.5
            )
        }
        var y = top + Layout.sectionTitleHeight + Layout.weekHeight
        if let comparison = week.comparison {
            PixelPaint.text(comparison, in: NSRect(x: Layout.padding, y: y, width: Layout.innerWidth, height: Layout.rowHeight))
            y += Layout.rowHeight
        }
        return y
    }

    // MARK: - 建议

    /// 一栏结论：小标题 + 一句一块底色（该做的铺浅黄，做得好的铺浅绿）。空的不画；返回下面内容的起点
    private func drawAdviceBlock(_ advice: [TodayAdvice], title: String, at top: CGFloat) -> CGFloat {
        guard !advice.isEmpty else { return top }
        PixelPaint.text(
            title,
            in: NSRect(x: Layout.padding, y: top, width: Layout.innerWidth, height: Layout.sectionTitleHeight),
            color: PixelPalette.shade
        )
        var y = top + Layout.sectionTitleHeight
        for item in advice {
            let rect = NSRect(x: Layout.padding, y: y, width: Layout.innerWidth, height: Layout.adviceHeight - 2)
            PixelPaint.stepped(rect, corner: 1, item.tone == .act ? PixelPalette.wornCell : PixelPalette.summaryBackground)
            PixelPaint.draw(Self.icon(for: item.topic), centeredIn: NSRect(x: rect.minX, y: rect.minY, width: Layout.iconColumnWidth, height: rect.height))
            PixelPaint.text(item.text, in: NSRect(x: Layout.labelX, y: rect.minY, width: rect.maxX - Layout.labelX, height: rect.height))
            y += Layout.adviceHeight
        }
        return y
    }

    /// 点状线落在整格上，不然会画出半个像素点；返回线下面内容的起点
    private func drawSeparator(at top: CGFloat) -> CGFloat {
        let lineY = ((top + Layout.separatorHeight / 2) / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        PixelPaint.dottedLine(from: Layout.padding + 4, to: bounds.width - Layout.padding - 4, y: lineY)
        return top + Layout.separatorHeight
    }

    // MARK: - 图标和颜色

    private static func icon(for topic: TodayAdvice.Topic) -> PixelIcon {
        switch topic {
        case .water: return .drop
        case .eyes: return .eye
        case .rest, .overtime: return .clock
        case .snoozing: return .bell
        case .allGood: return .check
        }
    }

    private static func icon(for kind: TodayReportMeter.Kind) -> PixelIcon {
        switch kind {
        case .water: return .drop
        case .eyes: return .eye
        case .hours: return .clock
        }
    }

    private static func color(for kind: TodayReportMeter.Kind) -> NSColor {
        switch kind {
        case .water: return PixelPalette.water
        case .eyes: return PixelPalette.grass
        case .hours: return PixelPalette.yellow
        }
    }

    private static func icon(for kind: TodayReportContent.RowKind) -> PixelIcon? {
        switch kind {
        case .onDuty: return .clock
        case .eyes: return .eye
        case .water: return .drop
        case .span, .shift, .focus, .rest: return nil
        }
    }
}
