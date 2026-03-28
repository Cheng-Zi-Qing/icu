import Foundation

func testAvatarAssetStoreUsesInstalledCopyCatalogForGeneratedStyleLabel() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "avatar": {
            "generated_style_name": "AI生成"
          }
        }
        """,
        overrideJSON: """
        {
          "avatar": {
            "generated_style_name": "像素实验稿"
          }
        }
        """
    )

    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let idleURL = root.appendingPathComponent("idle.png", isDirectory: false)
    try writeFixtureFile(at: idleURL, contents: "idle")

    let store = AvatarAssetStore(repoRootURL: root)
    let avatarID = try store.saveCustomAvatar(
        name: "catalog avatar",
        persona: "文案来源于 copy catalog。",
        generatedActionImageURLs: [
            "idle": idleURL,
        ]
    )

    let configURL = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent(avatarID, isDirectory: true)
        .appendingPathComponent("config.json", isDirectory: false)
    let data = try Data(contentsOf: configURL)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let style = object?["style"] as? String

    try expect(
        style == "像素实验稿",
        "avatar asset store should use the installed copy catalog for the generated style label"
    )
}

func testAvatarAssetStoreWritesCustomAvatarFiles() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let idleURL = root.appendingPathComponent("idle.png", isDirectory: false)
    let workingURL = root.appendingPathComponent("working.png", isDirectory: false)
    let alertURL = root.appendingPathComponent("alert.png", isDirectory: false)
    try writeFixtureFile(at: idleURL, contents: "idle")
    try writeFixtureFile(at: workingURL, contents: "working")
    try writeFixtureFile(at: alertURL, contents: "alert")

    let store = AvatarAssetStore(repoRootURL: root)
    let avatarID = try store.saveCustomAvatar(
        name: "calm capybara",
        persona: "总是淡定地提醒你休息。",
        generatedActionImageURLs: [
            "idle": idleURL,
            "working": workingURL,
            "alert": alertURL,
        ]
    )

    let avatarDir = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent(avatarID, isDirectory: true)

    try expect(avatarID == "calm_capybara", "avatar store should slugify display name")
    try expect(FileManager.default.fileExists(atPath: avatarDir.appendingPathComponent("base.png").path), "base image should exist")
    try expect(FileManager.default.fileExists(atPath: avatarDir.appendingPathComponent("idle/0.png").path), "idle image should exist")
    try expect(FileManager.default.fileExists(atPath: avatarDir.appendingPathComponent("working/0.png").path), "working image should exist")
    try expect(FileManager.default.fileExists(atPath: avatarDir.appendingPathComponent("alert/0.png").path), "alert image should exist")
    try expect(FileManager.default.fileExists(atPath: avatarDir.appendingPathComponent("config.json").path), "config should exist")
}
