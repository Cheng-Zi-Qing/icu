import Foundation

final class SpeechGenerationService {
    private let transport: GenerationTransport
    private let settingsStore: GenerationSettingsStore
    private let decoder = JSONDecoder()

    init(
        transport: GenerationTransport = GenerationHTTPClient(),
        settingsStore: GenerationSettingsStore
    ) {
        self.transport = transport
        self.settingsStore = settingsStore
    }

    func generateSpeechDraft(from prompt: String) throws -> SpeechDraft {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else {
            throw GenerationRouteError.emptyVibe
        }

        let settings = try settingsStore.load()
        let capability = settings.textDescription
        try validateCapability(capability)

        let responseJSON = try transport.completeJSON(
            prompt: makeSpeechDraftPrompt(prompt: normalizedPrompt),
            capability: capability
        )

        let draft = try decoder.decode(SpeechDraft.self, from: Data(responseJSON.utf8))
        try draft.validate()
        return draft
    }

    private func validateCapability(_ capability: GenerationCapabilityConfig) throws {
        guard capability.provider == .ollama || capability.provider == .openAICompatible else {
            throw GenerationRouteError.unsupportedProviderForTheme(capability.provider)
        }
        guard capability.isConfigured else {
            throw GenerationRouteError.missingCapabilityConfig("text_description")
        }
    }

    private func makeSpeechDraftPrompt(prompt: String) -> String {
        """
        You are a desktop pet copy generator.
        Convert the user's prompt into a JSON object with these non-empty string fields only:
        - status_idle
        - status_working
        - status_focus
        - status_break
        - focus_end_light
        - focus_end_heavy
        - stop_work_message
        - eye_reminder
        Return JSON only.

        user_prompt:
        \(prompt)
        """
    }
}
