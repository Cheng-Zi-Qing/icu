import AppKit

struct ThemedMenuPanelItem: Equatable {
    enum Tone: Equatable {
        case standard
        /// 最常用的那一项（开始工作 / 回来工作）：黄色立体按钮
        case primary
        case destructive
    }

    var id: String
    var title: String
    var tone: Tone = .standard
}

struct ThemedMenuPanelSection: Equatable {
    var items: [ThemedMenuPanelItem]
}

/// 像素风菜单：米色板子 + 一列按钮，分组之间是点状分隔线；可选顶上的今日小结
final class ThemedMenuPanel: NSView {
    private enum Layout {
        static let panelWidth: CGFloat = 200
        static let padding: CGFloat = 8
        static let rowHeight: CGFloat = 28
        static let separatorHeight: CGFloat = 10
        static let shadow = 2
    }

    private let sections: [ThemedMenuPanelSection]
    private let summary: MenuTodaySummary?
    private let onSelect: (String) -> Void

    override var isFlipped: Bool { true }

    init(
        sections: [ThemedMenuPanelSection],
        summary: MenuTodaySummary? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.sections = sections
        self.summary = summary
        self.onSelect = onSelect
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize(for: sections, hasSummary: summary != nil)))
        buildRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func preferredSize(for sections: [ThemedMenuPanelSection], hasSummary: Bool = false) -> NSSize {
        let rows = sections.reduce(0) { $0 + $1.items.count }
        let separators = max(sections.count - 1, 0) + (hasSummary ? 1 : 0)
        let header = hasSummary ? MenuTodayHeaderView.height : 0
        let height = 2 * Layout.padding + header + CGFloat(rows) * Layout.rowHeight
            + CGFloat(separators) * Layout.separatorHeight + CGFloat(Layout.shadow) * PixelPaint.unit
        return NSSize(width: Layout.panelWidth, height: height)
    }

    private var innerWidth: CGFloat {
        Layout.panelWidth - 2 * Layout.padding
    }

    private func buildRows() {
        var y = Layout.padding
        if let summary {
            let header = MenuTodayHeaderView(summary: summary)
            header.frame = NSRect(x: Layout.padding, y: y, width: innerWidth, height: MenuTodayHeaderView.height)
            addSubview(header)
            y += MenuTodayHeaderView.height
            y = addSeparator(at: y)
        }
        for (index, section) in sections.enumerated() {
            for item in section.items {
                let row = makeRow(item)
                row.frame = NSRect(x: Layout.padding, y: y, width: innerWidth, height: Layout.rowHeight - 2)
                addSubview(row)
                y += Layout.rowHeight
            }
            if index < sections.count - 1 {
                y = addSeparator(at: y)
            }
        }
    }

    private func makeRow(_ item: ThemedMenuPanelItem) -> PixelButton {
        let row = PixelButton(title: item.title, identifier: item.id)
        row.textAlignment = 0
        row.target = self
        row.action = #selector(handleSelect(_:))
        switch item.tone {
        case .primary:
            row.fillColor = PixelPalette.yellow
        case .standard:
            row.isFlat = true
        case .destructive:
            row.isFlat = true
            row.textColor = PixelPalette.danger
        }
        if row.isFlat { row.fillColor = PixelPalette.paper2 }
        return row
    }

    private func addSeparator(at y: CGFloat) -> CGFloat {
        let separator = DottedSeparator(frame: NSRect(x: Layout.padding, y: y, width: innerWidth, height: Layout.separatorHeight))
        separator.identifier = NSUserInterfaceItemIdentifier("menu-separator")
        addSubview(separator)
        return y + Layout.separatorHeight
    }

    override func draw(_ dirtyRect: NSRect) {
        let panel = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - CGFloat(Layout.shadow) * PixelPaint.unit)
        PixelPaint.plate(panel, PixelPalette.paper, shadow: Layout.shadow)
    }

    @objc private func handleSelect(_ sender: PixelButton) {
        guard let id = sender.identifier?.rawValue else { return }
        onSelect(id)
    }
}

private final class DottedSeparator: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let y = (bounds.midY / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        PixelPaint.dottedLine(from: 4, to: bounds.width - 4, y: y)
    }
}
