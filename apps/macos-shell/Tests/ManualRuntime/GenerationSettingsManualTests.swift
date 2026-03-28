import Foundation

func writeText(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = contents.data(using: .utf8) else {
        throw TestFailure(message: "unable to encode text")
    }
    try data.write(to: url, options: .atomic)
}

func loadJSONObject(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
        throw TestFailure(message: "expected JSON object at \(url.path)")
    }
    return dictionary
}

func makeTemporaryAppPaths() throws -> AppPaths {
    let root = try makeTemporaryDirectory()
    let paths = AppPaths(rootURL: root)
    try paths.ensureDirectories()
    try FileManager.default.createDirectory(at: themesDirectory(for: paths), withIntermediateDirectories: true)
    return paths
}

func themesDirectory(for paths: AppPaths) -> URL {
    paths.stateDirectory.appendingPathComponent("themes", isDirectory: true)
}

func testGenerationSettingsStorePersistsCapabilitiesWithoutDroppingAvatarState() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"{"avatar":{"current_id":"seal"},"timers":{"eye_interval":1200}}"#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    try store.save(
        GenerationSettings(
            activeThemeID: "pixel_default",
            textDescription: GenerationCapabilityConfig(
                provider: .ollama,
                baseURL: "http://localhost:11434",
                model: "qwen3.5:35b",
                auth: [:],
                options: ["temperature": 0.7]
            ),
            animationAvatar: GenerationCapabilityConfig(
                provider: .huggingFace,
                baseURL: "https://api-inference.huggingface.co",
                model: "stabilityai/stable-diffusion-xl-base-1.0",
                auth: ["token": "hf_xxx"],
                options: [:]
            ),
            codeGeneration: GenerationCapabilityConfig(
                provider: .openAICompatible,
                baseURL: "https://example.invalid/v1",
                model: "gpt-4.1-mini",
                auth: ["api_key": "sk-test"],
                options: [:]
            )
        )
    )

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    try expect(
        ((rootObject["avatar"] as? [String: Any])?["current_id"] as? String) == "seal",
        "generation save should preserve avatar.current_id"
    )

    guard let generationBlock = rootObject["generation"] as? [String: Any] else {
        throw TestFailure(message: "generation block should be written")
    }

    try expect(
        ((generationBlock["text_description"] as? [String: Any])?["model"] as? String) == "qwen3.5:35b",
        "text description model should match stored capability"
    )

    try expect(
        (((generationBlock["code_generation"] as? [String: Any])?["auth"] as? [String: Any])?["api_key"] as? String) == "sk-test",
        "code generation auth api_key should be preserved"
    )

    try expect(
        ((rootObject["theme"] as? [String: Any])?["current_id"] as? String) == "pixel_default",
        "active theme should be written"
    )
}

func testGenerationSettingsStoreFallsBackToRepoSettingsAndMigratesWritesToAppSupport() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appRoot = try makeTemporaryDirectory()
    defer {
        try? FileManager.default.removeItem(at: repoRoot)
        try? FileManager.default.removeItem(at: appRoot)
    }

    try writeText(
        at: repoRoot.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "avatar": {
            "current_id": "seal",
            "custom_avatars": []
          },
          "generation": {
            "text_description": {
              "provider": "ollama",
              "base_url": "http://localhost:11434",
              "model": "qwen3.5:35b",
              "auth": {},
              "options": {
                "temperature": 0.7
              }
            }
          }
        }
        """#
    )

    let appPaths = AppPaths(rootURL: appRoot)
    try appPaths.ensureDirectories()
    let store = GenerationSettingsStore(appPaths: appPaths, repoRootURL: repoRoot)

    let loaded = try store.load()
    try expect(
        loaded.textDescription.model == "qwen3.5:35b",
        "store should fall back to repo settings when app support settings are missing"
    )

    try store.save(
        GenerationSettings(
            activeThemeID: "pixel_default",
            textDescription: loaded.textDescription,
            animationAvatar: GenerationCapabilityConfig(
                provider: .huggingFace,
                baseURL: "https://api-inference.huggingface.co",
                model: "stabilityai/stable-diffusion-xl-base-1.0",
                auth: ["token": "hf_live"],
                options: [:]
            ),
            codeGeneration: GenerationCapabilityConfig(
                provider: .openAICompatible,
                baseURL: "https://example.invalid/v1",
                model: "gpt-4.1-mini",
                auth: [:],
                options: [:]
            )
        )
    )

    let appSettingsURL = appRoot
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("settings.json", isDirectory: false)
    let migratedRoot = try loadJSONObject(at: appSettingsURL)
    let repoRootObject = try loadJSONObject(at: repoRoot.appendingPathComponent("config/settings.json"))

    try expect(
        ((migratedRoot["avatar"] as? [String: Any])?["current_id"] as? String) == "seal",
        "saving via app support store should preserve repo-backed avatar defaults during migration"
    )
    try expect(
        (((migratedRoot["generation"] as? [String: Any])?["animation_avatar"] as? [String: Any])?["model"] as? String) == "stabilityai/stable-diffusion-xl-base-1.0",
        "saving via app support store should write migrated settings into Application Support"
    )
    try expect(
        repoRootObject["theme"] == nil,
        "migration writes should not mutate the repo-backed settings file"
    )
}
