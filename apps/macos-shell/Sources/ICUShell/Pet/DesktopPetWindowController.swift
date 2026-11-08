import AppKit

// MARK: - Window Controller

class DesktopPetWindowController: NSWindowController, NSWindowDelegate {
    private let workSessionController: WorkSessionController
    private let reminderScheduler: ReminderScheduler
    private let healthTracker: HealthSessionTracker
    private let healthReportPresenter: (HealthDaySummary, HealthWeekSummary) -> Void
    private let onChangeAvatarRequested: () -> Void
    private let onOpenGenerationConfigRequested: () -> Void
    private let onQuitRequested: () -> Void
    private let nowProvider: () -> Date
    private let petView: DesktopPetView
    private var edgeDock: PetEdgeDockController?
    private var gaze: PetGazeController?
    private lazy var contextMenuController = ContextMenuPanelController { [weak self] action in
        self?.handleMenuAction(action)
    }

    init(
        workSessionController: WorkSessionController,
        reminderScheduler: ReminderScheduler,
        healthTracker: HealthSessionTracker,
        healthReportPresenter: @escaping (HealthDaySummary, HealthWeekSummary) -> Void,
        assetLocator: PetAssetLocator,
        petID: String,
        onChangeAvatarRequested: @escaping () -> Void,
        onOpenGenerationConfigRequested: @escaping () -> Void,
        onQuitRequested: @escaping () -> Void,
        edgeSnapSettings: EdgeSnapSettings = .default,
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.workSessionController = workSessionController
        self.reminderScheduler = reminderScheduler
        self.healthTracker = healthTracker
        self.healthReportPresenter = healthReportPresenter
        self.onChangeAvatarRequested = onChangeAvatarRequested
        self.onOpenGenerationConfigRequested = onOpenGenerationConfigRequested
        self.onQuitRequested = onQuitRequested
        self.nowProvider = nowProvider

        let size = DesktopPetView.compactContentSize
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
        // 拖拽由 DesktopPetView 自己处理（带拎起 / 摆动 / 落地效果）
        window.isMovableByWindowBackground = false

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
        configureEdgeDock(window: window, settings: edgeSnapSettings)
        configureGaze(window: window)
        petView.onPetDragEnded = { [weak self] in
            self?.persistCurrentWindowPlacement()
            self?.edgeDock?.dragEnded()
        }
        petView.onOverlayLayoutModeChanged = { [weak self] mode in
            self?.updateWindowSize(for: mode)
            self?.edgeDock?.overlayVisibilityChanged(mode != .compact)
        }

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
        edgeDock?.restoreAfterLaunch()
    }

    /// 转头看鼠标；贴在左右屏幕边时朝向归贴边管（脸朝屏幕里）
    private func configureGaze(window: NSWindow) {
        let gaze = PetGazeController(
            bodyFrameOnScreen: { [weak petView, weak window] in
                guard let body = petView?.petBodyRect, let origin = window?.frame.origin else { return nil }
                return body.offsetBy(dx: origin.x, dy: origin.y)
            },
            isFacingRight: { [weak petView] in petView?.isFacingRight ?? false },
            onTurn: { [weak petView] facingRight in petView?.setFacingRight(facingRight) }
        )
        gaze.canTurn = { [weak self] in
            guard let self, self.petView.canTurnTowardCursor else { return false }
            guard let edgeDock = self.edgeDock else { return true }
            return edgeDock.dock.horizontal == nil && !edgeDock.isHidden
        }
        self.gaze = gaze
    }

