import Foundation

enum GenerationProvider: String, Codable, Equatable, CaseIterable {
    case openAI = "openai"
    case anthropic
    case ollama
    case huggingFace = "huggingface"
    case openAICompatible = "openai-compatible"
}

typealias GenerationCapabilityProvider = GenerationProvider

struct GenerationProviderDefaultConfig: Codable, Equatable {
    var apiKey: String
    var baseURL: String
    var headers: [String: String]
    var auth: [String: String]

    init(
        apiKey: String = "",
        baseURL: String = "",
        headers: [String: String] = [:],
        auth: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.headers = headers
        self.auth = auth
    }

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case baseURL = "base_url"
        case headers
        case auth
    }

    var resolvedAuth: [String: String] {
        if !auth.isEmpty {
            return auth
        }
        guard !apiKey.isEmpty else {
            return [:]
        }
        return ["api_key": apiKey]
    }
}

struct GenerationCapabilityCustomTransport: Codable, Equatable {
    var apiKey: String
    var baseURL: String
    var headers: [String: String]
    var auth: [String: String]

    init(
        apiKey: String = "",
        baseURL: String = "",
        headers: [String: String] = [:],
        auth: [String: String] = [:]
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.headers = headers
        self.auth = auth
    }

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case baseURL = "base_url"
        case headers
        case auth
    }

    var resolvedAuth: [String: String] {
        if !auth.isEmpty {
            return auth
        }
        guard !apiKey.isEmpty else {
            return [:]
        }
        return ["api_key": apiKey]
    }
}

struct GenerationCapabilityConfig: Codable, Equatable {
    var provider: GenerationCapabilityProvider
    var preset: String
    var customized: Bool
    var custom: GenerationCapabilityCustomTransport?
    var headers: [String: String] = [:]
    var baseURL: String
    var model: String
    var auth: [String: String]
    var options: [String: Double]

    init(
        provider: GenerationCapabilityProvider,
        preset: String,
        model: String,
        customized: Bool,
        custom: GenerationCapabilityCustomTransport?,
        headers: [String: String] = [:],
        baseURL: String,
        auth: [String: String],
        options: [String: Double]
    ) {
        self.provider = provider
        self.preset = preset
        self.model = model
        self.customized = customized
        self.custom = custom
        self.headers = headers
        self.baseURL = baseURL
        self.auth = auth
        self.options = options
    }

    init(
        provider: GenerationCapabilityProvider,
        baseURL: String,
        model: String,
        auth: [String: String],
        options: [String: Double]
    ) {
        self.provider = provider
        // Legacy capability-shaped entries represent explicit per-capability transport,
        // so migration starts with customized=true and a populated custom transport payload.
        self.preset = model
        self.customized = true
        self.custom = GenerationCapabilityCustomTransport(
            apiKey: auth["api_key"] ?? "",
            baseURL: baseURL,
            headers: [:],
            auth: auth
        )
        self.headers = [:]
        self.baseURL = baseURL
        self.model = model
        self.auth = auth
        self.options = options
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case preset
        case customized
        case custom
        case headers
        case baseURL = "base_url"
        case model
        case auth
        case options
    }

    static let emptyTextDescription = GenerationCapabilityConfig(
        provider: .ollama,
        preset: "",
        model: "",
        customized: false,
        custom: nil,
        headers: [:],
        baseURL: "",
        auth: [:],
        options: [:]
    )

    static let emptyAnimationAvatar = GenerationCapabilityConfig(
        provider: .huggingFace,
        preset: "",
        model: "",
        customized: false,
        custom: nil,
        headers: [:],
        baseURL: "",
        auth: [:],
        options: [:]
    )

    static let emptyCodeGeneration = GenerationCapabilityConfig(
        provider: .openAICompatible,
        preset: "",
        model: "",
        customized: false,
        custom: nil,
        headers: [:],
        baseURL: "",
        auth: [:],
        options: [:]
    )
}

protocol GenerationTransport {
    func completeJSON(
        prompt: String,
        capability: GenerationCapabilityConfig
    ) throws -> String
}

protocol GenerationConnectionTesting {
    func testConnection(
        provider: GenerationProvider,
        defaults: GenerationProviderDefaultConfig
    ) throws
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
    var providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    var textDescription: GenerationCapabilityConfig
    var animationAvatar: GenerationCapabilityConfig
    var codeGeneration: GenerationCapabilityConfig

    init(
        activeThemeID: String?,
        providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig] = [:],
        textDescription: GenerationCapabilityConfig,
        animationAvatar: GenerationCapabilityConfig,
        codeGeneration: GenerationCapabilityConfig
    ) {
        self.activeThemeID = activeThemeID
        self.providerDefaults = providerDefaults
        self.textDescription = textDescription
        self.animationAvatar = animationAvatar
        self.codeGeneration = codeGeneration
    }

    static let `default` = GenerationSettings(
        activeThemeID: nil,
        providerDefaults: [:],
        textDescription: .emptyTextDescription,
        animationAvatar: .emptyAnimationAvatar,
        codeGeneration: .emptyCodeGeneration
    )
}

extension GenerationCapabilityConfig {
    func resolvedProviderConfig(
        providerDefault: GenerationProviderDefaultConfig?
    ) -> GenerationCapabilityConfig {
        let resolvedBaseURL: String
        if customized, let custom {
            let customBaseURL = custom.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customBaseURL.isEmpty {
                resolvedBaseURL = custom.baseURL
            } else if let providerDefault, !providerDefault.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedBaseURL = providerDefault.baseURL
            } else {
                resolvedBaseURL = baseURL
            }
        } else if let providerDefault, !providerDefault.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedBaseURL = providerDefault.baseURL
        } else {
            resolvedBaseURL = baseURL
        }

        let resolvedAuth: [String: String]
        if customized, let custom {
            let customAuth = custom.resolvedAuth
            if !customAuth.isEmpty {
                resolvedAuth = customAuth
            } else if let providerDefault {
                let providerAuth = providerDefault.resolvedAuth
                resolvedAuth = providerAuth.isEmpty ? auth : providerAuth
            } else {
                resolvedAuth = auth
            }
        } else if let providerDefault {
            let providerAuth = providerDefault.resolvedAuth
            resolvedAuth = providerAuth.isEmpty ? auth : providerAuth
        } else {
            resolvedAuth = auth
        }

        let resolvedHeaders: [String: String]
        if customized, let custom, !custom.headers.isEmpty {
            resolvedHeaders = custom.headers
        } else if let providerDefault, !providerDefault.headers.isEmpty {
            resolvedHeaders = providerDefault.headers
        } else {
            resolvedHeaders = headers
        }

        return GenerationCapabilityConfig(
            provider: provider,
            preset: preset,
            model: model,
            customized: customized,
            custom: customized ? custom : nil,
            headers: resolvedHeaders,
            baseURL: resolvedBaseURL,
            auth: resolvedAuth,
            options: options
        )
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
