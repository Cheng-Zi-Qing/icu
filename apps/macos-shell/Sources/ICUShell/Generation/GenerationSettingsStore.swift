import Foundation

final class GenerationSettingsStore {
    private let appPaths: AppPaths?
    private let repoRootURL: URL
    private let fileManager: FileManager

    init(
        appPaths: AppPaths? = nil,
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default
    ) {
        self.appPaths = appPaths
        self.repoRootURL = repoRootURL
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        self.fileManager = fileManager
    }

    func load() throws -> GenerationSettings {
        let rootObject = try loadRootObject()
        let generationObject = rootObject["generation"] as? [String: Any] ?? [:]
        let activeThemeID = try loadActiveThemeID(from: rootObject)

        if generationObject["provider_defaults"] != nil {
            return loadProviderFirstSettings(from: generationObject, activeThemeID: activeThemeID)
        }
        return loadLegacySettings(from: generationObject, activeThemeID: activeThemeID)
    }

    func save(_ settings: GenerationSettings) throws {
        var rootObject = try loadRootObject()
        let normalized = normalizeForSave(settings)
        rootObject["generation"] = makeGenerationObject(from: normalized)

        var themeObject = (rootObject["theme"] as? [String: Any]) ?? [:]
        if let activeThemeID = settings.activeThemeID, !activeThemeID.isEmpty {
            themeObject["current_id"] = activeThemeID
        } else {
            themeObject.removeValue(forKey: "current_id")
        }
        if themeObject.isEmpty {
            rootObject.removeValue(forKey: "theme")
        } else {
            rootObject["theme"] = themeObject
        }

        try saveRootObject(rootObject)
    }

    func loadActiveThemeID() throws -> String? {
        let rootObject = try loadRootObject()
        return try loadActiveThemeID(from: rootObject)
    }

    func saveActiveThemeID(_ id: String) throws {
        var rootObject = try loadRootObject()
        var themeObject = (rootObject["theme"] as? [String: Any]) ?? [:]
        themeObject["current_id"] = id
        rootObject["theme"] = themeObject
        try saveRootObject(rootObject)
    }

    private func loadActiveThemeID(from rootObject: [String: Any]) throws -> String? {
        let themeObject = rootObject["theme"] as? [String: Any]
        return themeObject?["current_id"] as? String
    }

    private func loadProviderFirstSettings(
        from generationObject: [String: Any],
        activeThemeID: String?
    ) -> GenerationSettings {
        let providerDefaults = makeProviderDefaults(
            from: generationObject["provider_defaults"] as? [String: Any]
        )
        let textDescription = makeProviderFirstCapabilityConfig(
            from: generationObject["text_description"] as? [String: Any],
            fallback: .emptyTextDescription,
            providerDefaults: providerDefaults
        )
        let animationAvatar = makeProviderFirstCapabilityConfig(
            from: generationObject["animation_avatar"] as? [String: Any],
            fallback: .emptyAnimationAvatar,
            providerDefaults: providerDefaults
        )
        let codeGeneration = makeProviderFirstCapabilityConfig(
            from: generationObject["code_generation"] as? [String: Any],
            fallback: .emptyCodeGeneration,
            providerDefaults: providerDefaults
        )

        return GenerationSettings(
            activeThemeID: activeThemeID,
            providerDefaults: providerDefaults,
            textDescription: textDescription,
            animationAvatar: animationAvatar,
            codeGeneration: codeGeneration
        )
    }

    private func loadLegacySettings(
        from generationObject: [String: Any],
        activeThemeID: String?
    ) -> GenerationSettings {
        let legacyTextDescriptionObject = generationObject["text_description"] as? [String: Any]
        let legacyAnimationAvatarObject = generationObject["animation_avatar"] as? [String: Any]
        let legacyCodeGenerationObject = generationObject["code_generation"] as? [String: Any]

        let legacyTextDescription = makeLegacyCapabilityConfig(
            from: legacyTextDescriptionObject,
            fallback: .emptyTextDescription
        )
        let legacyAnimationAvatar = makeLegacyCapabilityConfig(
            from: legacyAnimationAvatarObject,
            fallback: .emptyAnimationAvatar
        )
        let legacyCodeGeneration = makeLegacyCapabilityConfig(
            from: legacyCodeGenerationObject,
            fallback: .emptyCodeGeneration
        )

        let legacyCapabilitiesForDefaults: [GenerationCapabilityConfig] = [
            legacyTextDescriptionObject != nil ? legacyTextDescription : nil,
            legacyAnimationAvatarObject != nil ? legacyAnimationAvatar : nil,
            legacyCodeGenerationObject != nil ? legacyCodeGeneration : nil,
        ]
        .compactMap { $0 }
        var providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig] = [:]
        for capability in legacyCapabilitiesForDefaults where shouldMigrateLegacyCapabilityToProviderDefault(capability) {
            if providerDefaults[capability.provider] == nil {
                providerDefaults[capability.provider] = GenerationProviderDefaultConfig(
                    apiKey: capability.auth["api_key"] ?? "",
                    baseURL: capability.baseURL,
                    headers: capability.headers,
                    auth: capability.auth
                )
            }
        }

