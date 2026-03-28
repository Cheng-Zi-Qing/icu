import Foundation

final class SpeechGenerationService {
    private let transport: GenerationTransport
    private let router: GenerationCapabilityRouter
    private let decoder = JSONDecoder()

    init(
        transport: GenerationTransport = GenerationHTTPClient(),
        settingsStore: GenerationSettingsStore
    ) {
        self.transport = transport
        self.router = GenerationCapabilityRouter(settingsStore: settingsStore)
    }

    func generateSpeechDraft(from prompt: String) throws -> SpeechDraft {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else {
            throw GenerationRouteError.emptyVibe
        }

        let capability = try router.capability(for: .textDescription)

        let responseJSON = try transport.completeJSON(
            prompt: makeSpeechDraftPrompt(prompt: normalizedPrompt),
            capability: capability
        )

        let draft = try decoder.decode(SpeechDraft.self, from: Data(responseJSON.utf8))
        try draft.validate()
        return draft
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
