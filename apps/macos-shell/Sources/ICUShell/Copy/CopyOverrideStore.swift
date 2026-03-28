import Foundation

final class CopyOverrideStore {
    private let appPaths: AppPaths
    private let repoRootURL: URL?
    private let fileManager: FileManager

    init(
        appPaths: AppPaths,
        repoRootURL: URL?,
        fileManager: FileManager = .default
    ) {
        self.appPaths = appPaths
        self.repoRootURL = repoRootURL
        self.fileManager = fileManager
    }

    func applySpeechDraft(_ draft: SpeechDraft) throws {
        try draft.validate()
        let activeURL = appPaths.configDirectory
            .appendingPathComponent("copy", isDirectory: true)
            .appendingPathComponent("active.json", isDirectory: false)

        try fileManager.createDirectory(at: activeURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var rootObject = try loadRootObject(from: activeURL)
        rootObject = deepMerge(rootObject, with: draft.overrideRootObject())

        let data = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: activeURL, options: .atomic)

        _ = try TextCatalog.reloadShared(appPaths: appPaths, repoRootURL: repoRootURL, fileManager: fileManager)
    }

    private func loadRootObject(from url: URL) throws -> [String: Any] {
        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GenerationRouteError.invalidResponse("active copy override must be a JSON object")
        }
        return object
    }

    private func deepMerge(_ base: [String: Any], with override: [String: Any]) -> [String: Any] {
        var merged = base

        for (key, value) in override {
            if
                let baseObject = merged[key] as? [String: Any],
                let overrideObject = value as? [String: Any]
            {
                merged[key] = deepMerge(baseObject, with: overrideObject)
            } else {
                merged[key] = value
            }
        }

        return merged
    }
}
