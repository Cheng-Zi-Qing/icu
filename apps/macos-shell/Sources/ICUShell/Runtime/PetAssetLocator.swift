import Foundation

struct PetAssetLocator {
    let appPaths: AppPaths?
    let repoRootURL: URL?
    let fileManager: FileManager

    init(
        appPaths: AppPaths? = nil,
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default
    ) {
        self.appPaths = appPaths
        self.repoRootURL = repoRootURL
        self.fileManager = fileManager
    }

    func displayImageURL(for petID: String, preferredAction: String?) -> URL? {
        resolveAnimation(for: petID, preferredAction: preferredAction)?.frameURLs.first
    }

    func resolveAnimation(for petID: String, preferredAction: String?) -> PetAnimationDescriptor? {
        resolveAnimationFamily(for: petID, preferredAction: preferredAction)?.first
    }

    func resolveAnimationFamily(for petID: String, preferredAction: String?) -> [PetAnimationDescriptor]? {
        for petDirectory in candidatePetDirectories(for: petID) {
            if let animations = resolveAnimationFamily(in: petDirectory, preferredAction: preferredAction) {
                return animations
            }
        }

        return nil
    }

    private func candidatePetDirectories(for petID: String) -> [URL] {
        var directories: [URL] = []

        if let appPaths {
            directories.append(
                appPaths.assetsDirectory
                    .appendingPathComponent("pets", isDirectory: true)
                    .appendingPathComponent(petID, isDirectory: true)
            )
        }

        if let repoRootURL {
            directories.append(
                repoRootURL
                    .appendingPathComponent("assets", isDirectory: true)
                    .appendingPathComponent("pets", isDirectory: true)
                    .appendingPathComponent(petID, isDirectory: true)
            )
        }

        return directories
    }

    private func resolveAnimationFamily(
        in petDirectory: URL,
        preferredAction: String?
    ) -> [PetAnimationDescriptor]? {
        let metadata = loadAnimationMetadata(in: petDirectory)

        for stateID in resolutionStateIDs(for: preferredAction) {
            if let animations = resolveStateAnimations(
                in: petDirectory,
                stateID: stateID,
                metadata: metadata[stateID]
            ) {
                return animations
            }
        }

        let baseImage = petDirectory.appendingPathComponent("base.png", isDirectory: false)
        guard fileManager.fileExists(atPath: baseImage.path) else {
            return nil
        }

        return [
            PetAnimationDescriptor(
                stateID: "base",
                variantID: "base",
                frameURLs: [baseImage],
                framesPerSecond: defaultFramesPerSecond(for: preferredAction ?? "idle"),
                loopMode: .loop
            )
        ]
    }

    private func resolveStateAnimations(
        in petDirectory: URL,
        stateID: String,
        metadata: PetAnimationStateMetadata?
    ) -> [PetAnimationDescriptor]? {
        let stateDirectory = petDirectory.appendingPathComponent(stateID, isDirectory: true)
        let variantFrames = animationVariants(in: stateDirectory)
        let defaultFramesPerSecond = self.defaultFramesPerSecond(for: stateID)
        let defaultLoopMode = metadata?.loopMode ?? .loop

        if !variantFrames.isEmpty {
            let orderedVariantIDs = orderedVariantIDs(
                from: variantFrames,
                defaultVariantID: metadata?.defaultVariant
            )
            let animations = orderedVariantIDs.compactMap { variantID -> PetAnimationDescriptor? in
                guard let frameURLs = variantFrames[variantID] else {
                    return nil
                }
                let variantMetadata = metadata?.variants?[variantID]

                return PetAnimationDescriptor(
                    stateID: stateID,
                    variantID: variantID,
                    frameURLs: frameURLs,
                    framesPerSecond: variantMetadata?.fps ?? metadata?.fps ?? defaultFramesPerSecond,
                    loopMode: variantMetadata?.loopMode ?? defaultLoopMode
                )
            }
            return animations.isEmpty ? nil : animations
        }

        let legacyFrame = stateDirectory.appendingPathComponent("0.png", isDirectory: false)
        guard fileManager.fileExists(atPath: legacyFrame.path) else {
            return nil
        }

        return [
            PetAnimationDescriptor(
                stateID: stateID,
                variantID: "main",
                frameURLs: [legacyFrame],
                framesPerSecond: metadata?.fps ?? defaultFramesPerSecond,
                loopMode: defaultLoopMode
            )
        ]
    }

