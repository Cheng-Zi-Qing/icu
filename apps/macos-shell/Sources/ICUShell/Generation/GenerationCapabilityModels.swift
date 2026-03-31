import Foundation

enum GenerationCapabilityProvider: String, Codable, Equatable {
    case ollama
    case huggingFace = "huggingface"
    case openAICompatible = "openai-compatible"
}

struct GenerationCapabilityConfig: Codable, Equatable {
    var provider: GenerationCapabilityProvider
    var baseURL: String
    var model: String
    var auth: [String: String]
    var options: [String: Double]

    init(
        provider: GenerationCapabilityProvider,
        baseURL: String,
        model: String,
        auth: [String: String],
        options: [String: Double]
    ) {
        self.provider = provider
        self.baseURL = baseURL
        self.model = model
        self.auth = auth
        self.options = options
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case baseURL = "base_url"
        case model
        case auth
        case options
    }

    static let emptyTextDescription = GenerationCapabilityConfig(
        provider: .ollama,
        baseURL: "",
        model: "",
        auth: [:],
        options: [:]
    )

    static let emptyAnimationAvatar = GenerationCapabilityConfig(
        provider: .huggingFace,
        baseURL: "",
        model: "",
        auth: [:],
        options: [:]
    )

    static let emptyCodeGeneration = GenerationCapabilityConfig(
        provider: .openAICompatible,
        baseURL: "",
        model: "",
        auth: [:],
        options: [:]
    )
}

struct GenerationCapabilityVisibleDraft: Equatable {
    var provider: GenerationCapabilityProvider
    var baseURL: String
    var model: String
    var authToken: String
}

protocol GenerationTransport {
    func completeJSON(
        prompt: String,
        capability: GenerationCapabilityConfig
    ) throws -> String
}

enum GenerationRouteError: Error, LocalizedError, Equatable {
    case emptyVibe
    case missingCapabilityConfig(String)
    case unsupportedProviderForTheme(GenerationCapabilityProvider)
    case unsupportedProviderForCapability(String, GenerationCapabilityProvider)
    case invalidBaseURL(String)
    case requestFailed(String)
    case invalidResponse(String)
    case providerReturnedError(String)
    case responseMissingContent(String)

    var errorDescription: String? {
        switch self {
        case .emptyVibe:
            return TextCatalog.shared.text(.errorEmptyVibe)
        case let .missingCapabilityConfig(capability):
            return String(format: TextCatalog.shared.text(.errorMissingCapabilityConfig), capability)
        case let .unsupportedProviderForTheme(provider):
            return String(format: TextCatalog.shared.text(.errorUnsupportedProviderForTheme), provider.rawValue)
        case let .unsupportedProviderForCapability(capability, provider):
            return String(
                format: TextCatalog.shared.text(.errorUnsupportedProviderForCapability),
                capability,
                provider.rawValue
            )
        case let .invalidBaseURL(url):
            return String(format: TextCatalog.shared.text(.errorInvalidBaseURL), url)
        case let .requestFailed(details):
            return String(format: TextCatalog.shared.text(.errorRequestFailed), details)
        case let .invalidResponse(details):
            return String(format: TextCatalog.shared.text(.errorInvalidResponse), details)
        case let .providerReturnedError(message):
            return String(format: TextCatalog.shared.text(.errorProviderReturnedError), message)
        case let .responseMissingContent(details):
            return String(format: TextCatalog.shared.text(.errorResponseMissingContent), details)
        }
    }
}

struct GenerationSettings: Codable, Equatable {
    var activeThemeID: String?
    var textDescription: GenerationCapabilityConfig
    var animationAvatar: GenerationCapabilityConfig
    var codeGeneration: GenerationCapabilityConfig

    init(
        activeThemeID: String?,
        textDescription: GenerationCapabilityConfig,
        animationAvatar: GenerationCapabilityConfig,
        codeGeneration: GenerationCapabilityConfig
    ) {
        self.activeThemeID = activeThemeID
        self.textDescription = textDescription
        self.animationAvatar = animationAvatar
        self.codeGeneration = codeGeneration
    }

    static let `default` = GenerationSettings(
        activeThemeID: nil,
        textDescription: .emptyTextDescription,
        animationAvatar: .emptyAnimationAvatar,
        codeGeneration: .emptyCodeGeneration
    )
}

extension GenerationCapabilityConfig {
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var visibleAuthToken: String {
        switch provider {
        case .huggingFace:
            return auth["token"] ?? auth["authorization"] ?? auth["api_key"] ?? ""
        case .openAICompatible:
            return auth["api_key"] ?? auth["authorization"] ?? auth["token"] ?? ""
        case .ollama:
            return auth["authorization"] ?? auth["token"] ?? auth["api_key"] ?? ""
        }
    }

    func applyingVisibleDraft(_ draft: GenerationCapabilityVisibleDraft) -> GenerationCapabilityConfig {
        GenerationCapabilityConfig(
            provider: draft.provider,
            baseURL: draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model: draft.model.trimmingCharacters(in: .whitespacesAndNewlines),
            auth: GenerationCapabilityConfig.authDictionary(for: draft.provider, token: draft.authToken),
            options: options
        )
    }

    static func authDictionary(
        for provider: GenerationCapabilityProvider,
        token: String
    ) -> [String: String] {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        switch provider {
        case .huggingFace:
            return ["token": trimmed]
        case .openAICompatible:
            return ["api_key": trimmed]
        case .ollama:
            return ["authorization": trimmed]
        }
    }
}

extension GenerationSettings {
    func applyingVisibleDrafts(
        textDescription: GenerationCapabilityVisibleDraft,
        animationAvatar: GenerationCapabilityVisibleDraft,
        codeGeneration: GenerationCapabilityVisibleDraft
    ) -> GenerationSettings {
        GenerationSettings(
            activeThemeID: activeThemeID,
            textDescription: self.textDescription.applyingVisibleDraft(textDescription),
            animationAvatar: self.animationAvatar.applyingVisibleDraft(animationAvatar),
            codeGeneration: self.codeGeneration.applyingVisibleDraft(codeGeneration)
        )
    }
}
