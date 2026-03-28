import Foundation

struct AvatarSummary: Equatable {
    var id: String
    var name: String
    var style: String
    var previewURL: URL
    var traits: String
    var tone: String
}

struct AvatarCatalog {
    let repoRootURL: URL?
    let appAssetsRootURL: URL?
    let fileManager: FileManager

    init(
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        appAssetsRootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.repoRootURL = repoRootURL
        self.appAssetsRootURL = appAssetsRootURL
        self.fileManager = fileManager
    }

    func loadAvatars() throws -> [AvatarSummary] {
        var avatarsByID: [String: AvatarSummary] = [:]

        for root in candidateAssetsRoots() {
            let petsDirectory = root.appendingPathComponent("pets", isDirectory: true)
            guard let petDirectories = try? fileManager.contentsOfDirectory(
                at: petsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for petDirectory in petDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard
                    let summary = try loadAvatarSummary(at: petDirectory),
                    avatarsByID[summary.id] == nil
                else {
                    continue
                }

                avatarsByID[summary.id] = summary
            }
        }

        return avatarsByID.values.sorted(by: { $0.id < $1.id })
    }

    private func candidateAssetsRoots() -> [URL] {
        var roots: [URL] = []

        if let appAssetsRootURL {
            roots.append(appAssetsRootURL)
        }

        if let repoRootURL {
            roots.append(repoRootURL.appendingPathComponent("assets", isDirectory: true))
        }

        return roots
    }

    private func loadAvatarSummary(at petDirectory: URL) throws -> AvatarSummary? {
        let configURL = petDirectory.appendingPathComponent("config.json", isDirectory: false)
        let previewURL = petDirectory.appendingPathComponent("base.png", isDirectory: false)

        guard
            fileManager.fileExists(atPath: configURL.path),
            fileManager.fileExists(atPath: previewURL.path)
        else {
            return nil
        }

        let data = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(AvatarConfig.self, from: data)
        return AvatarSummary(
            id: config.id,
            name: config.name,
            style: config.style ?? "",
            previewURL: previewURL,
            traits: config.persona?.traits ?? "",
            tone: config.persona?.tone ?? ""
        )
    }
}

private struct AvatarConfig: Decodable {
    var id: String
    var name: String
    var style: String?
    var persona: AvatarPersona?
}

private struct AvatarPersona: Decodable {
    var traits: String?
    var tone: String?
}
