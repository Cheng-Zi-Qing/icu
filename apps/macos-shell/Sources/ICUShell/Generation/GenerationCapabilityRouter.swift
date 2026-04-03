import Foundation

enum GenerationCapabilityKind: String, CaseIterable {
    case textDescription = "text_description"
    case animationAvatar = "animation_avatar"
    case codeGeneration = "code_generation"
}

extension GenerationCapabilityKind {
    var allowedProviders: [GenerationCapabilityProvider] {
        switch self {
        case .textDescription, .codeGeneration:
            return [.openAI, .anthropic, .ollama, .openAICompatible]
        case .animationAvatar:
            return [.openAI, .huggingFace, .openAICompatible]
        }
    }
}

struct GenerationCapabilityRouter {
    let settingsStore: GenerationSettingsStore

    func capability(for kind: GenerationCapabilityKind) throws -> GenerationCapabilityConfig {
        let settings = try settingsStore.load()
        let rawCapability: GenerationCapabilityConfig

        switch kind {
        case .textDescription:
            rawCapability = settings.textDescription
        case .animationAvatar:
            rawCapability = settings.animationAvatar
        case .codeGeneration:
            rawCapability = settings.codeGeneration
        }

        let capability = rawCapability.resolvedProviderConfig(
            providerDefault: settings.providerDefaults[rawCapability.provider]
        )
        try validate(capability, for: kind)
        return capability
    }

    func validate(_ capability: GenerationCapabilityConfig, for kind: GenerationCapabilityKind) throws {
        guard kind.allowedProviders.contains(capability.provider) else {
            throw GenerationRouteError.unsupportedProviderForCapability(kind.rawValue, capability.provider)
        }
        guard capability.isConfigured else {
            throw GenerationRouteError.missingCapabilityConfig(kind.rawValue)
        }
    }
}
