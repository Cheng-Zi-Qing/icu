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
                }
            )
            petWindowController?.setOutfit(wardrobe.outfitID)
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

        statusMenuController?.toggle(from: button, model: StatusItemMenuModel(), summary: todaySummary())
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func handleStatusMenuAction(_ action: StatusItemMenuAction) {
        switch action {
        case .showPet:
            showPet()
        case .openWardrobe:
            wardrobe?.open()
        case .openSettings:
            openSettings()
        case .quitApp:
            quit()
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
        guard let healthTracker, let settingsStore else { return nil }
        do {
            let day = try healthTracker.todayReport(at: .now)
            return MenuTodaySummary(day: day, cupsGoal: HydrationPlan(profile: settingsStore.loadHealthProfile()).cups)
        } catch {
            NSLog("[ICUShell] failed to read today's health summary: \(error.localizedDescription)")
            return nil
        }
    }
}