        let textDescription = migrateLegacyCapability(
            legacyTextDescription,
            wasPresent: legacyTextDescriptionObject != nil,
            providerDefaults: providerDefaults
        )
        let animationAvatar = migrateLegacyCapability(
            legacyAnimationAvatar,
            wasPresent: legacyAnimationAvatarObject != nil,
            providerDefaults: providerDefaults
        )
        let codeGeneration = migrateLegacyCapability(
            legacyCodeGeneration,
            wasPresent: legacyCodeGenerationObject != nil,
            providerDefaults: providerDefaults
        )

        return GenerationSettings(
            activeThemeID: activeThemeID,
            providerDefaults: providerDefaults,
            textDescription: textDescription,
            animationAvatar: animationAvatar,
            codeGeneration: codeGeneration
        )
    }

    private func makeLegacyCapabilityConfig(
        from object: [String: Any]?,
        fallback: GenerationCapabilityConfig
    ) -> GenerationCapabilityConfig {
        guard let object else {
            return fallback
        }

        let provider: GenerationCapabilityProvider = {
            guard let rawValue = object["provider"] as? String else {
                return fallback.provider
            }
            return GenerationCapabilityProvider(rawValue: rawValue) ?? fallback.provider
        }()

        let authObject = object["auth"] as? [String: Any] ?? [:]
        var auth: [String: String] = [:]
        for (key, value) in authObject {
            if let stringValue = value as? String {
                auth[key] = stringValue
            }
        }
        let headers = makeStringMap(from: object["headers"] as? [String: Any])

        let optionsObject = object["options"] as? [String: Any] ?? [:]
        var options: [String: Double] = [:]
        for (key, value) in optionsObject {
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                options[key] = number.doubleValue
            }
        }

        return GenerationCapabilityConfig(
            provider: provider,
            preset: object["model"] as? String ?? fallback.model,
            model: object["model"] as? String ?? fallback.model,
            customized: true,
            custom: GenerationCapabilityCustomTransport(
                apiKey: auth["api_key"] ?? "",
                baseURL: object["base_url"] as? String ?? fallback.baseURL,
                headers: headers,
                auth: auth
            ),
            headers: headers,
            baseURL: object["base_url"] as? String ?? fallback.baseURL,
            auth: auth,
            options: options
        )
    }

    private func makeProviderFirstCapabilityConfig(
        from object: [String: Any]?,
        fallback: GenerationCapabilityConfig,
        providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    ) -> GenerationCapabilityConfig {
        guard let object else {
            return fallback
        }

        if isLegacyCapabilityShape(object) {
            let legacy = makeLegacyCapabilityConfig(from: object, fallback: fallback)
            return migrateLegacyCapability(
                legacy,
                wasPresent: true,
                providerDefaults: providerDefaults
            )
        }

        let provider: GenerationCapabilityProvider = {
            guard let rawValue = object["provider"] as? String else {
                return fallback.provider
            }
            return GenerationCapabilityProvider(rawValue: rawValue) ?? fallback.provider
        }()
        let providerDefault = providerDefaults[provider]
        let model = object["model"] as? String ?? fallback.model
        let preset = (object["preset"] as? String) ?? (fallback.preset.isEmpty ? model : fallback.preset)
        let custom = makeCustomTransport(from: object["custom"] as? [String: Any])
        let customized = (object["customized"] as? Bool) ?? (custom != nil)
        let options = makeOptions(from: object["options"] as? [String: Any])

        let resolvedBaseURL: String
        let resolvedAuth: [String: String]
        let resolvedHeaders: [String: String]
        if customized, let custom {
            resolvedBaseURL = custom.baseURL
            resolvedAuth = custom.resolvedAuth
            resolvedHeaders = custom.headers
        } else if let providerDefault {
            resolvedBaseURL = providerDefault.baseURL
            resolvedAuth = providerDefault.resolvedAuth
            resolvedHeaders = providerDefault.headers
        } else {
            resolvedBaseURL = fallback.baseURL
            resolvedAuth = fallback.auth
            resolvedHeaders = fallback.headers
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

    private func makeProviderDefaults(from object: [String: Any]?) -> [GenerationProvider: GenerationProviderDefaultConfig] {
        guard let object else {
            return [:]
        }

        var providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig] = [:]
        for (rawProvider, value) in object {
            guard let provider = GenerationProvider(rawValue: rawProvider),
                  let configObject = value as? [String: Any] else {
                continue
            }
            providerDefaults[provider] = GenerationProviderDefaultConfig(
                apiKey: configObject["api_key"] as? String ?? "",
                baseURL: configObject["base_url"] as? String ?? "",
                headers: makeStringMap(from: configObject["headers"] as? [String: Any]),
                auth: makeStringMap(from: configObject["auth"] as? [String: Any])
            )
        }
        return providerDefaults
    }

    private func makeGenerationObject(from settings: GenerationSettings) -> [String: Any] {
        [
            "provider_defaults": makeProviderDefaultsObject(from: settings.providerDefaults),
            "text_description": makeCapabilityObject(from: settings.textDescription),
            "animation_avatar": makeCapabilityObject(from: settings.animationAvatar),
            "code_generation": makeCapabilityObject(from: settings.codeGeneration),
        ]
    }

    private func makeProviderDefaultsObject(
        from providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    ) -> [String: Any] {
        var object: [String: Any] = [:]
        for provider in GenerationProvider.allCases {
            guard let config = providerDefaults[provider] else {
                continue
            }
            var value: [String: Any] = [
                "api_key": config.apiKey,
                "base_url": config.baseURL,
                "headers": config.headers,
            ]
            if !config.auth.isEmpty {
                value["auth"] = config.auth
            }
            object[provider.rawValue] = value
        }
        return object
    }

    private func makeCapabilityObject(from config: GenerationCapabilityConfig) -> [String: Any] {
        var object: [String: Any] = [
            "provider": config.provider.rawValue,
            "preset": config.preset,
            "model": config.model,
            "customized": config.customized,
            "options": config.options,
        ]
        if config.customized, let custom = config.custom {
            var customObject: [String: Any] = [
                "api_key": custom.apiKey,
                "base_url": custom.baseURL,
                "headers": custom.headers,
            ]
            if !custom.auth.isEmpty {
                customObject["auth"] = custom.auth
            }
            object["custom"] = customObject
        }
        return object
    }

    private func migrateLegacyCapability(
        _ legacy: GenerationCapabilityConfig,
        wasPresent: Bool,
        providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    ) -> GenerationCapabilityConfig {
        guard wasPresent else {
            return legacy
        }
        let providerDefault = providerDefaults[legacy.provider] ?? GenerationProviderDefaultConfig()
        let isCustomized = legacy.baseURL != providerDefault.baseURL
            || legacy.auth != providerDefault.resolvedAuth
            || legacy.headers != providerDefault.headers
        let custom: GenerationCapabilityCustomTransport? = isCustomized
            ? GenerationCapabilityCustomTransport(
                apiKey: legacy.auth["api_key"] ?? "",
                baseURL: legacy.baseURL,
                headers: legacy.headers,
                auth: legacy.auth
            )
            : nil

        return GenerationCapabilityConfig(
            provider: legacy.provider,
            preset: legacy.model,
            model: legacy.model,
            customized: isCustomized,
            custom: custom,
            headers: isCustomized ? (custom?.headers ?? [:]) : providerDefault.headers,
            baseURL: legacy.baseURL,
            auth: legacy.auth,
            options: legacy.options
        )
    }

    private func normalizeForSave(_ settings: GenerationSettings) -> GenerationSettings {
        var providerDefaults = settings.providerDefaults
        let textDescription = normalizeCapabilityForSave(settings.textDescription, providerDefaults: &providerDefaults)
        let animationAvatar = normalizeCapabilityForSave(settings.animationAvatar, providerDefaults: &providerDefaults)
        let codeGeneration = normalizeCapabilityForSave(settings.codeGeneration, providerDefaults: &providerDefaults)

        return GenerationSettings(
            activeThemeID: settings.activeThemeID,
            providerDefaults: providerDefaults,
            textDescription: textDescription,
            animationAvatar: animationAvatar,
            codeGeneration: codeGeneration
        )
    }

    private func normalizeCapabilityForSave(
        _ capability: GenerationCapabilityConfig,
        providerDefaults: inout [GenerationProvider: GenerationProviderDefaultConfig]
    ) -> GenerationCapabilityConfig {
        let providerDefault = providerDefaults[capability.provider]
        let preset = capability.preset.isEmpty ? capability.model : capability.preset

        var customized = capability.customized
        var custom = customized ? capability.custom : nil

        if !customized && providerDefault == nil && hasCapabilityLevelTransport(capability) {
            customized = true
        }

        if customized, custom == nil {
            custom = GenerationCapabilityCustomTransport(
                apiKey: capability.auth["api_key"] ?? "",
                baseURL: capability.baseURL,
                headers: capability.headers,
                auth: capability.auth
            )
        }

        let resolvedBaseURL: String
        let resolvedAuth: [String: String]
        let resolvedHeaders: [String: String]
        if customized, let custom {
            resolvedBaseURL = custom.baseURL
            resolvedAuth = custom.resolvedAuth
            resolvedHeaders = custom.headers
        } else if let providerDefault {
            resolvedBaseURL = providerDefault.baseURL
            resolvedAuth = providerDefault.resolvedAuth
            resolvedHeaders = providerDefault.headers
        } else {
            resolvedBaseURL = capability.baseURL
            resolvedAuth = capability.auth
            resolvedHeaders = capability.headers
        }

        return GenerationCapabilityConfig(
            provider: capability.provider,
            preset: preset,
            model: capability.model,
            customized: customized,
            custom: custom,
            headers: resolvedHeaders,
            baseURL: resolvedBaseURL,
            auth: resolvedAuth,
            options: capability.options
        )
    }

    private func makeCustomTransport(from object: [String: Any]?) -> GenerationCapabilityCustomTransport? {
        guard let object else {
            return nil
        }
        return GenerationCapabilityCustomTransport(
            apiKey: object["api_key"] as? String ?? "",
            baseURL: object["base_url"] as? String ?? "",
            headers: makeStringMap(from: object["headers"] as? [String: Any]),
            auth: makeStringMap(from: object["auth"] as? [String: Any])
        )
    }

    private func makeStringMap(from object: [String: Any]?) -> [String: String] {
        guard let object else {
            return [:]
        }
        var map: [String: String] = [:]
        for (key, value) in object {
            if let stringValue = value as? String {
                map[key] = stringValue
            }
        }
        return map
    }

    private func makeOptions(from object: [String: Any]?) -> [String: Double] {
        guard let object else {
            return [:]
        }
        var options: [String: Double] = [:]
        for (key, value) in object {
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                options[key] = number.doubleValue
            }
        }
        return options
    }

    private func shouldMigrateLegacyCapabilityToProviderDefault(_ capability: GenerationCapabilityConfig) -> Bool {
        hasCapabilityLevelTransport(capability)
    }

    private func hasCapabilityLevelTransport(_ capability: GenerationCapabilityConfig) -> Bool {
        !capability.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !capability.auth.isEmpty
            || !capability.headers.isEmpty
    }

    private func isLegacyCapabilityShape(_ object: [String: Any]) -> Bool {
        let hasLegacyTransportKeys = object["base_url"] != nil
            || object["auth"] != nil
            || object["headers"] != nil
        let hasProviderFirstKeys = object["preset"] != nil || object["customized"] != nil || object["custom"] != nil
        return hasLegacyTransportKeys && !hasProviderFirstKeys
    }

    private func loadRootObject() throws -> [String: Any] {
        let candidateURLs = [primarySettingsFileURL, fallbackSettingsFileURL].compactMap { $0 }
        guard let existingURL = candidateURLs.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return [:]
        }

        let data = try Data(contentsOf: existingURL)
        return (try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]) ?? [:]
    }

    private func saveRootObject(_ rootObject: [String: Any]) throws {
        try fileManager.createDirectory(
            at: primarySettingsFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: primarySettingsFileURL, options: .atomic)
    }

    private var primarySettingsFileURL: URL {
        if let appPaths {
            return appPaths.configDirectory
                .appendingPathComponent("settings.json", isDirectory: false)
        }

        return repoRootURL
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    private var fallbackSettingsFileURL: URL? {
        guard appPaths != nil else {
            return nil
        }

        return repoRootURL
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }
}
