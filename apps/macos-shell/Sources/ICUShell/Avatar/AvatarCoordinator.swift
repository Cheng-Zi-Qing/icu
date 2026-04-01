import AppKit

final class AvatarCoordinator {
#if MANUAL_RUNTIME_TESTS
    enum PickerExitAction {
        case choose
        case createNew
        case close
    }
#endif

    private let settingsStore: AvatarSettingsStore
    private let catalog: AvatarCatalog
    private let assetStore: AvatarAssetStore
    private let bridge: AvatarBuilderBridge
    private let generationCoordinator: GenerationCoordinator?
    private var pickerController: AvatarPickerWindowController?
    private var studioController: StudioWindowController?
    var onCurrentAvatarChanged: ((String) -> Void)?
#if MANUAL_RUNTIME_TESTS
    private(set) var lastPickerExitAction: PickerExitAction?
    private(set) var lastRequestedStudioTarget: StudioLaunchTarget?
#endif

    init(
        settingsStore: AvatarSettingsStore,
        catalog: AvatarCatalog,
        assetStore: AvatarAssetStore,
        bridge: AvatarBuilderBridge,
        generationCoordinator: GenerationCoordinator? = nil
    ) {
        self.settingsStore = settingsStore
        self.catalog = catalog
        self.assetStore = assetStore
        self.bridge = bridge
        self.generationCoordinator = generationCoordinator
    }

    func presentAvatarPicker() {
        do {
            let avatars = try catalog.loadAvatars()
            guard !avatars.isEmpty else {
                throw AvatarBuilderBridgeError.executionFailed(command: "load-avatars", details: "no avatars found")
            }

            let controller = AvatarPickerWindowController(
                avatars: avatars,
                currentAvatarID: try settingsStore.loadCurrentAvatarID(),
                onChoose: { [weak self] avatarID in
#if MANUAL_RUNTIME_TESTS
                    self?.lastPickerExitAction = .choose
#endif
                    try self?.applyAvatarSelection(avatarID)
                    self?.pickerController = nil
                },
                onCreateNew: { [weak self] in
#if MANUAL_RUNTIME_TESTS
                    self?.lastPickerExitAction = .createNew
#endif
                    self?.pickerController = nil
                    self?.presentStudio(target: .avatarBrowse)
                },
                onClose: { [weak self] in
#if MANUAL_RUNTIME_TESTS
                    self?.lastPickerExitAction = .close
#endif
                    self?.pickerController = nil
                }
            )
            pickerController = controller
            controller.present()
        } catch {
            showError(error)
        }
    }

    func presentStudio(target: StudioLaunchTarget = .theme) {
        do {
#if MANUAL_RUNTIME_TESTS
            lastRequestedStudioTarget = target
#endif
            let avatars = try catalog.loadAvatars()
            guard !avatars.isEmpty else {
                throw AvatarBuilderBridgeError.executionFailed(command: "load-avatars", details: "no avatars found")
            }

            if let studioController {
                studioController.present(target: target)
                return
            }

            let controller = StudioWindowController(
                avatars: avatars,
                currentAvatarID: try settingsStore.loadCurrentAvatarID(),
                initialTarget: target,
                themePromptOptimizer: bridge.optimizePrompt,
                themeDraftGenerator: { [weak self] prompt in
                    guard let generationCoordinator = self?.generationCoordinator else {
                        throw GenerationRouteError.missingCapabilityConfig("theme_description")
                    }
                    return try generationCoordinator.generateThemeDraft(from: prompt)
                },
                themeDraftApplier: { [weak self] pack in
                    guard let generationCoordinator = self?.generationCoordinator else {
                        throw GenerationRouteError.missingCapabilityConfig("theme_description")
                    }
                    try generationCoordinator.applyThemeDraft(pack)
                },
                avatarPromptOptimizer: bridge.optimizePrompt,
                avatarSaveHandler: { [weak self] request in
                    guard let assetStore = self?.assetStore else {
                        throw AvatarBuilderBridgeError.executionFailed(command: "save-avatar", details: "asset store unavailable")
                    }
                    return try assetStore.saveCustomAvatar(
                        name: request.name,
                        persona: request.persona,
                        generatedActionImageURLs: request.actionImageURLs
                    )
                },
                onChooseAvatar: { [weak self] avatarID in
                    try self?.applyAvatarSelection(avatarID)
                },
                onOpenAvatarPicker: { [weak self] in
                    self?.presentAvatarPicker()
                },
                speechDraftGenerator: { [weak self] prompt in
                    guard let generationCoordinator = self?.generationCoordinator else {
                        throw GenerationRouteError.missingCapabilityConfig("text_description")
                    }
                    return try generationCoordinator.generateSpeechDraft(from: prompt)
                },
                speechDraftApplier: { [weak self] draft in
                    guard let generationCoordinator = self?.generationCoordinator else {
                        throw GenerationRouteError.missingCapabilityConfig("text_description")
                    }
                    try generationCoordinator.applySpeechDraft(draft)
                },
                onClose: { [weak self] in
                    self?.studioController = nil
                }
            )
            studioController = controller
            controller.present()
        } catch {
            showError(error)
        }
    }

    func availableAvatars() throws -> [AvatarSummary] {
        try catalog.loadAvatars()
    }

    func currentAvatarID(fallback: String) -> String {
        (try? settingsStore.loadCurrentAvatarID()) ?? fallback
    }

    func applyAvatarSelection(_ avatarID: String) throws {
        try settingsStore.saveCurrentAvatarID(avatarID)
        try refreshAvatarControllers(selectedAvatarID: avatarID)
        onCurrentAvatarChanged?(avatarID)
    }

    private func refreshAvatarControllers(selectedAvatarID: String) throws {
        let avatars = try catalog.loadAvatars()
        pickerController?.updateAvatars(avatars, currentAvatarID: selectedAvatarID)
        studioController?.updateAvatars(avatars, currentAvatarID: selectedAvatarID)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = TextCatalog.shared.text("avatar.error_unavailable_title", fallback: "形象功能暂不可用")
        alert.informativeText = UserFacingErrorCopy.avatarMessage(for: error)
        alert.addButton(withTitle: TextCatalog.shared.text("avatar.error_acknowledge_button", fallback: "知道了"))
        alert.runModal()
    }

}
