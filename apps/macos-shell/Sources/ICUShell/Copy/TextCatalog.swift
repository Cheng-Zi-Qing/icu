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
        try self.init(baseURL: baseURL, localizedURL: nil, overrideURL: overrideURL, fileManager: fileManager)
    }

    /// 合并顺序：中文 base → 英文（选 en 时）→ 用户 override
    init(baseURL: URL, localizedURL: URL?, overrideURL: URL?, fileManager: FileManager = .default) throws {
        var values = try Self.loadValues(from: baseURL, fileManager: fileManager)
        let localizedValues = try Self.loadValues(from: localizedURL, fileManager: fileManager)
        let overrideValues = try Self.loadValues(from: overrideURL, fileManager: fileManager)
        values.merge(localizedValues) { _, localized in localized }
        self.values = values.merging(overrideValues) { _, override in override }
    }

    /// 直接给一组已经展开好的 key（测试用）
    static func inMemory(_ values: [String: String]) -> TextCatalog {
        TextCatalog(values: values)
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
        let language = AppSettingsStore(appPaths: appPaths, repoRootURL: repoRootURL, fileManager: fileManager).loadLanguage()
        return try live(appPaths: appPaths, repoRootURL: repoRootURL, fileManager: fileManager, language: language)
    }

    static func live(
        appPaths: AppPaths? = nil,
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default,
        language: AppLanguage
    ) throws -> TextCatalog {
        let baseURL = resolvedBaseURL(appPaths: appPaths, repoRootURL: repoRootURL)
        let localizedURL = language == .english
            ? baseURL.deletingLastPathComponent().appendingPathComponent("en.json", isDirectory: false)
            : nil
        let overrideURL = resolvedOverrideURL(appPaths: appPaths, repoRootURL: repoRootURL, fileManager: fileManager)
        return try TextCatalog(
            baseURL: baseURL,
            localizedURL: localizedURL,
            overrideURL: overrideURL,
            fileManager: fileManager
        )
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

    /// 没有兜底参数的写法：`config/copy/` 里缺这个 key 时露出 key 本身，方便发现漏翻
    func text(_ rawKey: String) -> String {
        text(rawKey, fallback: rawKey)
    }

    /// 带占位符的文案（`%d`、`%@`…）
    func format(_ rawKey: String, _ arguments: CVarArg...) -> String {
        String(format: text(rawKey), arguments: arguments)
    }

    /// 一组文案池（`config/copy/` 里写成数组，展开成 `key.0`、`key.1`…）
    func texts(_ prefix: String) -> [String] {
        var result: [String] = []
        while let value = values["\(prefix).\(result.count)"] {
            result.append(value)
        }
        return result
    }

    /// 自查用：这份 catalog 现在有哪些 key
    var keys: [String] { values.keys.sorted() }

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
            flattened.merge(flatten(value: value, key: fullKey)) { current, _ in current }
        }

        return flattened
    }

    /// 数组按 `key.0`、`key.1` 展开：提醒卡的多句随机文案池就是数组
    private static func flatten(value: Any, key: String) -> [String: String] {
        if let stringValue = value as? String {
            return [key: stringValue]
        }
        if let nestedObject = value as? [String: Any] {
            return flatten(object: nestedObject, prefix: key)
        }
        if let nestedArray = value as? [Any] {
            return nestedArray.enumerated().reduce(into: [String: String]()) { result, pair in
                result.merge(flatten(value: pair.element, key: "\(key).\(pair.offset)")) { current, _ in current }
            }
        }
        return [:]
    }
}
