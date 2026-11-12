import AppKit

/// 像素风衣柜：左边试衣台（桌宠现在的侧身形象），右边四个装扮位页签和格子，底下一排套装
final class WardrobeView: NSView {
    enum Layout {
        static let width: CGFloat = 480
        static let padding: CGFloat = 16
        static let standWidth: CGFloat = 176
        static let tabHeight: CGFloat = 26
        static let tabGap: CGFloat = 6
        static let gridGap: CGFloat = 8
        static let columns = 3
        static let suitHeight: CGFloat = 26
        static let messageHeight: CGFloat = 20
        static let previewScale: CGFloat = 5
        static let meadowHeight: CGFloat = 40
        static let suitLabelWidth: CGFloat = 44
    }

    let closeButton = PixelPanelChrome.makeCloseButton(identifier: "wardrobe.close")
    private(set) var tabButtons: [WardrobeSlot: PixelButton] = [:]
    private(set) var cells: [WardrobeItemCell] = []
    private(set) var suitButtons: [PixelButton] = []
    private(set) var selectedSlot: WardrobeSlot = .head
    var message: String? { didSet { needsDisplay = true } }

    private let catalog: WardrobeCatalog
    private let art: WardrobeArt
    private let onEquip: (String) -> Void
    private let onWearSuit: (WardrobeSuit) -> Void
    private var state: WardrobeState
    private var previewImage: NSImage?
    private var decorationImage: NSImage?
    private var copyObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }

    // MARK: - 尺寸

    private static func gridRows(for catalog: WardrobeCatalog) -> Int {
        let most = WardrobeSlot.allCases.map { catalog.items(in: $0).count }.max() ?? 1
        return max(1, (most + Layout.columns - 1) / Layout.columns)
    }

    private static func gridHeight(for catalog: WardrobeCatalog) -> CGFloat {
        let rows = CGFloat(gridRows(for: catalog))
        return rows * WardrobeItemCell.size.height + (rows - 1) * Layout.gridGap
    }

    private static var bodyTop: CGFloat { PixelPanelChrome.decorationHeight + PixelPanelChrome.titleHeight + Layout.padding }

    private static func standHeight(for catalog: WardrobeCatalog) -> CGFloat {
        Layout.tabHeight + 10 + gridHeight(for: catalog)
    }

    private static func suitsTop(for catalog: WardrobeCatalog) -> CGFloat {
        bodyTop + standHeight(for: catalog) + 14
    }

    static func preferredSize(for catalog: WardrobeCatalog) -> NSSize {
        let height = suitsTop(for: catalog) + Layout.suitHeight + 6 + Layout.messageHeight + 6
            + CGFloat(PixelPanelChrome.shadow) * PixelPaint.unit
        return NSSize(width: Layout.width, height: height)
    }

    private var standRect: NSRect {
        NSRect(x: Layout.padding, y: Self.bodyTop, width: Layout.standWidth, height: Self.standHeight(for: catalog))
    }

    private var rightColumnX: CGFloat { Layout.padding + Layout.standWidth + Layout.padding }
    private var rightColumnWidth: CGFloat { bounds.width - rightColumnX - Layout.padding }

    // MARK: - 初始化

    init(
        catalog: WardrobeCatalog,
        state: WardrobeState,
        art: WardrobeArt,
        onEquip: @escaping (String) -> Void,
        onWearSuit: @escaping (WardrobeSuit) -> Void
    ) {
        self.catalog = catalog
        self.state = state
        self.art = art
        self.onEquip = onEquip
        self.onWearSuit = onWearSuit
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize(for: catalog)))
        addSubview(closeButton)
        buildTabs()
        buildSuits()
        update(state: state)
        copyObserver = NotificationCenter.default.addObserver(forName: .icuCopyDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadCopy()
        }
    }

    deinit {
        copyObserver.map(NotificationCenter.default.removeObserver)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 状态

    /// 换装后刷新：格子、套装高亮、试衣台、标题栏上那只
    func update(state: WardrobeState) {
        self.state = state
        previewImage = art.preview(state)
        decorationImage = art.decoration(state)
        rebuildCells()
        refreshSuits()
        needsDisplay = true
    }

    func select(slot: WardrobeSlot) {
        selectedSlot = slot
        for (tabSlot, button) in tabButtons {
            button.fillColor = tabSlot == slot ? PixelPalette.yellow : PixelPalette.paper2
            button.setAccessibilityValue(tabSlot == slot ? TextCatalog.shared.text("common.selected") : nil)
        }
        rebuildCells()
    }

    /// 语言换了：页签、套装、格子里的字都重读一遍（宽度跟着变，所以套装按钮重建）
    func reloadCopy() {
        for (slot, button) in tabButtons {
            button.title = slot.title
        }
        buildSuits()
        refreshSuits()
        select(slot: selectedSlot)
        needsDisplay = true
    }

    private func buildTabs() {
        let slots = WardrobeSlot.allCases
        let count = CGFloat(slots.count)
        let width = ((rightColumnWidth - (count - 1) * Layout.tabGap) / count).rounded(.down)
        for (index, slot) in slots.enumerated() {
            let button = PixelButton(title: slot.title, identifier: "wardrobe.tab.\(slot.rawValue)")
            button.frame = NSRect(x: rightColumnX + CGFloat(index) * (width + Layout.tabGap), y: Self.bodyTop, width: width, height: Layout.tabHeight)
            button.target = self
            button.action = #selector(handleTab(_:))
            addSubview(button)
            tabButtons[slot] = button
        }
        select(slot: .head)
    }

    private func rebuildCells() {
        cells.forEach { $0.removeFromSuperview() }
        let top = Self.bodyTop + Layout.tabHeight + 10
        let size = WardrobeItemCell.size
        cells = catalog.items(in: selectedSlot).enumerated().map { index, item in
            let cell = WardrobeItemCell(item: item, icon: art.itemIcon(item.id), look: look(of: item))
            let column = CGFloat(index % Layout.columns)
            let row = CGFloat(index / Layout.columns)
            cell.frame = NSRect(
                x: rightColumnX + column * (size.width + Layout.gridGap),
                y: top + row * (size.height + Layout.gridGap),
                width: size.width,
                height: size.height
            )
            cell.target = self
            cell.action = #selector(handleCell(_:))
            addSubview(cell)
            return cell
        }
    }

    private func look(of item: WardrobeItem) -> WardrobeItemCell.Look {
        if state.equipped[item.slot] == item.id { return .equipped }
        return state.owned.contains(item.id) ? .owned : .locked
    }

    private func buildSuits() {
        suitButtons.forEach { $0.removeFromSuperview() }
        var x = Layout.padding + Layout.suitLabelWidth
        suitButtons = catalog.suits.map { suit in
            let title = suit.displayName
            let button = PixelButton(title: title, identifier: "wardrobe.suit.\(suit.id)")
            let lockRoom = state.canWear(suit) ? 0 : PixelPaint.iconSize(.lock).width + 4
            let width = (PixelPaint.textSize(title).width + 24 + lockRoom).rounded(.up)
            button.frame = NSRect(x: x, y: Self.suitsTop(for: catalog), width: width, height: Layout.suitHeight)
            button.target = self
            button.action = #selector(handleSuit(_:))
            addSubview(button)
            x += width + Layout.tabGap
            return button
        }
    }

    private func refreshSuits() {
        for (suit, button) in zip(catalog.suits, suitButtons) {
            let unlocked = state.canWear(suit)
            button.isEnabled = unlocked
            button.icon = unlocked ? nil : .lock
            button.fillColor = state.isWearing(suit) ? PixelPalette.yellow : PixelPalette.paper2
            button.setAccessibilityValue(
                unlocked
                    ? (state.isWearing(suit) ? TextCatalog.shared.text("wardrobe.wearing") : nil)
                    : TextCatalog.shared.text("wardrobe.suit_locked")
            )
        }
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        PixelPanelChrome.draw(in: bounds, title: TextCatalog.shared.text("wardrobe.title"), decoration: decorationImage)
        drawStand()
        PixelPaint.text(TextCatalog.shared.text("wardrobe.suits"), in: NSRect(x: Layout.padding, y: Self.suitsTop(for: catalog), width: Layout.suitLabelWidth, height: Layout.suitHeight))
        if let message {
            let y = Self.suitsTop(for: catalog) + Layout.suitHeight + 6
            PixelPaint.text(message, in: NSRect(x: Layout.padding, y: y, width: bounds.width - 2 * Layout.padding, height: Layout.messageHeight), color: PixelPalette.danger)
        }
    }

    /// 试衣台：蓝天 + 草地，水豚按 5 倍站在草地上
    private func drawStand() {
        let stand = standRect
        PixelPaint.plate(stand, PixelPalette.sky)
        let inner = stand.insetBy(dx: PixelPaint.unit, dy: PixelPaint.unit)
        PixelPaint.fill(NSRect(x: inner.minX, y: inner.maxY - Layout.meadowHeight, width: inner.width, height: Layout.meadowHeight), PixelPalette.meadow)
        guard let previewImage else { return }
        let side = 32 * Layout.previewScale
        let rect = NSRect(x: (stand.midX - side / 2).rounded(), y: inner.maxY - Layout.meadowHeight / 2 - side, width: side, height: side)
        PixelPaint.image(previewImage, in: rect)
    }

    // MARK: - 事件

    @objc private func handleTab(_ sender: PixelButton) {
        guard let slot = tabButtons.first(where: { $0.value === sender })?.key else { return }
        select(slot: slot)
    }

    @objc private func handleCell(_ sender: WardrobeItemCell) {
        onEquip(sender.itemID)
    }

    @objc private func handleSuit(_ sender: PixelButton) {
        guard let index = suitButtons.firstIndex(where: { $0 === sender }) else { return }
        onWearSuit(catalog.suits[index])
    }

    override func mouseDown(with event: NSEvent) {
        PixelPanelChrome.handleMouseDown(event, in: self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        PixelPanelChrome.passesThrough(point, in: self) ? nil : super.hitTest(point)
    }
}
