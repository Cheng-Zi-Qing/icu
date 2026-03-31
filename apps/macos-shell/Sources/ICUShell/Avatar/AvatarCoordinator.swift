import AppKit

final class AvatarCoordinator {
    private let settingsStore: AvatarSettingsStore
    private let catalog: AvatarCatalog
    private let assetStore: AvatarAssetStore
    private let bridge: AvatarBuilderBridge
    private let generationCoordinator: GenerationCoordinator?
    private var pickerController: AvatarPickerWindowController?
    private var studioController: StudioWindowController?
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

            let controller = AvatarPickerWindowController(
                avatars: avatars,
                currentAvatarID: try settingsStore.loadCurrentAvatarID(),
                onChoose: { [weak self] avatarID in
                    try self?.applyAvatarSelection(avatarID)
                    self?.pickerController = nil
                },
                onCreateNew: { [weak self] in
                    self?.pickerController = nil
                    self?.presentStudio(target: .avatarCreate)
                },
                onClose: { [weak self] in
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
        onCurrentAvatarChanged?(avatarID)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = TextCatalog.shared.text("avatar.error_unavailable_title", fallback: "形象功能暂不可用")
        alert.informativeText = UserFacingErrorCopy.avatarMessage(for: error)
        alert.addButton(withTitle: TextCatalog.shared.text("avatar.error_acknowledge_button", fallback: "知道了"))
        alert.runModal()
    }

}
