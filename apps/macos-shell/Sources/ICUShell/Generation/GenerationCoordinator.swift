import AppKit
import Foundation

final class GenerationCoordinator {
    private let settingsStore: GenerationSettingsStore
    private let themeManager: ThemeManager
    private let generationService: ThemeGenerationService
    private let speechGenerationService: SpeechGenerationService?
    private let copyOverrideStore: CopyOverrideStore?

    private var configWindowController: GenerationConfigWindowController?

    init(
        settingsStore: GenerationSettingsStore,
        themeManager: ThemeManager,
        generationService: ThemeGenerationService,
        speechGenerationService: SpeechGenerationService? = nil,
        copyOverrideStore: CopyOverrideStore? = nil
    ) {
        self.settingsStore = settingsStore
        self.themeManager = themeManager
        self.generationService = generationService
        self.speechGenerationService = speechGenerationService
        self.copyOverrideStore = copyOverrideStore
    }

    func openGenerationConfig() -> GenerationConfigWindowController {
        if let configWindowController {
            configWindowController.present()
            return configWindowController
        }

        let controller = GenerationConfigWindowController(
            settingsStore: settingsStore,
            themeManager: themeManager,
            generationCoordinator: self,
            onClose: { [weak self] in
                self?.configWindowController = nil
            }
        )
        configWindowController = controller
        controller.present()
        return controller
    }

    func generateAndApplyTheme(from vibe: String) throws -> ThemePack {
        try generationService.generateAndApplyTheme(from: vibe)
    }

    func generateThemeDraft(from vibe: String) throws -> ThemePack {
        try generationService.generateThemeDraft(from: vibe)
    }

    func applyThemeDraft(_ pack: ThemePack) throws {
        try themeManager.apply(pack)
    }

    func generateSpeechDraft(from prompt: String) throws -> SpeechDraft {
        guard let speechGenerationService else {
            throw GenerationRouteError.missingCapabilityConfig("text_description")
        }
        return try speechGenerationService.generateSpeechDraft(from: prompt)
    }

    func applySpeechDraft(_ draft: SpeechDraft) throws {
        guard let copyOverrideStore else {
            throw GenerationRouteError.invalidResponse("copy override store is unavailable")
        }
        try copyOverrideStore.applySpeechDraft(draft)
    }

    func resetToPixelDefault() throws {
        try themeManager.resetToPixelDefault()
    }
}
