import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindowController: DesktopPetWindowController?
    private var statusItem: NSStatusItem?
    private var appPaths: AppPaths?
    private var stateStore: StateStore?
    private var workSessionController: WorkSessionController?
    private var reminderScheduler: ReminderScheduler?
    private var avatarCoordinator: AvatarCoordinator?
    private var generationSettingsStore: GenerationSettingsStore?
    private var themeManager: ThemeManager?
    private var generationCoordinator: GenerationCoordinator?
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
            setenv("ICU_APP_SUPPORT_ROOT", paths.rootURL.path, 1)
            TextCatalog.installShared(try TextCatalog.live(appPaths: paths, repoRootURL: assetLocator.repoRootURL))
            let generationSettingsStore = GenerationSettingsStore(
                appPaths: paths,
                repoRootURL: assetLocator.repoRootURL
            )
            let themeManager = try ThemeManager(appPaths: paths, settingsStore: generationSettingsStore)
            ThemeManager.installShared(themeManager)
            let generationService = ThemeGenerationService(
                settingsStore: generationSettingsStore,
                themeManager: themeManager
            )
            let speechGenerationService = SpeechGenerationService(
                settingsStore: generationSettingsStore
            )
            let copyOverrideStore = CopyOverrideStore(
                appPaths: paths,
                repoRootURL: assetLocator.repoRootURL
            )
            let generationCoordinator = GenerationCoordinator(
                settingsStore: generationSettingsStore,
                themeManager: themeManager,
                generationService: generationService,
                speechGenerationService: speechGenerationService,
                copyOverrideStore: copyOverrideStore
            )
            let avatarSettingsStore = AvatarSettingsStore(
                appPaths: paths,
                repoRootURL: assetLocator.repoRootURL
            )
            let avatarCatalog = AvatarCatalog(
                repoRootURL: assetLocator.repoRootURL,
                appAssetsRootURL: paths.assetsDirectory
            )
            let avatarAssetStore = AvatarAssetStore(repoRootURL: assetLocator.repoRootURL)
            let bridgeScriptURL = (assetLocator.repoRootURL
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
                .appendingPathComponent("tools", isDirectory: true)
                .appendingPathComponent("avatar_builder_bridge.py", isDirectory: false)
            let avatarBridge = AvatarBuilderBridge(scriptURL: bridgeScriptURL)
            let avatarCoordinator = AvatarCoordinator(
                settingsStore: avatarSettingsStore,
                catalog: avatarCatalog,
                assetStore: avatarAssetStore,
                bridge: avatarBridge,
                generationCoordinator: generationCoordinator
            )
            let petID = avatarCoordinator.currentAvatarID(
                fallback: ProcessInfo.processInfo.environment["ICU_PET_ID"] ?? "capybara"
            )
            let scheduler = ReminderScheduler { [weak self] in
                self?.petWindowController?.presentReminder(text: DesktopPetCopy.eyeReminderMessage())
            }

            self.appPaths = paths
            self.stateStore = store
            self.workSessionController = sessionController
            self.reminderScheduler = scheduler
            self.avatarCoordinator = avatarCoordinator
            self.generationSettingsStore = generationSettingsStore
            self.themeManager = themeManager
            self.generationCoordinator = generationCoordinator
            self.statusMenuController = StatusMenuPanelController { [weak self] action in
                self?.handleStatusMenuAction(action)
            }

            petWindowController = DesktopPetWindowController(
                workSessionController: sessionController,
                reminderScheduler: scheduler,
                assetLocator: assetLocator,
                petID: petID,
                avatarCoordinator: avatarCoordinator,
                generationCoordinator: generationCoordinator,
                onQuitRequested: { [weak self] in
                    self?.quit()
                }
            )
            avatarCoordinator.onCurrentAvatarChanged = { [weak self] avatarID in
                self?.petWindowController?.setPetID(avatarID)
            }
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

    @objc private func changeAvatar() {
        avatarCoordinator?.presentAvatarPicker()
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
        case .changeAvatar:
            changeAvatar()
        case .openStudio:
            avatarCoordinator?.presentStudio(target: .theme)
        case .openGenerationConfig:
            _ = generationCoordinator?.openGenerationConfig()
        case .quitApp:
            quit()
        }
    }
}
