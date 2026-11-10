import AppKit

final class StatusMenuPanelController {
    private let floatingPanelController = FloatingPanelController()
    private let onAction: (StatusItemMenuAction) -> Void

    private(set) var currentPanel: ThemedMenuPanel?

    var isPresented: Bool {
        floatingPanelController.isPresented
    }

    init(onAction: @escaping (StatusItemMenuAction) -> Void) {
        self.onAction = onAction
        floatingPanelController.onDidDismiss = { [weak self] in
            self?.currentPanel = nil
        }
    }

    func toggle(from button: NSStatusBarButton, model: StatusItemMenuModel, summary: MenuTodaySummary? = nil) {
        if isPresented {
            dismiss()
            return
        }

        present(from: button, model: model, summary: summary)
    }

    func dismiss() {
        floatingPanelController.dismiss()
    }

    /// 「今日报告…」：像素风浮层，挂在状态栏按钮下面、右边和按钮对齐往左长（按钮在屏幕右上角，居中会顶到屏幕边）
    func presentTodayReport(from button: NSStatusBarButton, content: TodayReportContent) {
        guard let window = button.window else {
            return
        }

        let contentView = MenuTodayReportView(content: content)
        let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? buttonFrame.insetBy(dx: -2000, dy: -2000)
        let frame = ReportPanelPlacement.frame(size: contentView.frame.size, below: buttonFrame, in: visible)
        floatingPanelController.present(contentView: contentView, frame: frame)
    }

    private func present(from button: NSStatusBarButton, model: StatusItemMenuModel, summary: MenuTodaySummary?) {
        guard button.window != nil else {
            return
        }

        let sections = model.sections.map { section in
            ThemedMenuPanelSection(
                items: section.map { action in
                    ThemedMenuPanelItem(
                        id: action.rawValue,
                        title: action.title,
                        tone: action == .quitApp ? .destructive : .standard
                    )
                }
            )
        }

        let panel = ThemedMenuPanel(sections: sections, summary: summary) { [weak self] id in
            guard
                let self,
                let action = StatusItemMenuAction(rawValue: id)
            else {
                return
            }

            self.dismiss()
            self.onAction(action)
        }

        guard let frame = panelFrame(for: button, size: ThemedMenuPanel.preferredSize(for: sections, hasSummary: summary != nil)) else {
            return
        }

        floatingPanelController.present(contentView: panel, frame: frame)
        currentPanel = panel
    }

    /// 面板锚到按钮下方 6pt，横向以按钮居中
    private func panelFrame(for button: NSStatusBarButton, size: NSSize) -> NSRect? {
        guard let window = button.window else {
            return nil
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameInScreen = window.convertToScreen(buttonFrameInWindow)
        return NSRect(
            x: buttonFrameInScreen.midX - (size.width / 2),
            y: buttonFrameInScreen.minY - size.height - 6,
            width: size.width,
            height: size.height
        )
    }
}
