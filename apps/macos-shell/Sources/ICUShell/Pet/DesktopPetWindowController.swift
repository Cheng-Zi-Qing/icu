import AppKit

// MARK: - Window Controller

class DesktopPetWindowController: NSWindowController, NSWindowDelegate {
    private let workSessionController: WorkSessionController
    private let reminderScheduler: ReminderScheduler
    private let healthTracker: HealthSessionTracker
    private let onQuitRequested: () -> Void
    private let onOpenSettingsRequested: () -> Void
    private let onOpenWardrobeRequested: () -> Void
    private let todaySummaryProvider: () -> MenuTodaySummary?
    private let nowProvider: () -> Date
    private let petView: DesktopPetView
    private var edgeDock: PetEdgeDockController?
    private var gaze: PetGazeController?
    /// Claude Code 接上了没有（菜单里显示「接入 / 断开」）；nil = 没法接，不显示
    var claudeConnection: () -> Bool? = { nil }
    var onClaudeConnectionChange: (Bool) -> Void = { _ in }
    private(set) var agentSummary = AgentSummary.idle
    /// 干活小场景：换场景至少隔 3 秒（见 AgentSceneHold）
    private var sceneHold = AgentSceneHold.none
    private var sceneRecheck: DispatchWorkItem?
    /// 搜索时追着球跑来跑去（见 PetChaseRunner）
    private var chaseRunner: PetChaseRunner?
    var isChasing: Bool { chaseRunner?.isRunning == true }
    /// 追球或往回跑时窗口位置是临时的，不存
    private var isChaseMovingWindow: Bool { isChasing || chaseRunner?.isReturning == true }
    /// 正在追的那个场景：往回跑的路上接着放它的跑步帧
    private var chasedActivity: AgentActivity?
    /// 打扰分级：在等你 > 健康提醒 > 干完了 / 出错了；你不在、全屏时压着（见 PetAttentionCoordinator）
    private let attention = PetAttentionCoordinator()
    /// 健康提醒：屏幕中央的提醒卡 + 护眼时盖住屏幕的全屏休息；挂着的时候桌宠跟着做动作
    let reminderStage = ReminderStagePresenter()
    let eyeRest = EyeRestOverlayController()
    private var reminderScene: PetScene?
    /// 点了「知道了」的那个会话；它还在等时不再弹卡片，不等了就清掉
    private var dismissedWait: String?
    /// 每秒报一次你多久没碰键盘鼠标（使用时长统计）
    var onUserIdleChecked: ((TimeInterval) -> Void)?
    /// 「跳过去」：把那个终端叫到前台
    var activateApp: (String) -> Void = DesktopPetWindowController.activateApplication
    private lazy var contextMenuController = ContextMenuPanelController { [weak self] action in
        self?.handleMenuAction(action)
    }

