import AppKit

// MARK: - Window Controller

class DesktopPetWindowController: NSWindowController, NSWindowDelegate {
    private let workSessionController: WorkSessionController
    private let reminderScheduler: ReminderScheduler
    private let avatarCoordinator: AvatarCoordinator
    private let generationCoordinator: GenerationCoordinator
    private let onQuitRequested: () -> Void
    private let petView: DesktopPetView
    private lazy var contextMenuController = ContextMenuPanelController { [weak self] action in
        self?.handleMenuAction(action)
    }

    init(
        workSessionController: WorkSessionController,
        reminderScheduler: ReminderScheduler,
        assetLocator: PetAssetLocator,
        petID: String,
        avatarCoordinator: AvatarCoordinator,
        generationCoordinator: GenerationCoordinator,
        onQuitRequested: @escaping () -> Void
    ) {
        self.workSessionController = workSessionController
        self.reminderScheduler = reminderScheduler
        self.avatarCoordinator = avatarCoordinator
        self.generationCoordinator = generationCoordinator
        self.onQuitRequested = onQuitRequested

        let size = NSSize(width: 128, height: 128)
        let origin = WindowPlacement.resolveInitialOrigin(
            saved: workSessionController.savedWindowPlacement,
            visibleFrame: Self.activeVisibleFrame(),
            windowSize: size
        )
        let frame = NSRect(origin: origin, size: size)

        let window = DesktopPetWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // 透明无边框设置
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        // 浮在所有普通窗口之上
        window.level = .floating

        // 不抢焦点
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        let petView = DesktopPetView(
            frame: NSRect(origin: .zero, size: size),
            assetLocator: assetLocator,
            petID: petID
        )
        self.petView = petView
        window.contentView = petView

        super.init(window: window)
        window.delegate = self

        window.menuModelProvider = { [weak self] in
            self?.currentMenuModel() ?? DesktopPetMenuModel(state: .idle)
        }
        window.actionHandler = { [weak self] action in
            self?.handleMenuAction(action)
        }
        window.contextMenuController = contextMenuController

        applyCurrentStateToView(showBubble: true)
        persistCurrentWindowPlacement()
        window.makeKeyAndOrderFront(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func presentReminder(text: String) {
        petView.showTransientMessage(text)
    }

    func setPetID(_ petID: String) {
        petView.setPetID(petID)
    }

    func windowDidMove(_ notification: Notification) {
        persistCurrentWindowPlacement()
    }

    private func currentMenuModel() -> DesktopPetMenuModel {
        DesktopPetMenuModel(state: workSessionController.state)
    }

    private func handleMenuAction(_ action: DesktopPetMenuAction) {
        do {
            var transientMessage: String?

            switch action {
            case .startWork:
                try workSessionController.startWork()
                reminderScheduler.startWorking()
            case .enterFocus:
                try workSessionController.enterFocus()
                reminderScheduler.enterFocus()
            case .takeBreak:
                try workSessionController.takeBreak()
                reminderScheduler.stop()
            case .resumeWorking:
                let suggestion = try workSessionController.resumeWorking()
                reminderScheduler.resumeWorking()
                transientMessage = focusSuggestionMessage(for: suggestion)
            case .stopWork:
                try workSessionController.stopWork()
                reminderScheduler.stop()
                transientMessage = DesktopPetCopy.stopWorkMessage()
            case .changeAvatar:
                avatarCoordinator.presentAvatarPicker()
                return
            case .openGenerationConfig:
                _ = generationCoordinator.openGenerationConfig()
                return
            case .openHealthReport:
                return
            case .closeWindow:
                window?.orderOut(nil)
                return
            case .quitApp:
                onQuitRequested()
                return
            }

            applyCurrentStateToView(showBubble: transientMessage == nil)
            if let transientMessage {
                petView.showTransientMessage(transientMessage)
            }
        } catch {
            NSSound.beep()
            petView.showTransientMessage(UserFacingErrorCopy.desktopPetMessage(for: error), duration: 2)
        }
    }

    private func applyCurrentStateToView(showBubble: Bool = false) {
        petView.setWorkState(workSessionController.state)
        petView.setStatusText(statusText(for: workSessionController.state), showBubble: showBubble)
    }

    private func statusText(for state: ShellWorkState) -> String {
        DesktopPetCopy.statusText(for: state)
    }

    private func focusSuggestionMessage(for suggestion: FocusEndSuggestion?) -> String? {
        DesktopPetCopy.focusSuggestionMessage(for: suggestion)
    }

    private func persistCurrentWindowPlacement() {
        guard let origin = window?.frame.origin else {
            return
        }

        do {
            try workSessionController.persistWindowPlacement(SavedWindowPlacement(origin: origin))
        } catch {
            NSLog("[ICUShell] failed to persist window placement: \(error.localizedDescription)")
        }
    }

    private static func activeVisibleFrame() -> CGRect {
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            return screen.visibleFrame
        }

        return CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

// MARK: - Window

class DesktopPetWindow: NSWindow {
    var menuModelProvider: (() -> DesktopPetMenuModel)?
    var actionHandler: ((DesktopPetMenuAction) -> Void)?
    var contextMenuController: ContextMenuPanelController?

    // 无边框窗口默认无法成为 key window，这里开放以接收键盘事件（Spike 阶段备用）
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // 拖拽移动窗口
    override func mouseDragged(with event: NSEvent) {
        performDrag(with: event)
    }

    // 右键菜单
    override func rightMouseDown(with event: NSEvent) {
        guard let contentView else {
            return
        }

        contextMenuController?.present(
            from: menuModelProvider?() ?? DesktopPetMenuModel(state: .idle),
            event: event,
            in: contentView
        )
    }

    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let action = DesktopPetMenuAction(rawValue: rawValue)
        else {
            return
        }

        actionHandler?(action)
    }
}
