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
                    self?.todayDayReport()
                },
                cupsGoalProvider: { [weak self] in
                    // AppDelegate 没了就用默认目标（和桌宠那边的默认值一致）
                    self?.cupsGoal() ?? HydrationPlan(profile: HealthProfile.default).cups
                }
            )
            petWindowController?.setOutfit(wardrobe.outfitID)
            configureClaudeCode(paths: paths)
            petWindowController?.showWindow(nil)
        } catch {
            NSLog("[ICUShell] failed to bootstrap runtime: \(error.localizedDescription)")
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
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

        statusMenuController?.toggle(from: button, model: StatusItemMenuModel(claudeConnection: claudeConnection()), summary: todaySummary())
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// 「今日报告…」：今天一条记录都没有就只让桌宠说一句，不弹面板
    private func presentTodayReport() {
        guard let button = statusItem?.button, let report = todayDayReport() else {
            return
        }

        guard report.hasActivity else {
            petWindowController?.showMessage("今天还没有记录")
            return
        }

        statusMenuController?.presentTodayReport(from: button, report: report, cupsGoal: cupsGoal())
    }

    private func handleStatusMenuAction(_ action: StatusItemMenuAction) {
        switch action {
        case .showPet:
            showPet()
        case .showTodayReport:
            presentTodayReport()
        case .openWardrobe:
            wardrobe?.open()
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

    // MARK: - Claude Code

    /// 读 icu-hook 写下的会话状态，交给桌宠表现；菜单里能接入 / 断开
    private func configureClaudeCode(paths: AppPaths) {
        let installer = ClaudeHookInstaller.live(appPaths: paths)
        claudeInstaller = installer
        refreshInstalledHook(installer)
        let monitor = AgentStatusMonitor(reader: AgentDirectoryReader(appPaths: paths))
        monitor.onChange = { [weak self] summary in
            self?.petWindowController?.setAgentSummary(summary)
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
                petWindowController?.showMessage("接上 Claude Code 了，新开的会话就能看到")
            } else {
                try claudeInstaller.uninstall(now: .now)
                petWindowController?.showMessage("和 Claude Code 断开了")
            }
            agentMonitor?.reload()
        } catch let error as ClaudeHookInstallerError {
            petWindowController?.showMessage(error.userMessage, duration: 4)
        } catch {
            NSLog("[ICUShell] Claude Code hook \(connect ? "install" : "uninstall") failed: \(error.localizedDescription)")
            petWindowController?.showMessage("没弄成，稍后再试试", duration: 4)
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
        let controller = SettingsWindowController(form: form, decoration: wardrobe?.decoration) { [weak self] form in
            try self?.applySettings(form)
        }
        settingsWindowController = controller
        controller.present()
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
