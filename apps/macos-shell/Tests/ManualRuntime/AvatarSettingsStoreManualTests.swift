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
