import AppKit

final class AvatarCoordinator {
    private let settingsStore: AvatarSettingsStore
    private let catalog: AvatarCatalog
    private let assetStore: AvatarAssetStore
    private let bridge: AvatarBuilderBridge
    private let generationCoordinator: GenerationCoordinator?
    private var selectorController: AvatarSelectorWindowController?
    private var wizardController: AvatarWizardWindowController?
    var onCurrentAvatarChanged: ((String) -> Void)?

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

            let controller = AvatarSelectorWindowController(
                avatars: avatars,
                currentAvatarID: try settingsStore.loadCurrentAvatarID(),
                themePromptOptimizer: { [bridge] prompt in
                    try bridge.optimizePrompt(prompt)
                },
                themeDraftGenerator: generationCoordinator.map { coordinator in
                    { prompt in
                        try coordinator.generateThemeDraft(from: prompt)
                    }
                },
                themeDraftApplier: generationCoordinator.map { coordinator in
                    { pack in
                        try coordinator.applyThemeDraft(pack)
                    }
                },
                speechDraftGenerator: generationCoordinator.map { coordinator in
                    { prompt in
                        try coordinator.generateSpeechDraft(from: prompt)
                    }
                },
                speechDraftApplier: generationCoordinator.map { coordinator in
                    { draft in
                        try coordinator.applySpeechDraft(draft)
                    }
                },
                onChoose: { [weak self] avatarID in
                    try? self?.applyAvatarSelection(avatarID)
                    self?.selectorController = nil
                },
                onClose: { [weak self] in
                    self?.selectorController = nil
                }
            )
            selectorController = controller
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
        onCurrentAvatarChanged?(avatarID)
    }

    private func presentAvatarWizard() {
        do {
            let models = try bridge.listImageModels(repoRootURL: catalog.repoRootURL)
            let controller = AvatarWizardWindowController(
                bridge: bridge,
                models: models,
                settingsStore: settingsStore,
                assetStore: assetStore,
                onSave: { [weak self] avatarID in
                    try? self?.applyAvatarSelection(avatarID)
                    self?.wizardController = nil
                },
                onClose: { [weak self] in
                    self?.wizardController = nil
                }
            )
            wizardController = controller
            controller.present()
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = TextCatalog.shared.text("avatar.error_unavailable_title", fallback: "形象功能暂不可用")
        alert.informativeText = UserFacingErrorCopy.avatarMessage(for: error)
        alert.addButton(withTitle: TextCatalog.shared.text("avatar.error_acknowledge_button", fallback: "知道了"))
        alert.runModal()
    }
}
