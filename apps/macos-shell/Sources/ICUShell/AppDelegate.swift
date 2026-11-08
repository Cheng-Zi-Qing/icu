import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindowController: DesktopPetWindowController?
    private var statusItem: NSStatusItem?
    private var appPaths: AppPaths?
    private var stateStore: StateStore?
    private var workSessionController: WorkSessionController?
    private var reminderScheduler: ReminderScheduler?
    private var themeManager: ThemeManager?
    private var statusMenuController: StatusMenuPanelController?

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
            let petID = ProcessInfo.processInfo.environment["ICU_PET_ID"] ?? "capybara"
            let hydrationPlan = HydrationPlan(profile: settingsStore.loadHealthProfile())
            let scheduler = ReminderScheduler(
                eyeInterval: settingsStore.loadReminderTimerSettings().eyeInterval,
                hydrationInterval: hydrationPlan.interval
            ) { [weak self] payload in
                self?.petWindowController?.presentReminder(payload: payload)
            }

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
                edgeSnapSettings: settingsStore.loadEdgeSnapSettings()
            )
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

        statusMenuController?.toggle(from: button, model: StatusItemMenuModel())
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func handleStatusMenuAction(_ action: StatusItemMenuAction) {
        switch action {
        case .showPet:
            showPet()
        case .quitApp:
            quit()
        }
    }
}