    init(
        workSessionController: WorkSessionController,
        reminderScheduler: ReminderScheduler,
        healthTracker: HealthSessionTracker,
        assetLocator: PetAssetLocator,
        petID: String,
        onQuitRequested: @escaping () -> Void,
        edgeSnapSettings: EdgeSnapSettings = .default,
        onOpenSettingsRequested: @escaping () -> Void = {},
        onOpenWardrobeRequested: @escaping () -> Void = {},
        todaySummaryProvider: @escaping () -> MenuTodaySummary? = { nil },
        todayReportProvider: @escaping () -> TodayReportContent? = { nil },
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.onOpenSettingsRequested = onOpenSettingsRequested
        self.onOpenWardrobeRequested = onOpenWardrobeRequested
        self.todaySummaryProvider = todaySummaryProvider
        self.workSessionController = workSessionController
        self.reminderScheduler = reminderScheduler
        self.healthTracker = healthTracker
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
        configureAttention()
        petView.onPetDragEnded = { [weak self] in
            self?.persistCurrentWindowPlacement()
            self?.edgeDock?.dragEnded()
            self?.faceHome()
            // 还在搜：从放下的地方接着追
            self?.updateChase()
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
        window.menuSummaryProvider = todaySummaryProvider

        // 「今日报告…」由 ContextMenuPanelController 从菜单里直接拦下弹面板，这里只喂数据；
        // 今天没记录就只让桌宠说一句（和菜单栏那条提示同一句话）
        contextMenuController.todayReportProvider = todayReportProvider
        contextMenuController.petFrameProvider = { [weak self] in self?.petBodyFrameOnScreen() }
        contextMenuController.onEmptyReport = { [weak self] in
            self?.petView.showTransientMessage(TextCatalog.shared.text("app.report_empty"))
        }

        applyCurrentStateToView(showBubble: true)
        persistCurrentWindowPlacement()
        window.makeKeyAndOrderFront(nil)
        edgeDock?.restoreAfterLaunch()
        faceHome()
    }

    /// 放下来 / 刚启动：朝着屏幕中间蹲（右半边朝左，左半边朝右）；贴在左右边时朝向归贴边管
    private func faceHome() {
        guard edgeDock?.dock.horizontal == nil,
              let body = petBodyFrameOnScreen(),
              let home = gaze?.homeFacingRight(body: body)
        else { return }
        petView.setFacingRight(home)
    }

    private func petBodyFrameOnScreen() -> CGRect? {
        guard let body = petView.petBodyRect, let origin = window?.frame.origin else { return nil }
        return body.offsetBy(dx: origin.x, dy: origin.y)
    }

    /// 转头看鼠标；贴在左右屏幕边时朝向归贴边管（脸朝屏幕里）
    private func configureGaze(window: NSWindow) {
        let gaze = PetGazeController(
            bodyFrameOnScreen: { [weak self] in self?.petBodyFrameOnScreen() },
            isFacingRight: { [weak petView] in petView?.isFacingRight ?? false },
            onTurn: { [weak petView] facingRight in petView?.turn(toFacingRight: facingRight) }
        )
        gaze.canTurn = { [weak self] in
            guard let self, self.petView.canTurnTowardCursor else { return false }
            return self.isFacingUpToThePet
        }
        self.gaze = gaze
        // 戳太多下生气了：扭过身去背对你；气消了（这段放完）转头看鼠标那套会再把它转回来
        petView.onPokeReaction = { [weak self] clip, pokedFromRight in
            guard let self, clip == .grumpy, self.isFacingUpToThePet else { return }
            self.petView.turn(toFacingRight: !pokedFromRight)
        }
    }

    /// 朝向能不能由桌宠自己定：贴在左右屏幕边时归贴边管（脸朝屏幕里）
    private var isFacingUpToThePet: Bool {
        guard let edgeDock else { return true }
        return edgeDock.dock.horizontal == nil && !edgeDock.isHidden
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
        edgeDock.onPeekFlinch = { [weak petView] in
            petView?.flinchPeek()
        }
        edgeDock.onDockedOriginSettled = { [weak self] origin in
            self?.persistWindowPlacement(origin)
        }
        petView.onPetDragStarted = { [weak self, weak edgeDock] in
            // 被拎起来就不追了，留在手里（往回跑的路上被拎起来，跑步帧也停）
            self?.chaseRunner?.stop(returnHome: false)
            if let self { self.petView.setScene(self.sceneToShow(work: self.sceneHold.shown)) }
            edgeDock?.dragStarted()
        }
        petView.onPointerEntered = { [weak edgeDock] in edgeDock?.pointerEntered() }
        petView.onPointerExited = { [weak edgeDock] in edgeDock?.pointerExited() }
        self.edgeDock = edgeDock
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 关桌宠窗口时，屏幕中央的提醒卡和全屏休息也一起收掉
    override func close() {
        putReminderAway()
        super.close()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 提醒到点：交给打扰分级决定现在弹、等会儿弹还是跳过
    func presentReminder(payload: ReminderPresentationPayload) {
        attention.reminderDue(payload)
    }

    /// 全屏（看视频、演示）时除了「在等你」都先压着
    func setFullscreen(_ fullscreen: Bool) {
        attention.fullscreenChanged(fullscreen)
    }

    private func configureAttention() {
        attention.onReminderReady = { [weak self] payload in self?.showReminder(payload) }
        attention.onReminderWithdrawn = { [weak self] in self?.putReminderAway() }
        attention.onDigest = { [weak self] message in
            // 卡片上已经写着谁在等你了，不再冒一句盖住它
            guard let self, !self.petView.isShowingWaitCard else { return }
            self.petView.showTransientMessage(message, duration: PetAttentionCoordinator.digestDuration)
        }
        attention.onStageChanged = { [weak self] in self?.applyAgentScene() }
        petView.onSceneFinished = { [weak self] scene in self?.attention.sceneFinished(scene) }
        petView.behavior.onUserLeft = { [weak self] in self?.attention.userLeft() }
        petView.behavior.onUserReturned = { [weak self] in self?.attention.userReturned() }
        petView.behavior.onUserIdleChecked = { [weak self] idle in self?.onUserIdleChecked?(idle) }
    }

    private func showReminder(_ payload: ReminderPresentationPayload) {
        let now = nowProvider()
        do {
            try healthTracker.recordReminderShown(payload, at: now)
        } catch {
            logHealthError("record reminder shown", error: error)
        }

        let cups = payload.type == .hydration ? todaySummaryProvider().map(CupProgress.init(summary:)) : nil
        let content = ReminderCardContent(payload: payload, cups: cups)
        reminderScene = content.scene
        applyAgentScene()
        reminderStage.show(
            content: content,
            petImage: { [weak petView] elapsed in petView?.sceneImage(content.scene, after: elapsed) },
            onAction: { [weak self] outcome in self?.handleReminderChoice(outcome, content: content, payload: payload) }
        )
    }

    /// 提醒卡上点了按钮。护眼的主按钮不是直接完成：先全屏休息，歇完（或提前结束）再记结果
    private func handleReminderChoice(_ outcome: HealthReminderOutcome, content: ReminderCardContent, payload: ReminderPresentationPayload) {
        guard outcome == .completed, content.startsRest else {
            handleReminderOutcome(outcome, for: payload)
            return
        }
        attention.reminderRestStarted(payload.id)
        eyeRest.start(
            content: content,
            petImage: { [weak petView] elapsed in petView?.napImage(after: elapsed) },
            onFinish: { [weak self] rested in self?.handleReminderOutcome(rested, for: payload) }
        )
    }

    /// 提醒被「在等你」盖过：卡片收起来，桌宠不再跟着做动作（之后会重新弹）
    private func putReminderAway() {
        reminderStage.dismiss()
        eyeRest.cancel()
        reminderScene = nil
    }

    /// 现在该演的场景：健康提醒挂着就跟着做动作，否则按 Agent 的状态来
    private func sceneToShow(work: AgentActivity?) -> PetScene? {
        reminderScene ?? attention.stage.scene(work: work)
    }

    func setPetID(_ petID: String) {
        petView.setPetID(petID)
    }

    /// 衣柜换装后换整套帧（nil = 默认橙子）
    func setOutfit(_ outfit: String?) {
        petView.setOutfit(outfit)
    }

    func windowDidMove(_ notification: Notification) {
        // 拖拽中每个事件都会移动窗口，等松手（onPetDragEnded）再落盘；
        // 吸边 / 藏边动画的中间位置也不保存（贴好后由 onDockedOriginSettled 保存）
        // 追球时跑来跑去的位置也不保存（停下会回原位）
        guard !petView.isDraggingPet, edgeDock?.isManagingWindowPosition != true, !isChaseMovingWindow else { return }
        persistCurrentWindowPlacement()
    }

    private func currentMenuModel() -> DesktopPetMenuModel {
        DesktopPetMenuModel(state: workSessionController.state, claudeConnection: claudeConnection())
    }

    /// Agent 状态变了：状态条优先显示它（在等你、干完了……），没事时回到平时的状态
    func setAgentSummary(_ summary: AgentSummary) {
        guard summary != agentSummary else { return }
        agentSummary = summary
        // 先让打扰分级收起被盖过的提醒卡、挑好场景，再挂在等你的卡片
        attention.agentChanged(summary)
        updateWaitCard()
    }

    /// 在等你：头顶挂卡片（谁在等、等什么、跳过去）；点了「知道了」这一次就不再挂
    private func updateWaitCard() {
        if agentSummary.kind != .waiting {
            dismissedWait = nil
        }
        guard let content = AgentWaitCardContent(summary: agentSummary), let key = waitKey, key != dismissedWait else {
            petView.hideWaitCard()
            return
        }
        petView.showWaitCard(content, onJump: { [weak self] bundleID in
            self?.activateApp(bundleID)
            self?.dismissedWait = key
            self?.petView.hideWaitCard()
        }, onDismiss: { [weak self] in
            self?.dismissedWait = key
            self?.petView.hideWaitCard()
        })
    }

    /// 按会话认：同一次等待里还会来补充通知（PermissionRequest 之后的 permission_prompt），记录时间会变
    private var waitKey: String? {
        agentSummary.lead?.id ?? (agentSummary.kind == .waiting ? "waiting" : nil)
    }

    /// 先请那个 App 自己到前台；系统不让（ICU 不在前台时可能被拒）就经 LaunchServices 打开它
    static func activateApplication(bundleID: String) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.activate() == true { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSLog("[ICUShell] could not find \(bundleID) to jump to")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { NSLog("[ICUShell] could not open \(bundleID): \(error.localizedDescription)") }
        }
    }

    /// 按 Agent 正在干的活换小场景；刚换过不到 3 秒就等够了再换
    private func applyAgentScene() {
        sceneRecheck?.cancel()
        sceneRecheck = nil
        let (hold, recheckAfter) = sceneHold.updated(desired: agentSummary.activity, at: ProcessInfo.processInfo.systemUptime)
        sceneHold = hold
        updateChase()
        // 不追了但还在往回跑：接着放跑步帧，到家再换
        if chaseRunner?.isReturning == true, let chasedActivity {
            petView.setScene(.work(chasedActivity))
        } else {
            petView.setScene(sceneToShow(work: hold.shown))
        }
        // 字跟着画面换（画面要停够 3 秒，字也一样）；字没变时 setStatusText 什么都不做
        petView.setStatusText(statusText(for: workSessionController.state))
        guard let recheckAfter else { return }
        let recheck = DispatchWorkItem { [weak self] in self?.applyAgentScene() }
        sceneRecheck = recheck
        DispatchQueue.main.asyncAfter(deadline: .now() + recheckAfter, execute: recheck)
    }

    /// 正在演追球（搜索）就让窗口跑起来；贴在边上、藏起来、被拎着时不跑。停下小跑回原位，到家再朝回屏幕中间
    private func updateChase() {
        // 健康提醒挂着时在原地做动作，不追球
        let chasing = reminderScene == nil && (sceneHold.shown.map { petView.workPlayer.scenes?.chases(.work($0)) == true } ?? false)
        let free = edgeDock.map { $0.dock == .none && !$0.isHidden } ?? true
        let shouldRun = chasing && free && !petView.isDraggingPet
        guard shouldRun != isChasing, let window else { return }
        if shouldRun {
            let runner = chaseRunner ?? PetChaseRunner(window: window)
            runner.onFacingChanged = { [weak petView] facingRight in petView?.setFacingRight(facingRight) }
            runner.onReturnedHome = { [weak self] in
                self?.faceHome()
                self?.applyAgentScene()
            }
            chaseRunner = runner
            chasedActivity = sceneHold.shown
            runner.start()
        } else {
            chaseRunner?.stop()
        }
    }

    private func handleMenuAction(_ action: DesktopPetMenuAction) {
        do {
            let oldState = workSessionController.state
            let now = nowProvider()
            var transientMessage: String?

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
                transientMessage = DesktopPetCopy.stopWorkMessage()
            case .openSettings:
                onOpenSettingsRequested()
                return
            case .openWardrobe:
                onOpenWardrobeRequested()
                return
            // 「今日报告…」在 ContextMenuPanelController 里就被拦下弹了报告面板，走不到这里；
            // Swift 要求 switch 穷尽，只能在这里占个位
            case .showTodayReport:
                return
            case .connectClaude:
                onClaudeConnectionChange(true)
                return
            case .disconnectClaude:
                onClaudeConnectionChange(false)
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

    private func handleReminderOutcome(_ outcome: HealthReminderOutcome, for payload: ReminderPresentationPayload) {
        let now = nowProvider()
        putReminderAway()
        applyCurrentStateToView(showBubble: false)
        defer { attention.reminderClosed(payload.id) }

        do {
            try healthTracker.recordReminderOutcome(for: payload, outcome: outcome, at: now)
        } catch {
            logHealthError("record reminder outcome", error: error)
        }

        if outcome == .snoozed {
            let followUpPayload = ReminderPresentationPayload(
                id: UUID(),
                type: payload.type,
                text: payload.text,
                restSeconds: payload.restSeconds
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

    private func applyCurrentStateToView(showBubble: Bool = false) {
        petView.setWorkState(workSessionController.state)
        petView.setStatusText(statusText(for: workSessionController.state), showBubble: showBubble)
    }

    private func statusText(for state: ShellWorkState) -> String {
        agentStatusText ?? DesktopPetCopy.statusText(for: state)
    }

    /// 干活时字跟着画面：画面还停在上一种活（不到 3 秒）就说上一种活；同一种活里换了工具，字马上换
    private var agentStatusText: String? {
        guard let shown = sceneHold.shown else { return agentSummary.statusText }
        guard agentSummary.activity == shown, let text = agentSummary.statusText else { return shown.label }
        return text
    }

    /// 在桌宠旁边冒一句话（比如接入 Claude Code 失败的原因）
    func showMessage(_ text: String, duration: TimeInterval = 3) {
        petView.showTransientMessage(text, duration: duration)
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
        case .card:
            targetSize = DesktopPetView.cardExpandedContentSize
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
    var menuSummaryProvider: (() -> MenuTodaySummary?)?

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
            summary: menuSummaryProvider?() ?? nil,
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
