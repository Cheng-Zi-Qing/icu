import AppKit

/// 「今日报告」浮层：今天工作 / 专注 / 休息 / 护眼 / 喝水，一行一项
final class MenuTodayReportView: NSView {
    private enum Layout {
        static let panelWidth: CGFloat = 200
        static let padding: CGFloat = 8
        static let titleHeight: CGFloat = 20
        static let separatorHeight: CGFloat = 10
        static let rowHeight: CGFloat = 22
        static let shadow = 2
        /// 图标列：按最宽的图标（护眼）留宽，图标在这一列里居中
        static let iconColumnWidth: CGFloat = 22
        static let iconGap: CGFloat = 4
        /// 标签都是两个字，像素字下一个字 12pt，整列 24
        static let labelColumnWidth: CGFloat = 24
        static let valueGap: CGFloat = 8

        static var labelX: CGFloat { padding + iconColumnWidth + iconGap }
        static var valueX: CGFloat { labelX + labelColumnWidth + valueGap }
        /// 数值最多能占多宽：撑到这里就打住，面板不放宽
        static var valueWidth: CGFloat { panelWidth - padding - valueX }
    }

    private struct Row {
        let icon: PixelIcon?
        let label: String
        let value: String
    }

    private let rows: [Row]

    override var isFlipped: Bool { true }

    init(report: HealthDaySummary, cupsGoal: Int) {
        let goal = max(0, cupsGoal)
        rows = Self.rows(for: report, cupsGoal: goal)
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize(rowCount: rows.count)))
        identifier = NSUserInterfaceItemIdentifier("menu-today-report")
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("今日报告：" + rows.map { "\($0.label) \($0.value)" }.joined(separator: "，"))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func preferredSize(for report: HealthDaySummary, cupsGoal: Int) -> NSSize {
        preferredSize(rowCount: rows(for: report, cupsGoal: max(0, cupsGoal)).count)
    }

    private static func preferredSize(rowCount: Int) -> NSSize {
        NSSize(
            width: Layout.panelWidth,
            height: 2 * Layout.padding + Layout.titleHeight + Layout.separatorHeight
                + CGFloat(rowCount) * Layout.rowHeight + CGFloat(Layout.shadow) * PixelPaint.unit
        )
    }

    /// 没数据的行不画：只有喝水一项永远在（目标杯数是定的）
    private static func rows(for report: HealthDaySummary, cupsGoal: Int) -> [Row] {
        var rows: [Row] = [Row(icon: .clock, label: "工作", value: workText(report.workDuration))]

        if report.focusCount > 0 || report.focusDuration > 0 {
            rows.append(Row(icon: nil, label: "专注", value: "\(report.focusCount) 次 · \(workText(report.focusDuration))"))
        }
        if report.breakCount > 0 {
            rows.append(Row(icon: nil, label: "休息", value: "\(report.breakCount) 次"))
        }
        if report.eyeReminder.shown > 0 {
            let eye = report.eyeReminder
            rows.append(Row(icon: .eye, label: "护眼", value: countsText(completed: eye.completed, shown: eye.shown, unit: "次", completionRate: eye.completionRate)))
        }
        let cups = report.hydrationReminder.completed
        rows.append(Row(icon: .drop, label: "喝水", value: countsText(completed: cups, shown: cupsGoal, unit: "杯")))
        return rows
    }

    /// 「3:20」= 3 小时 20 分，跟菜单顶上的今日小结一个格式
    private static func workText(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// 「4/5 次」后面放得下完成率就带上，放不下就只留数字
    private static func countsText(completed: Int, shown: Int, unit: String, completionRate: Double? = nil) -> String {
        let numbers = "\(completed)/\(shown) \(unit)"
        guard let completionRate else { return numbers }
        let percent = "\(Int((completionRate * 100).rounded()))%"
        guard PixelPaint.textSize("\(numbers) \(percent)").width <= Layout.valueWidth else { return numbers }
        return "\(numbers) \(percent)"
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

        let separatorTop = Layout.padding + Layout.titleHeight
        // 点状线落在整格上，不然会画出半个像素点
        let separatorY = ((separatorTop + Layout.separatorHeight / 2) / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        PixelPaint.dottedLine(from: Layout.padding + 4, to: bounds.width - Layout.padding - 4, y: separatorY)

        var y = separatorTop + Layout.separatorHeight
        let row = NSRect(x: 0, y: 0, width: bounds.width, height: Layout.rowHeight)
        for item in rows {
            if let icon = item.icon {
                PixelPaint.draw(icon, centeredIn: NSRect(x: Layout.padding, y: y, width: Layout.iconColumnWidth, height: row.height))
            }
            PixelPaint.text(item.label, in: NSRect(x: Layout.labelX, y: y, width: Layout.labelColumnWidth + 2, height: row.height))
            PixelPaint.text(item.value, in: NSRect(x: Layout.valueX, y: y, width: Layout.valueWidth, height: row.height))
            y += row.height
        }
    }
}