    private func configureEdgeDock(window: NSWindow, settings: EdgeSnapSettings) {
        let edgeDock = PetEdgeDockController(
            window: window,
            settings: settings,
            bodyRectProvider: { [weak petView] in petView?.petBodyRect }
        )
        edgeDock.onFacingChanged = { [weak petView] facingRight in
            petView?.setFacingRight(facingRight)
        }
        edgeDock.canPeek = { [weak petView] in petView?.hasPeekPose ?? false }
        edgeDock.onPeekChanged = { [weak petView] peeking in
            petView?.setEdgePeek(peeking)
        }
        edgeDock.onDockedOriginSettled = { [weak self] origin in
            self?.persistWindowPlacement(origin)
        }
        petView.onPetDragStarted = { [weak edgeDock] in edgeDock?.dragStarted() }
        petView.onPointerEntered = { [weak edgeDock] in edgeDock?.pointerEntered() }
        petView.onPointerExited = { [weak edgeDock] in edgeDock?.pointerExited() }
        self.edgeDock = edgeDock
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

    func presentReminder(payload: ReminderPresentationPayload) {
        let now = nowProvider()
        do {
            try healthTracker.recordReminderShown(payload, at: now)
        } catch {
            logHealthError("record reminder shown", error: error)
        }

        petView.showReminderCard(payload) { [weak self] outcome in
            self?.handleReminderOutcome(outcome, for: payload)
        }
    }

    func presentHealthReport() {
        let now = nowProvider()
        do {
            let todaySummary = try healthTracker.todayReport(at: now)
            let weekSummary = try healthTracker.weekReport(containing: now)
            healthReportPresenter(todaySummary, weekSummary)
        } catch {
            logHealthError("load health report", error: error)
            petView.showTransientMessage(DesktopPetCopy.healthReportUnavailableMessage(), duration: 1.8)
        }
    }

    func setPetID(_ petID: String) {
        petView.setPetID(petID)
    }

    func windowDidMove(_ notification: Notification) {
        // 拖拽中每个事件都会移动窗口，等松手（onPetDragEnded）再落盘；
        // 吸边 / 藏边动画的中间位置也不保存（贴好后由 onDockedOriginSettled 保存）
        guard !petView.isDraggingPet, edgeDock?.isManagingWindowPosition != true else { return }
        persistCurrentWindowPlacement()
    }

    private func currentMenuModel() -> DesktopPetMenuModel {
        DesktopPetMenuModel(state: workSessionController.state)
    }

    private func handleMenuAction(_ action: DesktopPetMenuAction) {
        do {
            let oldState = workSessionController.state
            let now = nowProvider()
            var transientMessage: String?
            var shouldPresentReport = false

            switch action {
            case .startWork:
                try workSessionController.startWork(now: now)
                recordHealthTransition(from: oldState, to: workSessionController.state, at: now)
                reminderScheduler.startWorking()
            case .enterFocus:
                try workSessionController.enterFocus(now: now)
                recordHealthTransition(from: oldState, to: workSessionController.state, at: now)
                reminderScheduler.enterFocus()
            case .takeBreak:
                try workSessionController.takeBreak(now: now)
                recordHealthTransition(from: oldState, to: workSessionController.state, at: now)
                reminderScheduler.stop()
            case .resumeWorking:
                let suggestion = try workSessionController.resumeWorking(now: now)
                recordHealthTransition(from: oldState, to: workSessionController.state, at: now)
                reminderScheduler.resumeWorking()
                transientMessage = focusSuggestionMessage(for: suggestion)
            case .stopWork:
                try workSessionController.stopWork(now: now)
                recordHealthTransition(from: oldState, to: workSessionController.state, at: now)
                reminderScheduler.stop()
                shouldPresentReport = shouldAutoPresentStopWorkReport(at: now)
                transientMessage = shouldPresentReport ? nil : DesktopPetCopy.stopWorkMessage()
            case .changeAvatar:
                onChangeAvatarRequested()
                return
            case .openGenerationConfig:
                onOpenGenerationConfigRequested()
                return
            case .openHealthReport:
                presentHealthReport()
                return
            case .closeWindow:
                window?.orderOut(nil)
                return
            case .quitApp:
                onQuitRequested()
                return
            }

            applyCurrentStateToView(showBubble: transientMessage == nil && !shouldPresentReport)
            if let transientMessage {
                petView.showTransientMessage(transientMessage)
            }
            if shouldPresentReport {
                presentHealthReport()
            }
        } catch {
            NSSound.beep()
            petView.showTransientMessage(UserFacingErrorCopy.desktopPetMessage(for: error), duration: 2)
        }
    }

    private func handleReminderOutcome(_ outcome: HealthReminderOutcome, for payload: ReminderPresentationPayload) {
        let now = nowProvider()
        petView.dismissReminderCard()
        applyCurrentStateToView(showBubble: false)

        do {
            try healthTracker.recordReminderOutcome(for: payload, outcome: outcome, at: now)
        } catch {
            logHealthError("record reminder outcome", error: error)
        }

        if outcome == .snoozed {
            let followUpPayload = ReminderPresentationPayload(
                id: UUID(),
                type: payload.type,
                text: payload.text
            )
            reminderScheduler.scheduleSnooze(for: followUpPayload)
        }
    }

    private func recordHealthTransition(from oldState: ShellWorkState, to newState: ShellWorkState, at date: Date) {
        do {
            try healthTracker.recordStateTransition(from: oldState, to: newState, at: date)
        } catch {
            logHealthError("record state transition", error: error)
        }
    }

    private func shouldAutoPresentStopWorkReport(at date: Date) -> Bool {
        do {
            return try healthTracker.shouldPresentStopWorkReport(at: date)
        } catch {
            logHealthError("check stop-work report eligibility", error: error)
            return false
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

    private func logHealthError(_ operation: String, error: Error) {
        NSLog("[ICUShell] failed to \(operation): \(error.localizedDescription)")
    }

    private func updateWindowSize(for mode: DesktopPetView.OverlayLayoutMode) {
        guard let window else {
            return
        }

        let targetSize: NSSize
        switch mode {
        case .compact:
            targetSize = DesktopPetView.compactContentSize
        case .transientBubble:
            targetSize = DesktopPetView.transientBubbleExpandedContentSize
        case .reminderCard:
            targetSize = DesktopPetView.reminderExpandedContentSize
        }
        guard window.contentView?.frame.size != targetSize else {
            return
        }

        var frame = window.frame
        frame.size = targetSize
        window.setFrame(frame, display: true)
    }

    private func persistCurrentWindowPlacement() {
        guard let origin = window?.frame.origin else {
            return
        }
        persistWindowPlacement(origin)
    }

    private func persistWindowPlacement(_ origin: CGPoint) {
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
