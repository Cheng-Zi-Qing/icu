import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindowController: DesktopPetWindowController?
    private var statusItem: NSStatusItem?
    private var appPaths: AppPaths?
    private var stateStore: StateStore?
    private var workSessionController: WorkSessionController?
    private var reminderScheduler: ReminderScheduler?
    private var themeManager: ThemeManager?
    private var statusMenuController: StatusMenuPanelController?
    private var settingsStore: AppSettingsStore?
    private var settingsWindowController: SettingsWindowController?
    private var wardrobe: WardrobeCoordinator?
    private var agentMonitor: AgentStatusMonitor?
    private var claudeInstaller: ClaudeHookInstaller?
    private var healthTracker: HealthSessionTracker?
    private var loot: LootCoordinator?
    private var backpackWindow: BackpackWindowController?
    private let fullscreenMonitor = FullscreenMonitor()
    private var usageRecorder: UsageRecorder?
    private var dutyClock: Timer?
    private var sleepObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarMenu()

        do {
            let paths = try AppPaths.live()
            let assetLocator = PetAssetLocator(appPaths: paths)
            RuntimeLaunchDiagnostics.emit(
                appPaths: paths,
                repoRootURL: assetLocator.repoRootURL,
                bundleResourceURL: Bundle.main.resourceURL
            )

            let store = try StateStore(paths: paths)
            let sessionController = try WorkSessionController(store: store)
            let healthMetricsStore = try HealthMetricsStore(appPaths: paths)
            let healthTracker = HealthSessionTracker(store: healthMetricsStore)
            // 上次被强退 / 崩溃时还在上班：补上下班打卡（启动后回到发呆，要接着上班就再点「我要上班」）
            do {
                let closed = try healthTracker.closeInterruptedShifts()
                if closed > 0 { NSLog("[ICUShell] closed \(closed) shift(s) left open by an unexpected quit") }
            } catch {
                NSLog("[ICUShell] failed to close shifts left open by an unexpected quit: \(error.localizedDescription)")
            }
            setenv("ICU_APP_SUPPORT_ROOT", paths.rootURL.path, 1)
            TextCatalog.installShared(try TextCatalog.live(appPaths: paths, repoRootURL: assetLocator.repoRootURL))
            let themeManager = ThemeManager()
            ThemeManager.installShared(themeManager)
            let settingsStore = AppSettingsStore(appPaths: paths, repoRootURL: assetLocator.repoRootURL)
            PixelFont.register(assetsDirectory: assetLocator.repoRootURL?.appendingPathComponent("assets", isDirectory: true))
            let petID = ProcessInfo.processInfo.environment["ICU_PET_ID"] ?? "capybara"
            self.settingsStore = settingsStore
            self.healthTracker = healthTracker
            let wardrobe = WardrobeCoordinator(
                catalogURL: assetLocator.repoRootURL?.appendingPathComponent("config/wardrobe.json", isDirectory: false),
                store: WardrobeStore(appPaths: paths),
                makeArt: { WardrobeArt.live(locator: assetLocator, petID: petID, catalog: $0) },
                onOutfitChanged: { [weak self] outfit in
                    self?.petWindowController?.setOutfit(outfit)
                }
            )
            self.wardrobe = wardrobe
            let hydrationPlan = HydrationPlan(profile: settingsStore.loadHealthProfile())
            let timers = settingsStore.loadReminderTimerSettings()
            let scheduler = ReminderScheduler(
                eyeInterval: timers.eyeInterval,
                hydrationInterval: hydrationPlan.interval
            ) { [weak self] payload in
                self?.petWindowController?.presentReminder(payload: payload)
            }
            scheduler.updateIntervals(eye: timers.eyeInterval, hydration: hydrationPlan.interval, eyeRest: timers.eyeRestSeconds)

            self.appPaths = paths
            self.stateStore = store
            self.workSessionController = sessionController
            self.reminderScheduler = scheduler
            self.themeManager = themeManager
            self.statusMenuController = StatusMenuPanelController { [weak self] action in
                self?.handleStatusMenuAction(action)
            }

            petWindowController = DesktopPetWindowController(
                workSessionController: sessionController,
                reminderScheduler: scheduler,
                healthTracker: healthTracker,
                assetLocator: assetLocator,
                petID: petID,
                onQuitRequested: { [weak self] in
                    self?.quit()
                },
                edgeSnapSettings: settingsStore.loadEdgeSnapSettings(),
                onOpenSettingsRequested: { [weak self] in
                    self?.openSettings()
                },
                onOpenWardrobeRequested: { [weak self] in
                    self?.wardrobe?.open()
                },
                todaySummaryProvider: { [weak self] in
                    self?.todaySummary()
                },
                todayReportProvider: { [weak self] in
                    self?.todayReportContent()
                }
            )
            petWindowController?.setOutfit(wardrobe.outfitID)
            configureClaudeCode(paths: paths)
            configureFullscreenQuiet()
            configureUsageRecording(paths: paths)
            configureLoot(paths: paths, metrics: healthMetricsStore, repoRootURL: assetLocator.repoRootURL)
            configureDutyClock()
            petWindowController?.showWindow(nil)
        } catch {
            NSLog("[ICUShell] failed to bootstrap runtime: \(error.localizedDescription)")
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        dutyClock?.invalidate()
        sleepObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        // 还在上班就退出：当成下班，把最后一段记上
        do {
            try healthTracker?.endSession(at: .now)
        } catch {
            NSLog("[ICUShell] failed to settle the work day on quit: \(error.localizedDescription)")
        }
        fullscreenMonitor.stop()
        reminderScheduler?.stop()
        petWindowController?.close()
    }

    // MARK: - Status Bar（右键菜单入口，Spike 用）

    private func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.title = "🐾"
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(toggleStatusPanel)
    }

    @objc private func showPet() {
        petWindowController?.showWindow(nil)
    }

    @objc private func toggleStatusPanel() {
        guard let button = statusItem?.button else {
            return
        }

        statusMenuController?.toggle(from: button, model: StatusItemMenuModel(claudeConnection: claudeConnection(), showsBackpack: loot != nil), summary: todaySummary())
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// 「今日报告…」：今天一条记录都没有就只让桌宠说一句，不弹面板
    private func presentTodayReport() {
        guard let button = statusItem?.button, let content = todayReportContent() else {
            return
        }

        guard content.hasActivity else {
            petWindowController?.showMessage(TextCatalog.shared.text("app.report_empty"))
            return
        }

        statusMenuController?.presentTodayReport(from: button, content: content)
    }

    private func handleStatusMenuAction(_ action: StatusItemMenuAction) {
        switch action {
        case .showPet:
            showPet()
        case .showTodayReport:
            presentTodayReport()
        case .openWardrobe:
            wardrobe?.open()
        case .openBackpack:
            openBackpack()
        case .openSettings:
            openSettings()
        case .connectClaude:
            setClaudeConnected(true)
        case .disconnectClaude:
            setClaudeConnected(false)
        case .quitApp:
            quit()
        }
    }

    // MARK: - 上班时长

    /// 上班时长每分钟入一次账（报告里总是最新的，意外退出最多丢一分钟）；电脑睡着的时间不算上班
    private func configureDutyClock() {
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkpointDuty() }
        }
        RunLoop.main.add(timer, forMode: .common)
        dutyClock = timer

        let center = NSWorkspace.shared.notificationCenter
        sleepObservers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspendDuty() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.healthTracker?.resume(at: .now)
                    self?.loot?.resetClock(at: .now)
                }
            },
        ]
    }

    private func checkpointDuty() {
        do {
            try healthTracker?.checkpoint(at: .now)
        } catch {
            NSLog("[ICUShell] failed to record work time: \(error.localizedDescription)")
        }
        loot?.tick(isOnDuty: (workSessionController?.state ?? .idle) != .idle, at: .now)
    }

    private func suspendDuty() {
        do {
            try healthTracker?.suspend(at: .now)
        } catch {
            NSLog("[ICUShell] failed to record work time before sleep: \(error.localizedDescription)")
        }
        loot?.tick(isOnDuty: (workSessionController?.state ?? .idle) != .idle, at: .now)
        loot?.resetClock(at: nil)
    }

    // MARK: - 宝箱掉落

    /// 完成提醒、专注、离开屏幕得宝箱，上班时孵化（PRD 2.1 Phase 1）。`loot_enabled` 关掉就整个不接
    private func configureLoot(paths: AppPaths, metrics: HealthMetricsStore, repoRootURL: URL?) {
        guard settingsStore?.loadLootEnabled() ?? true else {
            NSLog("[ICUShell] loot is turned off in settings")
            return
        }
        let config = LootCoordinator.loadConfig(directory: repoRootURL?.appendingPathComponent("config/loot", isDirectory: true))
        let hooks = LootCoordinator.Hooks(
            daySummary: { date in
                do {
                    return try metrics.daySummary(for: date)
                } catch {
                    NSLog("[ICUShell] loot could not read the day's health summary: \(error.localizedDescription)")
                    return nil
                }
            },
            goals: { [weak self] in
                let profile = self?.settingsStore?.loadHealthProfile() ?? .default
                return (HydrationPlan(profile: profile).cups, profile.workHours)
            },
            unownedOutfits: { [weak self] in self?.wardrobe?.unownedOutfits ?? [] },
            grantOutfit: { [weak self] id in self?.wardrobe?.grant(id) ?? false },
            canAnnounce: { [weak self] in self?.petWindowController?.canShowLootNotice ?? false },
            announce: { [weak self] text in self?.announceLoot(text) }
        )
        let loot = LootCoordinator(config: config, store: LootStore(appPaths: paths), hooks: hooks)
        loot.onChange = { [weak self] _ in self?.refreshBackpack() }
        healthTracker?.onActivity = { [weak loot] activity in loot?.handle(activity, at: .now) }
        petWindowController?.showsBackpack = true
        petWindowController?.onOpenBackpackRequested = { [weak self] in self?.openBackpack() }
        // 起个头：结算上次上班那天（要不要给黑匣），并开始计孵化时间
        loot.tick(isOnDuty: false, at: .now)
        self.loot = loot
    }

    /// 隔几秒再说：刚完成提醒、刚结束专注时桌宠自己有话（专注小结等），别被宝箱的话盖掉。
    /// 到时候不方便说话（进了专注、全屏）就不说了，背包里照样看得到
    private func announceLoot(_ text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.lootNoticeDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let pet = self?.petWindowController, pet.canShowLootNotice else { return }
                pet.showMessage(text, duration: 4)
            }
        }
    }

    private static let lootNoticeDelay: TimeInterval = 3.5

    private func openBackpack() {
        guard let loot else { return }
        let content = BackpackContent(state: loot.state, config: loot.config)
        if let backpackWindow {
            backpackWindow.update(content: content, decoration: wardrobe?.decoration)
            backpackWindow.present()
            return
        }
        let controller = BackpackWindowController(content: content, decoration: wardrobe?.decoration)
        controller.onClose = { [weak self] in self?.loot?.markAllSeen() }
        backpackWindow = controller
        controller.present()
    }

    private func refreshBackpack() {
        guard let loot, let backpackWindow, backpackWindow.isVisible else { return }
        backpackWindow.update(content: BackpackContent(state: loot.state, config: loot.config), decoration: wardrobe?.decoration)
    }

    // MARK: - Claude Code

    /// 后台记使用时长（你停顿多久、Claude 一段干多久），先攒着看分布，暂不用来调数值
    private func configureUsageRecording(paths: AppPaths) {
        let recorder = UsageRecorder(log: UsageSampleLog(appPaths: paths))
        usageRecorder = recorder
        petWindowController?.onUserIdleChecked = { [weak recorder] idle in recorder?.userIdleChecked(idle) }
        recorder.agentChanged(agentMonitor?.summary.kind ?? .idle)
    }

    /// 前台全屏（看视频、演示）时安静：除了「在等你」都先压着。只看窗口大小，不要权限
    private func configureFullscreenQuiet() {
        fullscreenMonitor.onChange = { [weak self] fullscreen in
            self?.petWindowController?.setFullscreen(fullscreen)
        }
        fullscreenMonitor.start()
    }

    /// 读 icu-hook 写下的会话状态，交给桌宠表现；菜单里能接入 / 断开
    private func configureClaudeCode(paths: AppPaths) {
        let installer = ClaudeHookInstaller.live(appPaths: paths)
        claudeInstaller = installer
        refreshInstalledHook(installer)
        let monitor = AgentStatusMonitor(reader: AgentDirectoryReader(appPaths: paths))
        monitor.onChange = { [weak self] summary in
            self?.petWindowController?.setAgentSummary(summary)
            self?.usageRecorder?.agentChanged(summary.kind)
        }
        agentMonitor = monitor
        petWindowController?.setAgentSummary(monitor.summary)
        petWindowController?.claudeConnection = { [weak self] in self?.claudeConnection() }
        petWindowController?.onClaudeConnectionChange = { [weak self] connect in self?.setClaudeConnected(connect) }
    }

    /// 已经接上的话，换成这个版本 app 自带的 icu-hook（比如新版开始记工具名）
    private func refreshInstalledHook(_ installer: ClaudeHookInstaller) {
        guard let binary = ClaudeHookInstaller.bundledHookBinary else { return }
        do {
            if try installer.refreshHookBinary(from: binary) {
                NSLog("[ICUShell] Updated the installed icu-hook to the bundled version")
            }
        } catch {
            NSLog("[ICUShell] Could not update the installed icu-hook: \(error.localizedDescription)")
        }
    }

    /// nil：没法接（找不到 icu-hook，也没装过），菜单里不显示
    private func claudeConnection() -> Bool? {
        guard let claudeInstaller else { return nil }
        if claudeInstaller.isInstalled { return true }
        let binary = ClaudeHookInstaller.bundledHookBinary
        return binary.map { FileManager.default.isExecutableFile(atPath: $0.path) } == true ? false : nil
    }

    private func setClaudeConnected(_ connect: Bool) {
        guard let claudeInstaller else { return }
        do {
            if connect {
                guard let binary = ClaudeHookInstaller.bundledHookBinary else { throw ClaudeHookInstallerError.missingHookBinary }
                try claudeInstaller.install(hookBinary: binary, now: .now)
                petWindowController?.showMessage(TextCatalog.shared.text("app.claude_connected"))
            } else {
                try claudeInstaller.uninstall(now: .now)
                petWindowController?.showMessage(TextCatalog.shared.text("app.claude_disconnected"))
            }
            agentMonitor?.reload()
        } catch let error as ClaudeHookInstallerError {
            petWindowController?.showMessage(error.userMessage, duration: 4)
        } catch {
            NSLog("[ICUShell] Claude Code hook \(connect ? "install" : "uninstall") failed: \(error.localizedDescription)")
            petWindowController?.showMessage(TextCatalog.shared.text("app.action_failed"), duration: 4)
        }
    }

    // MARK: - 设置

    private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.present()
            return
        }
        guard let settingsStore else { return }
        let form = SettingsForm(profile: settingsStore.loadHealthProfile(), timers: settingsStore.loadReminderTimerSettings())
        let controller = SettingsWindowController(
            form: form,
            language: settingsStore.loadLanguage(),
            decoration: wardrobe?.decoration,
            onSelectLanguage: { [weak self] language in
                self?.applyLanguage(language)
            }
        ) { [weak self] form in
            try self?.applySettings(form)
        }
        settingsWindowController = controller
        controller.present()
    }

    /// 换了界面语言：写进 settings.json，重读文案，再把已经开着的窗口重画一遍
    private func applyLanguage(_ language: AppLanguage) {
        do {
            try settingsStore?.saveLanguage(language)
            try TextCatalog.reloadShared(appPaths: appPaths, repoRootURL: PetAssetLocator.inferredRepoRoot())
            settingsWindowController?.reloadCopy()
        } catch {
            NSLog("[ICUShell] failed to switch language: \(error.localizedDescription)")
            settingsWindowController?.reloadCopy()
        }
    }

    /// 存进 settings.json，并让正在计时的提醒按新间隔重新计时
    private func applySettings(_ form: SettingsForm) throws {
        try settingsStore?.saveHealthProfile(form.profile)
        try settingsStore?.saveReminderTimerSettings(form.timers)
        reminderScheduler?.updateIntervals(
            eye: form.timers.eyeInterval,
            hydration: form.hydrationPlan.interval,
            eyeRest: form.timers.eyeRestSeconds
        )
    }

    /// 菜单顶上的今日小结；读不到统计时不显示
    private func todaySummary() -> MenuTodaySummary? {
        guard let day = todayDayReport() else { return nil }
        return MenuTodaySummary(day: day, cupsGoal: cupsGoal())
    }

    /// 今日报告：今天的数 + 结论 + 本机累计；读不到今天的统计就没有
    private func todayReportContent() -> TodayReportContent? {
        guard let healthTracker, let day = todayDayReport() else { return nil }
        let lifetime: HealthLifetimeSummary?
        do {
            lifetime = try healthTracker.lifetimeReport(at: .now)
        } catch {
            NSLog("[ICUShell] failed to read lifetime work totals: \(error.localizedDescription)")
            lifetime = nil
        }
        let week: HealthWeekSummary?
        do {
            week = try healthTracker.weekReport(containing: .now)
        } catch {
            NSLog("[ICUShell] failed to read this week's work totals: \(error.localizedDescription)")
            week = nil
        }
        let profile = settingsStore?.loadHealthProfile() ?? .default
        return TodayReportContent(
            day: day,
            lifetime: lifetime,
            cupsGoal: HydrationPlan(profile: profile).cups,
            workHours: profile.workHours,
            isOnDuty: (workSessionController?.state ?? .idle) != .idle,
            week: week
        )
    }

    private func todayDayReport() -> HealthDaySummary? {
        guard let healthTracker else { return nil }
        do {
            return try healthTracker.todayReport(at: .now)
        } catch {
            NSLog("[ICUShell] failed to read today's health summary: \(error.localizedDescription)")
            return nil
        }
    }

    private func cupsGoal() -> Int {
        guard let settingsStore else {
            return HydrationPlan(profile: HealthProfile.default).cups
        }
        return HydrationPlan(profile: settingsStore.loadHealthProfile()).cups
    }
}
