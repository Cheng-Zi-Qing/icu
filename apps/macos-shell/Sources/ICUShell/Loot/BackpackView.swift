import AppKit

/// 像素风背包：上面一排孵化位（宝箱、进度条、还要几分钟），下面是图鉴——
/// 全部材料按档次分组，拿到过的显示名字和数量，没拿到过的是「？？？」
final class BackpackView: NSView {
    enum Layout {
        static let width: CGFloat = 480
        static let padding: CGFloat = 16
        static let rowHeight: CGFloat = 20
        static let slotHeight: CGFloat = 60
        static let slotGap: CGFloat = 8
        static let columns = 3
        static let cellHeight: CGFloat = 24
        static let cellGap: CGFloat = 6
        static let groupLabelHeight: CGFloat = 20
        static let sectionGap: CGFloat = 12
    }

    let closeButton = PixelPanelChrome.makeCloseButton(identifier: "backpack.close")
    private(set) var content: BackpackContent
    /// 标题栏上趴着的那只（跟着现在的装扮）
    var decoration: NSImage? { didSet { needsDisplay = true } }
    private var copyObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }

    init(content: BackpackContent, decoration: NSImage? = nil) {
        self.content = content
        self.decoration = decoration
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize(for: content)))
        addSubview(closeButton)
        copyObserver = NotificationCenter.default.addObserver(forName: .icuCopyDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.needsDisplay = true
        }
    }

    deinit {
        copyObserver.map(NotificationCenter.default.removeObserver)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(content next: BackpackContent) {
        content = next
        needsDisplay = true
    }

    // MARK: - 尺寸

    private static var bodyTop: CGFloat { PixelPanelChrome.decorationHeight + PixelPanelChrome.titleHeight + Layout.padding }
    private static var innerWidth: CGFloat { Layout.width - 2 * Layout.padding }

    private static func rows(_ group: BackpackContent.Group) -> Int {
        (group.entries.count + Layout.columns - 1) / Layout.columns
    }

    private static func groupHeight(_ group: BackpackContent.Group) -> CGFloat {
        let rows = CGFloat(rows(group))
        return Layout.groupLabelHeight + rows * Layout.cellHeight + max(0, rows - 1) * Layout.cellGap + 6
    }

    private static var codexTop: CGFloat {
        bodyTop + Layout.rowHeight + 6 + Layout.slotHeight + Layout.sectionGap
    }

    static func preferredSize(for content: BackpackContent) -> NSSize {
        let groups = content.groups.reduce(0) { $0 + groupHeight($1) }
        let height = codexTop + Layout.rowHeight + 6 + groups + Layout.rowHeight + Layout.padding
            + CGFloat(PixelPanelChrome.shadow) * PixelPaint.unit
        return NSSize(width: Layout.width, height: height)
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        let catalog = TextCatalog.shared
        PixelPanelChrome.draw(in: bounds, title: catalog.text("loot.title"), decoration: decoration)
        drawIncubator()

        let top = Self.codexTop
        let header = NSRect(x: Layout.padding, y: top, width: Self.innerWidth, height: Layout.rowHeight)
        PixelPaint.text(catalog.format("loot.codex", content.discoveredCount, content.materialCount), in: header)
        var y = top + Layout.rowHeight + 6
        for group in content.groups {
            drawGroup(group, top: y)
            y += Self.groupHeight(group)
        }
        PixelPaint.text(catalog.text("loot.hint"), in: NSRect(x: Layout.padding, y: y, width: Self.innerWidth, height: Layout.rowHeight), color: PixelPalette.shade)
    }

    private func drawIncubator() {
        let catalog = TextCatalog.shared
        let top = Self.bodyTop
        let row = NSRect(x: Layout.padding, y: top, width: Self.innerWidth, height: Layout.rowHeight)
        PixelPaint.text(catalog.text("loot.incubator"), in: row)
        let status = [
            catalog.format("loot.queued", content.queuedChests),
            catalog.format("loot.shards", content.shards, content.shardsPerChest),
        ].joined(separator: "  ")
        PixelPaint.text(status, in: row, color: PixelPalette.shade, align: 1)

        let count = CGFloat(max(1, content.slots.count))
        let width = ((Self.innerWidth - (count - 1) * Layout.slotGap) / count).rounded(.down)
        for (index, slot) in content.slots.enumerated() {
            let rect = NSRect(x: Layout.padding + CGFloat(index) * (width + Layout.slotGap), y: top + Layout.rowHeight + 6, width: width, height: Layout.slotHeight)
            drawSlot(slot, in: rect)
        }
    }

    private func drawSlot(_ slot: BackpackContent.Slot?, in rect: NSRect) {
        let catalog = TextCatalog.shared
        guard let slot else {
            PixelPaint.plate(rect, PixelPalette.paper3)
            PixelPaint.text(catalog.text("loot.slot_empty"), in: rect, color: PixelPalette.shade, align: 0.5)
            return
        }
        PixelPaint.plate(rect, PixelPalette.paper2)
        let chest = NSRect(x: rect.minX + 8, y: rect.minY + 10, width: 24, height: 20)
        Self.drawChest(slot.kind, in: chest)
        let textX = chest.maxX + 6
        let textWidth = rect.maxX - 8 - textX
        PixelPaint.text(LootText.chestName(slot.kind), in: NSRect(x: textX, y: rect.minY + 6, width: textWidth, height: 18))
        PixelPaint.text(catalog.format("loot.minutes_left", slot.minutesLeft), in: NSRect(x: textX, y: rect.minY + 22, width: textWidth, height: 16), color: PixelPalette.shade)
        let bar = NSRect(x: rect.minX + 8, y: rect.maxY - 16, width: rect.width - 16, height: 8)
        PixelPaint.fill(bar, PixelPalette.paper3)
        PixelPaint.fill(NSRect(x: bar.minX, y: bar.minY, width: (bar.width * slot.progress).rounded(), height: bar.height), PixelPalette.grass)
    }

    private func drawGroup(_ group: BackpackContent.Group, top: CGFloat) {
        let swatch = NSRect(x: Layout.padding, y: top + 5, width: 10, height: 10)
        Self.drawSwatch(group.tier, in: swatch)
        PixelPaint.text(LootText.tierName(group.tier), in: NSRect(x: swatch.maxX + 6, y: top, width: 120, height: Layout.groupLabelHeight))
        let cellWidth = ((Self.innerWidth - CGFloat(Layout.columns - 1) * Layout.cellGap) / CGFloat(Layout.columns)).rounded(.down)
        for (index, entry) in group.entries.enumerated() {
            let column = CGFloat(index % Layout.columns)
            let row = CGFloat(index / Layout.columns)
            let rect = NSRect(
                x: Layout.padding + column * (cellWidth + Layout.cellGap),
                y: top + Layout.groupLabelHeight + row * (Layout.cellHeight + Layout.cellGap),
                width: cellWidth,
                height: Layout.cellHeight
            )
            drawEntry(entry, tier: group.tier, in: rect)
        }
    }

    private func drawEntry(_ entry: BackpackContent.Entry, tier: LootTier, in rect: NSRect) {
        let catalog = TextCatalog.shared
        guard let name = entry.name else {
            PixelPaint.plate(rect, PixelPalette.paper3, corner: 1)
            PixelPaint.text(catalog.text("loot.unknown"), in: rect, color: PixelPalette.shade, align: 0.5)
            return
        }
        // 新拿到的用暖黄底（和衣柜里「穿着」同一个色），用光了的灰一点
        let background = entry.isNew ? PixelPalette.wornCell : (entry.count > 0 ? PixelPalette.paper : PixelPalette.paper3)
        PixelPaint.plate(rect, background, corner: 1)
        let swatch = NSRect(x: rect.minX + 6, y: rect.midY - 4, width: 8, height: 8)
        Self.drawSwatch(tier, in: swatch)
        let countText = catalog.format("loot.count", entry.count)
        let countWidth = PixelPaint.textSize(countText).width.rounded(.up)
        let nameRect = NSRect(x: swatch.maxX + 4, y: rect.minY, width: rect.maxX - 6 - countWidth - 4 - swatch.maxX - 4, height: rect.height)
        PixelPaint.text(name, in: nameRect)
        PixelPaint.text(countText, in: NSRect(x: rect.maxX - 6 - countWidth, y: rect.minY, width: countWidth, height: rect.height), color: PixelPalette.shade, align: 1)
    }

    // MARK: - 小图

    static func tierColor(_ tier: LootTier) -> NSColor {
        switch tier {
        case .black: return PixelPalette.rgb(0x34303C)
        case .gray: return PixelPalette.rgb(0x9A968F)
        case .white: return PixelPalette.white
        case .blue: return PixelPalette.rgb(0x5B8FD9)
        case .purple: return PixelPalette.rgb(0x9B6BD3)
        }
    }

    private static func drawSwatch(_ tier: LootTier, in rect: NSRect) {
        PixelPaint.fill(rect, PixelPalette.outline)
        PixelPaint.fill(rect.insetBy(dx: PixelPaint.unit, dy: PixelPaint.unit), tierColor(tier))
    }

    private static func chestColor(_ kind: ChestKind) -> NSColor {
        switch kind {
        case .wood: return PixelPalette.body
        case .iron: return PixelPalette.rgb(0x8C99A6)
        case .gold: return PixelPalette.yellow
        case .grayBox: return PixelPalette.rgb(0x9A968F)
        case .blackBox: return PixelPalette.rgb(0x34303C)
        }
    }

    /// 像素小宝箱：盖子、箱身、中间一把黄锁
    static func drawChest(_ kind: ChestKind, in rect: NSRect) {
        let unit = PixelPaint.unit
        PixelPaint.fill(rect, PixelPalette.outline)
        let inner = rect.insetBy(dx: unit, dy: unit)
        PixelPaint.fill(inner, chestColor(kind))
        let lidLine = NSRect(x: inner.minX, y: inner.minY + inner.height * 0.4, width: inner.width, height: unit)
        PixelPaint.fill(lidLine, PixelPalette.outline)
        PixelPaint.fill(NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: unit), PixelPalette.highlight)
        let lock = NSRect(x: (inner.midX - 2 * unit).rounded(), y: lidLine.minY - unit, width: 4 * unit, height: 4 * unit)
        PixelPaint.fill(lock, PixelPalette.outline)
        PixelPaint.fill(lock.insetBy(dx: unit, dy: unit), PixelPalette.yellow)
    }

    // MARK: - 事件

    override func mouseDown(with event: NSEvent) {
        PixelPanelChrome.handleMouseDown(event, in: self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        PixelPanelChrome.passesThrough(point, in: self) ? nil : super.hitTest(point)
    }
}
