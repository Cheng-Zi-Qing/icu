import Foundation

func testAvatarCatalogListsRepoAvatar() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let petDir = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try writeFixtureFile(at: petDir.appendingPathComponent("base.png", isDirectory: false))
    try writeFixtureFile(
        at: petDir.appendingPathComponent("config.json", isDirectory: false),
        contents: #"{"id":"capybara","name":"卡皮巴拉","style":"16-bit 像素风"}"#
    )

    let catalog = AvatarCatalog(repoRootURL: root, appAssetsRootURL: nil)
    let avatars = try catalog.loadAvatars()

    try expect(avatars.count == 1, "catalog should list one avatar")
    try expect(avatars.first?.id == "capybara", "catalog should list repo avatar")
    try expect(avatars.first?.name == "卡皮巴拉", "catalog should decode avatar name")
}

func testAvatarCatalogPrefersAppAssetsOverRepoAvatar() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let repoPetDir = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("seal", isDirectory: true)
    try writeFixtureFile(at: repoPetDir.appendingPathComponent("base.png", isDirectory: false), contents: "repo")
    try writeFixtureFile(
        at: repoPetDir.appendingPathComponent("config.json", isDirectory: false),
        contents: #"{"id":"seal","name":"仓库海豹","style":"repo"}"#
    )

    let appAssetsRoot = root
        .appendingPathComponent("app-support", isDirectory: true)
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
    let appPetDir = appAssetsRoot.appendingPathComponent("seal", isDirectory: true)
    try writeFixtureFile(at: appPetDir.appendingPathComponent("base.png", isDirectory: false), contents: "app")
    try writeFixtureFile(
        at: appPetDir.appendingPathComponent("config.json", isDirectory: false),
        contents: #"{"id":"seal","name":"应用海豹","style":"app"}"#
    )

    let catalog = AvatarCatalog(repoRootURL: root, appAssetsRootURL: appAssetsRoot.deletingLastPathComponent())
    let avatars = try catalog.loadAvatars()

    try expect(avatars.count == 1, "catalog should de-duplicate avatar IDs")
    try expect(avatars.first?.name == "应用海豹", "app assets avatar should override repo avatar")
    try expect(avatars.first?.style == "app", "app assets metadata should win")
}
