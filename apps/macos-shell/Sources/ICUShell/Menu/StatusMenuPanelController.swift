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

    func toggle(from button: NSStatusBarButton, model: StatusItemMenuModel) {
        if isPresented {
            dismiss()
            return
        }

        present(from: button, model: model)
    }

    func dismiss() {
        floatingPanelController.dismiss()
    }

    private func present(from button: NSStatusBarButton, model: StatusItemMenuModel) {
        guard let window = button.window else {
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

        let panel = ThemedMenuPanel(sections: sections) { [weak self] id in
            guard
                let self,
                let action = StatusItemMenuAction(rawValue: id)
            else {
                return
            }

            self.dismiss()
            self.onAction(action)
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameInScreen = window.convertToScreen(buttonFrameInWindow)
        let size = ThemedMenuPanel.preferredSize(for: sections)
        let frame = NSRect(
            x: buttonFrameInScreen.midX - (size.width / 2),
            y: buttonFrameInScreen.minY - size.height - 6,
            width: size.width,
            height: size.height
        )

        floatingPanelController.present(contentView: panel, frame: frame)
        currentPanel = panel
    }
}
