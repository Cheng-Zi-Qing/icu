import AppKit

/// 衣柜窗口：点了就穿上并立刻保存，没有「确定」按钮。保存失败时什么都不变，底部提示再点一次
final class WardrobeWindowController: NSWindowController, NSWindowDelegate {
    private let catalog: WardrobeCatalog
    private let wardrobeView: WardrobeView
    private let onChange: (WardrobeState) throws -> Void
    private(set) var state: WardrobeState

    /// - Parameter onChange: 保存并让桌宠换装；抛错就当没换
    init(catalog: WardrobeCatalog, state: WardrobeState, art: WardrobeArt, onChange: @escaping (WardrobeState) throws -> Void) {
        self.catalog = catalog
        self.state = state
        self.onChange = onChange
        var equip: ((String) -> Void)?
        var wear: ((WardrobeSuit) -> Void)?
        wardrobeView = WardrobeView(
            catalog: catalog,
            state: state,
            art: art,
            onEquip: { id in equip?(id) },
            onWearSuit: { suit in wear?(suit) }
        )
        let window = PixelWindow(size: WardrobeView.preferredSize(for: catalog), title: "衣柜", content: wardrobeView)
        super.init(window: window)
        window.delegate = self

        equip = { [weak self] id in self?.equip(id) }
        wear = { [weak self] suit in self?.wear(suit) }
        wardrobeView.closeButton.target = self
        wardrobeView.closeButton.action = #selector(closeWardrobe)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var view: WardrobeView { wardrobeView }

    func present() {
        (window as? PixelWindow)?.present()
    }

    func equip(_ itemID: String) {
        guard !state.isWearing(itemID), let next = state.equipping(itemID, in: catalog) else { return }
        apply(next)
    }

    func wear(_ suit: WardrobeSuit) {
        guard let next = state.wearing(suit, in: catalog), next != state else { return }
        apply(next)
    }

    private func apply(_ next: WardrobeState) {
        do {
            try onChange(next)
            state = next
            wardrobeView.message = nil
            wardrobeView.update(state: next)
        } catch {
            NSLog("[Wardrobe] failed to save wardrobe: \(error.localizedDescription)")
            wardrobeView.message = "没存上，再点一次试试"
        }
    }

    @objc private func closeWardrobe() {
        window?.performClose(nil)
    }
}
