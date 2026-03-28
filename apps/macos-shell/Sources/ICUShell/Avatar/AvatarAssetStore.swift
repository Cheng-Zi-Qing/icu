import Foundation

final class AvatarAssetStore {
    private let repoRootURL: URL
    private let fileManager: FileManager

    init(
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default
    ) {
        self.repoRootURL = repoRootURL
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        self.fileManager = fileManager
    }

    func saveCustomAvatar(
        name: String,
        persona: String,
        generatedActionImageURLs: [String: URL]
    ) throws -> String {
        let avatarID = makeAvatarID(from: name)
        let avatarDirectory = avatarsRootURL
            .appendingPathComponent(avatarID, isDirectory: true)

        try fileManager.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)

        for action in ["idle", "working", "alert"] {
            guard let sourceURL = generatedActionImageURLs[action] else {
                continue
            }

            let actionDirectory = avatarDirectory.appendingPathComponent(action, isDirectory: true)
            try fileManager.createDirectory(at: actionDirectory, withIntermediateDirectories: true)
            let destinationURL = actionDirectory.appendingPathComponent("0.png", isDirectory: false)
            try copyItemReplacingIfNeeded(from: sourceURL, to: destinationURL)
        }

        if let idleURL = generatedActionImageURLs["idle"] {
            let baseURL = avatarDirectory.appendingPathComponent("base.png", isDirectory: false)
            try copyItemReplacingIfNeeded(from: idleURL, to: baseURL)
        }

        let config = AvatarSavedConfig(
            id: avatarID,
            name: name,
            style: TextCatalog.shared.text("avatar.generated_style_name", fallback: "AI生成"),
            persona: AvatarSavedPersona(
                traits: persona,
                tone: "",
                messages: AvatarSavedMessages(eyeCare: [], stretch: [], hydration: [])
            )
        )
        let configURL = avatarDirectory.appendingPathComponent("config.json", isDirectory: false)
        let data = try JSONEncoder.avatarPrettyEncoder.encode(config)
        try data.write(to: configURL, options: .atomic)

        return avatarID
    }

    private var avatarsRootURL: URL {
        repoRootURL
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("pets", isDirectory: true)
    }

    private func makeAvatarID(from name: String) -> String {
        let lowered = name.lowercased()
        var scalars: [UnicodeScalar] = []
        var lastWasUnderscore = false

        for scalar in lowered.unicodeScalars {
            let isAllowed =
                CharacterSet.lowercaseLetters.contains(scalar) ||
                CharacterSet.decimalDigits.contains(scalar)

            if isAllowed {
                scalars.append(scalar)
                lastWasUnderscore = false
            } else if !lastWasUnderscore {
                scalars.append("_")
                lastWasUnderscore = true
            }
        }

        let slug = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if !slug.isEmpty {
            return slug
        }

        return "custom_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))"
    }

    private func copyItemReplacingIfNeeded(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
}

private struct AvatarSavedConfig: Encodable {
    var id: String
    var name: String
    var style: String
    var persona: AvatarSavedPersona
}

private struct AvatarSavedPersona: Encodable {
    var traits: String
    var tone: String
    var messages: AvatarSavedMessages
}

private struct AvatarSavedMessages: Encodable {
    var eyeCare: [String]
    var stretch: [String]
    var hydration: [String]

    enum CodingKeys: String, CodingKey {
        case eyeCare = "eye_care"
        case stretch
        case hydration
    }
}

private extension JSONEncoder {
    static var avatarPrettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
