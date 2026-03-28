import Foundation

extension Notification.Name {
    static let icuCopyDidChange = Notification.Name("ICUShell.CopyDidChange")
}

struct TextCatalog {
    private static var installedShared: TextCatalog = (try? TextCatalog.live()) ?? TextCatalog(values: [:])

    private let values: [String: String]

    static var shared: TextCatalog {
        installedShared
    }

    init(baseURL: URL, overrideURL: URL?, fileManager: FileManager = .default) throws {
        let baseValues = try Self.loadValues(from: baseURL, fileManager: fileManager)
        let overrideValues = try Self.loadValues(from: overrideURL, fileManager: fileManager)
        self.values = baseValues.merging(overrideValues) { _, override in override }
    }

    static func installShared(_ catalog: TextCatalog) {
        installedShared = catalog
    }

    @discardableResult
    static func reloadShared(
        appPaths: AppPaths? = nil,
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default
    ) throws -> TextCatalog {
        let catalog = try TextCatalog.live(
            appPaths: appPaths,
            repoRootURL: repoRootURL,
            fileManager: fileManager
        )
        installShared(catalog)
        notificationCenter.post(name: .icuCopyDidChange, object: nil)
        return catalog
    }

    static func live(
        appPaths: AppPaths? = nil,
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default
    ) throws -> TextCatalog {
        let baseURL = resolvedBaseURL(appPaths: appPaths, repoRootURL: repoRootURL)
        let overrideURL = resolvedOverrideURL(appPaths: appPaths, repoRootURL: repoRootURL, fileManager: fileManager)
        return try TextCatalog(baseURL: baseURL, overrideURL: overrideURL, fileManager: fileManager)
    }

    func text(_ key: UserVisibleCopyKey, fallback: String) -> String {
        values[key.rawValue] ?? fallback
    }

    func text(_ key: UserVisibleCopyKey) -> String {
        text(key, fallback: key.defaultValue)
    }

    func text(_ rawKey: String, fallback: String) -> String {
        values[rawKey] ?? fallback
    }

    private init(values: [String: String]) {
        self.values = values
    }

    private static func resolvedBaseURL(appPaths: AppPaths?, repoRootURL: URL?) -> URL {
        if let repoRootURL {
            return repoRootURL
                .appendingPathComponent("config", isDirectory: true)
                .appendingPathComponent("copy", isDirectory: true)
                .appendingPathComponent("base.json", isDirectory: false)
        }

        if let appPaths {
            return appPaths.configDirectory
                .appendingPathComponent("copy", isDirectory: true)
                .appendingPathComponent("base.json", isDirectory: false)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("copy", isDirectory: true)
            .appendingPathComponent("base.json", isDirectory: false)
    }

    private static func resolvedOverrideURL(appPaths: AppPaths?, repoRootURL: URL?, fileManager: FileManager) -> URL? {
        if let appPaths {
            let appSupportOverride = appPaths.configDirectory
                .appendingPathComponent("copy", isDirectory: true)
                .appendingPathComponent("active.json", isDirectory: false)
            if fileManager.fileExists(atPath: appSupportOverride.path) {
                return appSupportOverride
            }
        }

        if let repoRootURL {
            let repoOverride = repoRootURL
                .appendingPathComponent("config", isDirectory: true)
                .appendingPathComponent("copy", isDirectory: true)
                .appendingPathComponent("active.json", isDirectory: false)
            if fileManager.fileExists(atPath: repoOverride.path) {
                return repoOverride
            }
        }

        return nil
    }

    private static func loadValues(from url: URL?, fileManager: FileManager) throws -> [String: String] {
        guard let url else {
            return [:]
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return flatten(object: object, prefix: nil)
    }

    private static func flatten(object: [String: Any], prefix: String?) -> [String: String] {
        var flattened: [String: String] = [:]

        for (key, value) in object {
            let fullKey = prefix.map { "\($0).\(key)" } ?? key

            if let stringValue = value as? String {
                flattened[fullKey] = stringValue
            } else if let nestedObject = value as? [String: Any] {
                flattened.merge(flatten(object: nestedObject, prefix: fullKey)) { current, _ in current }
            }
        }

        return flattened
    }
}
