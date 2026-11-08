import AppKit

final class ContextMenuPanelController {
    private let floatingPanelController = FloatingPanelController()
    private let onAction: (DesktopPetMenuAction) -> Void

    private(set) var currentPanel: ThemedMenuPanel?

    var isPresented: Bool {
        floatingPanelController.isPresented
    }

    init(onAction: @escaping (DesktopPetMenuAction) -> Void) {
        self.onAction = onAction
        floatingPanelController.onDidDismiss = { [weak self] in
            self?.currentPanel = nil
        }
    }

    func present(
        from model: DesktopPetMenuModel,
        summary: MenuTodaySummary? = nil,
        event: NSEvent,
        in contentView: NSView
    ) {
        guard let window = contentView.window ?? NSApp.window(withWindowNumber: event.windowNumber) else {
            return
        }

        let sections = makeSections(from: model)
        let panel = ThemedMenuPanel(sections: sections, summary: summary) { [weak self] id in
            guard
                let self,
                let action = DesktopPetMenuAction(rawValue: id)
            else {
                return
            }

            self.dismiss()
            self.onAction(action)
        }

        let size = ThemedMenuPanel.preferredSize(for: sections, hasSummary: summary != nil)
        let clickPoint = window.convertPoint(toScreen: event.locationInWindow)
        let frame = NSRect(
            x: clickPoint.x - 12,
            y: clickPoint.y - size.height + 12,
            width: size.width,
            height: size.height
        )

        floatingPanelController.present(contentView: panel, frame: frame)
        currentPanel = panel
    }

    func dismiss() {
        floatingPanelController.dismiss()
    }

    private func makeSections(from model: DesktopPetMenuModel) -> [ThemedMenuPanelSection] {
        model.sections.map { section in
            ThemedMenuPanelSection(
                items: section.map { action in
                    ThemedMenuPanelItem(
                        id: action.rawValue,
                        title: action.title,
                        tone: Self.tone(for: action)
                    )
                }
            )
        }
    }

    private static func tone(for action: DesktopPetMenuAction) -> ThemedMenuPanelItem.Tone {
        switch action {
        case .startWork, .resumeWorking: return .primary
        case .quitApp: return .destructive
        default: return .standard
        }
    }
}
