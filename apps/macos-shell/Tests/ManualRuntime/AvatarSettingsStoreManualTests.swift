import Foundation

func testAvatarSettingsStorePersistsCurrentAvatarID() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = AvatarSettingsStore(repoRootURL: root)

    try store.saveCurrentAvatarID("seal")

    let current = try store.loadCurrentAvatarID()
    try expect(current == "seal", "settings store should persist current avatar")
}

func testAvatarSettingsStoreFallsBackToNilWhenSettingsFileIsMissing() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let store = AvatarSettingsStore(repoRootURL: root)
    let current = try store.loadCurrentAvatarID()

    try expect(current == nil, "missing settings file should return nil")
}

func testAvatarSettingsStoreUpdatesExistingCurrentAvatarIDWithoutLosingOtherSettings() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let settingsURL = root
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("settings.json", isDirectory: false)
    try writeFixtureFile(
        at: settingsURL,
        contents: """
        {
          "ai": {
            "local_api": {
              "url": "http://localhost:11434"
            }
          },
          "avatar": {
            "current_id": "capybara",
            "custom_avatars": []
          }
        }
        """
    )

    let store = AvatarSettingsStore(repoRootURL: root)
    try store.saveCurrentAvatarID("horse")

    let current = try store.loadCurrentAvatarID()
    let savedData = try Data(contentsOf: settingsURL)
    let savedRoot = try JSONSerialization.jsonObject(with: savedData) as? [String: Any]
    let ai = savedRoot?["ai"] as? [String: Any]

    try expect(current == "horse", "current avatar should update to new selection")
    try expect(ai?["local_api"] != nil, "saving current avatar should preserve unrelated settings")
}

func testAvatarSettingsStorePersistsImageModelsWithoutLosingAvatarSettings() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let settingsURL = root
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("settings.json", isDirectory: false)
    try writeFixtureFile(
        at: settingsURL,
        contents: """
        {
          "ai": {
            "local_api": {
              "url": "http://localhost:11434"
            }
          },
          "avatar": {
            "current_id": "seal",
            "custom_avatars": []
          }
        }
        """
    )

    let store = AvatarSettingsStore(repoRootURL: root)
    let models = [
        BridgeImageModel(
            name: "Stable Diffusion XL",
            url: "stabilityai/stable-diffusion-xl-base-1.0",
            token: "hf_test_token"
        )
    ]

    try store.saveImageModels(models)

    let savedModels = try store.loadImageModels()
    let savedData = try Data(contentsOf: settingsURL)
    let savedRoot = try JSONSerialization.jsonObject(with: savedData) as? [String: Any]
    let avatar = savedRoot?["avatar"] as? [String: Any]

    try expect(savedModels == models, "image models should round-trip through settings store")
    try expect(avatar?["current_id"] as? String == "seal", "saving image models should preserve avatar settings")
}

func testAvatarSettingsStoreFallsBackToRepoSettingsAndWritesUserSelectionToAppSupport() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appRoot = try makeTemporaryDirectory()
    defer {
        try? FileManager.default.removeItem(at: repoRoot)
        try? FileManager.default.removeItem(at: appRoot)
    }

    let repoSettingsURL = repoRoot
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("settings.json", isDirectory: false)
    try writeFixtureFile(
        at: repoSettingsURL,
        contents: """
        {
          "generation": {
            "text_description": {
              "provider": "ollama",
              "base_url": "http://localhost:11434",
              "model": "qwen3.5:35b",
              "auth": {},
              "options": {}
            }
          },
          "avatar": {
            "current_id": "seal",
            "custom_avatars": []
          }
        }
        """
    )

    let appPaths = AppPaths(rootURL: appRoot)
    try appPaths.ensureDirectories()

    let store = AvatarSettingsStore(appPaths: appPaths, repoRootURL: repoRoot)
    let current = try store.loadCurrentAvatarID()
    try expect(current == "seal", "avatar store should fall back to repo settings when app support settings are missing")

    try store.saveCurrentAvatarID("horse")

    let appSettingsURL = appRoot
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("settings.json", isDirectory: false)
    let appData = try Data(contentsOf: appSettingsURL)
    let appRootObject = try JSONSerialization.jsonObject(with: appData) as? [String: Any]
    let repoData = try Data(contentsOf: repoSettingsURL)
    let repoRootObject = try JSONSerialization.jsonObject(with: repoData) as? [String: Any]

    try expect(
        ((appRootObject?["avatar"] as? [String: Any])?["current_id"] as? String) == "horse",
        "avatar selection should be written to Application Support settings"
    )
    try expect(
        ((appRootObject?["generation"] as? [String: Any])?["text_description"] as? [String: Any]) != nil,
        "app support migration should preserve existing repo-backed generation settings"
    )
    try expect(
        ((repoRootObject?["avatar"] as? [String: Any])?["current_id"] as? String) == "seal",
        "avatar migration should leave repo-backed settings unchanged"
    )
}
