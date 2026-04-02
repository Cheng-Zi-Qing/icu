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

        let textDescription = makeCapabilityConfig(
            from: generationObject["text_description"] as? [String: Any],
            fallback: .emptyTextDescription
        )
        let animationAvatar = makeCapabilityConfig(
            from: generationObject["animation_avatar"] as? [String: Any],
            fallback: .emptyAnimationAvatar
        )
        let codeGeneration = makeCapabilityConfig(
            from: generationObject["code_generation"] as? [String: Any],
            fallback: .emptyCodeGeneration
        )

        return GenerationSettings(
            activeThemeID: try loadActiveThemeID(from: rootObject),
            textDescription: textDescription,
            animationAvatar: animationAvatar,
            codeGeneration: codeGeneration
        )
    }

    func save(_ settings: GenerationSettings) throws {
        var rootObject = try loadRootObject()
        rootObject["generation"] = [
            "text_description": makeCapabilityObject(from: settings.textDescription),
            "animation_avatar": makeCapabilityObject(from: settings.animationAvatar),
            "code_generation": makeCapabilityObject(from: settings.codeGeneration),
        ]

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

    private func makeCapabilityConfig(
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

        let optionsObject = object["options"] as? [String: Any] ?? [:]
        var options: [String: Double] = [:]
        for (key, value) in optionsObject {
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                options[key] = number.doubleValue
            }
        }

        return GenerationCapabilityConfig(
            provider: provider,
            baseURL: object["base_url"] as? String ?? fallback.baseURL,
            model: object["model"] as? String ?? fallback.model,
            auth: auth,
            options: options
        )
    }

    private func makeCapabilityObject(from config: GenerationCapabilityConfig) -> [String: Any] {
        [
            "provider": config.provider.rawValue,
            "base_url": config.baseURL,
            "model": config.model,
            "auth": config.auth,
            "options": config.options,
        ]
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
