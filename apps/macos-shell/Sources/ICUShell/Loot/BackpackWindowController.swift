import AppKit

/// 背包窗口：只看不改。背包里有东西变了（孵好了、拿到新宝箱）窗口跟着刷新
final class BackpackWindowController: NSWindowController, NSWindowDelegate {
    private let backpackView: BackpackView
    /// 窗口关了（「新」标记在这时清掉，开着的时候还看得见哪些是新的）
    var onClose: (() -> Void)?

    init(content: BackpackContent, decoration: NSImage? = nil) {
        backpackView = BackpackView(content: content, decoration: decoration)
        let window = PixelWindow(size: BackpackView.preferredSize(for: content), title: TextCatalog.shared.text("loot.title"), content: backpackView)
        super.init(window: window)
        window.delegate = self
        backpackView.closeButton.target = self
        backpackView.closeButton.action = #selector(closeBackpack)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var view: BackpackView { backpackView }
    var isVisible: Bool { window?.isVisible == true }

    func present() {
        (window as? PixelWindow)?.present()
    }

    func update(content: BackpackContent, decoration: NSImage?) {
        backpackView.decoration = decoration
        backpackView.update(content: content)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    @objc private func closeBackpack() {
        window?.performClose(nil)
    }
}
