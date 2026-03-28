import Foundation

final class ThemeGenerationService {
    private let transport: GenerationTransport
    private let router: GenerationCapabilityRouter
    private let themeManager: ThemeManager

    init(
        transport: GenerationTransport = GenerationHTTPClient(),
        settingsStore: GenerationSettingsStore,
        themeManager: ThemeManager
    ) {
        self.transport = transport
        self.router = GenerationCapabilityRouter(settingsStore: settingsStore)
        self.themeManager = themeManager
    }

    func generateThemeDraft(from vibe: String) throws -> ThemePack {
        let normalizedVibe = vibe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedVibe.isEmpty else {
            throw GenerationRouteError.emptyVibe
        }

        let textCapability = try router.capability(for: .textDescription)
        let codeCapability = try router.capability(for: .codeGeneration)

        let styleIntentJSON = try transport.completeJSON(
            prompt: makeStyleIntentPrompt(vibe: normalizedVibe),
            capability: textCapability
        )
        let themePackJSON = try transport.completeJSON(
            prompt: makeThemePackPrompt(styleIntentJSON: styleIntentJSON),
            capability: codeCapability
        )

        return try ThemePack.decodeAndValidate(from: themePackJSON)
    }

    func generateAndApplyTheme(from vibe: String) throws -> ThemePack {
        let pack = try generateThemeDraft(from: vibe)
        try themeManager.apply(pack)
        return pack
    }
    private func makeStyleIntentPrompt(vibe: String) -> String {
        """
        You are a style-intent generator for UI themes.
        Convert the user's vibe text into a compact JSON object with fields:
        - name
        - summary
        - keywords (array of short strings)
        - paletteHints (array of hex color strings)
        Return JSON only.

        vibe:
        \(vibe)
        """
    }

    private func makeThemePackPrompt(styleIntentJSON: String) -> String {
        """
        You are a ThemePack generator.
        Convert the provided style intent JSON into a valid ThemePack JSON with this minimum shape:
        {
          "meta": { "id": "...", "name": "...", "version": 1, "source_prompt": "..." },
          "tokens": { "colors": { "menu_background_hex": "#112233" } },
          "components": { "menu_row": { "padding": "8" } }
        }
        Return JSON only, and ensure all required fields are non-empty.

        style_intent:
        \(styleIntentJSON)
        """
    }
}
