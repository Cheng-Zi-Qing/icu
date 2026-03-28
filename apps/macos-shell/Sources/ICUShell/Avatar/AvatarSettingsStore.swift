import Foundation

final class AvatarSettingsStore {
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

    func loadCurrentAvatarID() throws -> String? {
        guard let settingsFileURL = resolvedExistingSettingsFileURL() else {
            return nil
        }

        let data = try Data(contentsOf: settingsFileURL)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let avatar = object["avatar"] as? [String: Any]
        else {
            return nil
        }

        return avatar["current_id"] as? String
    }

    func saveCurrentAvatarID(_ id: String) throws {
        var rootObject = try loadRootObject()

        var avatar = (rootObject["avatar"] as? [String: Any]) ?? [:]
        avatar["current_id"] = id
        if avatar["custom_avatars"] == nil {
            avatar["custom_avatars"] = []
        }
        rootObject["avatar"] = avatar

        try saveRootObject(rootObject)
    }

    func loadImageModels() throws -> [BridgeImageModel] {
        guard resolvedExistingSettingsFileURL() != nil else {
            return Self.defaultImageModels
        }

        let rootObject = try loadRootObject()
        let ai = rootObject["ai"] as? [String: Any]
        let rawModels = ai?["image_models"] as? [[String: Any]] ?? []
        let models = rawModels.compactMap(Self.makeImageModel)
        return models.isEmpty ? Self.defaultImageModels : models
    }

    func saveImageModels(_ models: [BridgeImageModel]) throws {
        var rootObject = try loadRootObject()
        var ai = (rootObject["ai"] as? [String: Any]) ?? [:]
        ai["image_models"] = models.map { model in
            [
                "name": model.name,
                "url": model.url,
                "token": model.token,
            ]
        }
        rootObject["ai"] = ai

        try saveRootObject(rootObject)
    }

    private func loadRootObject() throws -> [String: Any] {
        let candidateURLs = [primarySettingsFileURL, fallbackSettingsFileURL].compactMap { $0 }
        guard let existingURL = candidateURLs.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return [:]
        }

        let data = try Data(contentsOf: existingURL)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func saveRootObject(_ rootObject: [String: Any]) throws {
        try fileManager.createDirectory(
            at: primarySettingsFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: primarySettingsFileURL, options: .atomic)
    }

    private static func makeImageModel(from object: [String: Any]) -> BridgeImageModel? {
        guard
            let name = object["name"] as? String,
            let url = object["url"] as? String
        else {
            return nil
        }

        return BridgeImageModel(name: name, url: url, token: object["token"] as? String ?? "")
    }

    private static let defaultImageModels = [
        BridgeImageModel(name: "Stable Diffusion XL", url: "stabilityai/stable-diffusion-xl-base-1.0", token: "")
    ]

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

    private func resolvedExistingSettingsFileURL() -> URL? {
        [primarySettingsFileURL, fallbackSettingsFileURL]
            .compactMap { $0 }
            .first(where: { fileManager.fileExists(atPath: $0.path) })
    }
}
