import AppKit

final class FloatingPanelController {
    private(set) var panelWindow: MenuFloatingPanelWindow?
    var onDidDismiss: (() -> Void)?

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var deactivationObserver: NSObjectProtocol?

    var isPresented: Bool {
        panelWindow != nil
    }

    deinit {
        dismiss()
    }

    func present(contentView: NSView, frame: NSRect) {
        dismiss()

        let adjustedFrame = clampedFrame(for: frame)
        contentView.frame = NSRect(origin: .zero, size: adjustedFrame.size)

        let panel = MenuFloatingPanelWindow(
            contentRect: adjustedFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = false
        panel.contentView = contentView
        panel.onCancel = { [weak self] in
            self?.dismiss()
        }

        panelWindow = panel
        installOutsideClickMonitors()
        installDeactivationObserver()
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        let hadPanel = panelWindow != nil
        removeOutsideClickMonitors()
        removeDeactivationObserver()
        panelWindow?.orderOut(nil)
        panelWindow = nil
        if hadPanel {
            onDidDismiss?()
        }
    }

    private func installOutsideClickMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleMonitoredMouseEvent(event)
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func removeOutsideClickMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    @discardableResult
    func handleMonitoredMouseEvent(_ event: NSEvent) -> NSEvent? {
        guard let panelWindow else {
            return event
        }

        if event.windowNumber != 0 {
            if event.windowNumber != panelWindow.windowNumber {
                dismiss()
            }
            return event
        }

        if event.window !== panelWindow {
            dismiss()
        }

        return event
    }

    private func installDeactivationObserver() {
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    private func removeDeactivationObserver() {
        if let deactivationObserver {
            NotificationCenter.default.removeObserver(deactivationObserver)
            self.deactivationObserver = nil
        }
    }

    private func clampedFrame(for frame: NSRect) -> NSRect {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else {
            return frame
        }

        let visibleFrame = screen.visibleFrame
        let maxX = visibleFrame.maxX - frame.width
        let maxY = visibleFrame.maxY - frame.height
        let clampedX = min(max(frame.origin.x, visibleFrame.minX), maxX)
        let clampedY = min(max(frame.origin.y, visibleFrame.minY), maxY)
        return NSRect(x: clampedX, y: clampedY, width: frame.width, height: frame.height)
    }
}

final class MenuFloatingPanelWindow: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        super.keyDown(with: event)
    }
}
