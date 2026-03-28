import Foundation

func testThemeManagerFallsBackToPixelThemeWhenStoredPackIsInvalid() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appPaths = try makeTemporaryAppPaths()
    try writeText(
        at: themesDirectory(for: appPaths).appendingPathComponent("broken.json"),
        contents: #"{"meta":{"id":"broken","name":"Broken","version":1},"tokens":{},"components":{}}"#
    )

    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    try settingsStore.saveActiveThemeID("broken")

    let manager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)

    try expect(manager.currentTheme.id == "pixel_default", "invalid stored theme should fall back to pixel default")
    let repairedThemeID = try settingsStore.loadActiveThemeID()
    try expect(repairedThemeID == "pixel_default", "invalid stored theme should be repaired to pixel_default in persisted settings")
}

func testThemeManagerApplyPersistsPackAndLoadsOnNextStartup() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appPaths = try makeTemporaryAppPaths()
    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    let manager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)

    var pack = PixelTheme.pack
    pack.meta.id = "moss_pixel"
    pack.meta.name = "Moss Pixel"
    pack.meta.version = 2
    pack.meta.sourcePrompt = "掌机、苔藓、低饱和像素"

    try manager.apply(pack)

    let fileURL = themesDirectory(for: appPaths).appendingPathComponent("moss_pixel.json")
    try expect(FileManager.default.fileExists(atPath: fileURL.path), "applied pack should be persisted to themes directory")
    let persistedThemeID = try settingsStore.loadActiveThemeID()
    try expect(persistedThemeID == "moss_pixel", "active theme should be persisted after apply")

    let reloadedManager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)
    try expect(reloadedManager.currentTheme.id == "moss_pixel", "startup should reload persisted active theme pack")
}