    private func resolutionStateIDs(for preferredAction: String?) -> [String] {
        guard let preferredAction, !preferredAction.isEmpty else {
            return []
        }

        var orderedStateIDs: [String] = []
        for stateID in [preferredAction, "alert", "working", "idle"] {
            if !orderedStateIDs.contains(stateID) {
                orderedStateIDs.append(stateID)
            }
        }
        return orderedStateIDs
    }

    private func animationVariants(in stateDirectory: URL) -> [String: [URL]] {
        guard isDirectory(at: stateDirectory) else {
            return [:]
        }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: stateDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var variants: [String: [URL]] = [:]
        for entry in entries {
            guard isDirectory(at: entry) else {
                continue
            }
            let frames = frameURLs(in: entry)
            if !frames.isEmpty {
                variants[entry.lastPathComponent] = frames
            }
        }

        return variants
    }

    private func frameURLs(in variantDirectory: URL) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: variantDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted(by: compareFrameURLs)
    }

    private func compareFrameURLs(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsName = lhs.deletingPathExtension().lastPathComponent
        let rhsName = rhs.deletingPathExtension().lastPathComponent
        let lhsIndex = Int(lhsName) ?? .max
        let rhsIndex = Int(rhsName) ?? .max

        if lhsIndex == rhsIndex {
            return lhsName < rhsName
        }
        return lhsIndex < rhsIndex
    }

    private func orderedVariantIDs(
        from variants: [String: [URL]],
        defaultVariantID: String?
    ) -> [String] {
        var orderedVariantIDs: [String] = []

        if let defaultVariantID, variants[defaultVariantID] != nil {
            orderedVariantIDs.append(defaultVariantID)
        }
        if variants["main"] != nil && !orderedVariantIDs.contains("main") {
            orderedVariantIDs.append("main")
        }

        for variantID in variants.keys.sorted() where !orderedVariantIDs.contains(variantID) {
            orderedVariantIDs.append(variantID)
        }

        return orderedVariantIDs
    }

    private func loadAnimationMetadata(in petDirectory: URL) -> [String: PetAnimationStateMetadata] {
        let configURL = petDirectory.appendingPathComponent("config.json", isDirectory: false)
        guard
            fileManager.fileExists(atPath: configURL.path),
            let data = try? Data(contentsOf: configURL),
            let config = try? JSONDecoder().decode(PetAnimationConfig.self, from: data)
        else {
            return [:]
        }

        return config.animations ?? [:]
    }

    private func isDirectory(at url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    private func defaultFramesPerSecond(for stateID: String) -> Double {
        switch stateID {
        case "working":
            return 10
        case "alert":
            return 12
        default:
            return 8
        }
    }

    static func inferredRepoRoot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        if let explicitRoot = environment["ICU_REPO_ROOT"] {
            let explicitURL = URL(fileURLWithPath: explicitRoot, isDirectory: true)
            if looksLikeRepoRoot(explicitURL, fileManager: fileManager) {
                return explicitURL
            }
        }

        let searchStarts = [
            URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true),
            URL(fileURLWithPath: CommandLine.arguments[0], isDirectory: false).deletingLastPathComponent(),
        ]

        for start in searchStarts {
            if let root = findRepoRoot(startingAt: start, fileManager: fileManager) {
                return root
            }
        }

        return nil
    }

    private static func findRepoRoot(startingAt start: URL, fileManager: FileManager) -> URL? {
        var current = start.standardizedFileURL

        while true {
            if looksLikeRepoRoot(current, fileManager: fileManager) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return nil
            }
            current = parent
        }
    }

    private static func looksLikeRepoRoot(_ url: URL, fileManager: FileManager) -> Bool {
        let assetsDirectory = url
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("pets", isDirectory: true)
        let shellPackage = url
            .appendingPathComponent("apps", isDirectory: true)
            .appendingPathComponent("macos-shell", isDirectory: true)
            .appendingPathComponent("Package.swift", isDirectory: false)

        return fileManager.fileExists(atPath: assetsDirectory.path)
            && fileManager.fileExists(atPath: shellPackage.path)
    }
}

private struct PetAnimationConfig: Decodable {
    var animations: [String: PetAnimationStateMetadata]?
}

private struct PetAnimationStateMetadata: Decodable {
    var defaultVariant: String?
    var fps: Double?
    var loopMode: PetAnimationLoopMode?
    var variants: [String: PetAnimationVariantMetadata]?

    private enum CodingKeys: String, CodingKey {
        case defaultVariant = "default_variant"
        case fps
        case loopMode = "loop_mode"
        case variants
    }
}

private struct PetAnimationVariantMetadata: Decodable {
    var fps: Double?
    var loopMode: PetAnimationLoopMode?

    private enum CodingKeys: String, CodingKey {
        case fps
        case loopMode = "loop_mode"
    }
}
