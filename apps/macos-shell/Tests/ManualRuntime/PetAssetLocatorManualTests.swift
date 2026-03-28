import Foundation

func writeFixtureFile(at url: URL, contents: String = "fixture") throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(contents.utf8).write(to: url)
}

private func standardizedFileURLs(_ urls: [URL]) -> [URL] {
    urls.map(\.standardizedFileURL)
}

func testPetAssetLocatorFallsBackToRepoBaseImage() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let repoBase = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("base.png", isDirectory: false)
    try writeFixtureFile(at: repoBase)

    let locator = PetAssetLocator(repoRootURL: root)
    let resolved = locator.displayImageURL(for: "capybara", preferredAction: "working")

    try expect(resolved == repoBase, "locator should fall back to repo base asset")
}

func testPetAssetLocatorPrefersAppSupportAssetOverRepoAsset() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let repoBase = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("base.png", isDirectory: false)
    try writeFixtureFile(at: repoBase, contents: "repo")

    let appRoot = root.appendingPathComponent("app-support", isDirectory: true)
    let appBase = appRoot
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("base.png", isDirectory: false)
    try writeFixtureFile(at: appBase, contents: "app")

    let locator = PetAssetLocator(
        appPaths: AppPaths(rootURL: appRoot),
        repoRootURL: root
    )
    let resolved = locator.displayImageURL(for: "capybara", preferredAction: nil)

    try expect(resolved == appBase, "locator should prefer Application Support asset")
}

func testPetAssetLocatorPrefersActionFrameBeforeBase() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let appRoot = root.appendingPathComponent("app-support", isDirectory: true)
    let actionFrame = appRoot
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let base = appRoot
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("base.png", isDirectory: false)
    try writeFixtureFile(at: actionFrame, contents: "action")
    try writeFixtureFile(at: base, contents: "base")

    let locator = PetAssetLocator(appPaths: AppPaths(rootURL: appRoot), repoRootURL: nil)
    let resolved = locator.displayImageURL(for: "capybara", preferredAction: "working")

    try expect(resolved == actionFrame, "locator should prefer action frame before base asset")
}

func testPetAssetLocatorResolvesMultiFrameDirectoryAnimation() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let petRoot = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let frame0 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let frame1 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("1.png", isDirectory: false)
    try writeFixtureFile(at: frame0, contents: "f0")
    try writeFixtureFile(at: frame1, contents: "f1")

    let locator = PetAssetLocator(repoRootURL: root)
    let animation = locator.resolveAnimation(for: "capybara", preferredAction: "idle")

    try expect(animation?.stateID == "idle", "multi-frame animation should keep requested state")
    try expect(animation?.variantID == "main", "multi-frame animation should use directory variant")
    try expect(
        standardizedFileURLs(animation?.frameURLs ?? []) == standardizedFileURLs([frame0, frame1]),
        "multi-frame animation should include all frames in order"
    )
}

func testPetAssetLocatorNormalizesLegacySingleFrameAnimation() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let legacyFrame = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try writeFixtureFile(at: legacyFrame, contents: "legacy")

    let locator = PetAssetLocator(repoRootURL: root)
    let animation = locator.resolveAnimation(for: "capybara", preferredAction: "working")

    try expect(animation?.stateID == "working", "legacy frame should keep state id")
    try expect(
        standardizedFileURLs(animation?.frameURLs ?? []) == standardizedFileURLs([legacyFrame]),
        "legacy frame should normalize to one-frame animation"
    )
}

func testPetAssetLocatorAppliesConfigAnimationOverrides() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let petRoot = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let mainFrame = petRoot
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let altFrame = petRoot
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("alt", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try writeFixtureFile(at: mainFrame, contents: "main")
    try writeFixtureFile(at: altFrame, contents: "alt")
    try writeFixtureFile(
        at: petRoot.appendingPathComponent("config.json", isDirectory: false),
        contents: """
        {
          "id": "capybara",
          "animations": {
            "working": {
              "default_variant": "alt",
              "fps": 7.5,
              "loop_mode": "once"
            }
          }
        }
        """
    )

    let locator = PetAssetLocator(repoRootURL: root)
    let animation = locator.resolveAnimation(for: "capybara", preferredAction: "working")

    try expect(animation?.variantID == "alt", "config default_variant should select matching variant")
    try expect(
        standardizedFileURLs(animation?.frameURLs ?? []) == standardizedFileURLs([altFrame]),
        "config default_variant should control selected frames"
    )
    try expect(animation?.framesPerSecond == 7.5, "config fps should override default fps")
    try expect(animation?.loopMode == .once, "config loop_mode should override default loop mode")
}

func testPetAssetLocatorDoesNotDuplicateMainVariantWhenItIsDefault() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let petRoot = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let mainFrame = petRoot
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let altFrame = petRoot
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("alt", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try writeFixtureFile(at: mainFrame, contents: "main")
    try writeFixtureFile(at: altFrame, contents: "alt")
    try writeFixtureFile(
        at: petRoot.appendingPathComponent("config.json", isDirectory: false),
        contents: """
        {
          "id": "capybara",
          "animations": {
            "working": {
              "default_variant": "main"
            }
          }
        }
        """
    )

    let locator = PetAssetLocator(repoRootURL: root)
    let animationFamily = locator.resolveAnimationFamily(for: "capybara", preferredAction: "working")

    try expect(animationFamily?.count == 2, "default main variant should not be duplicated in the resolved family")
    try expect(
        animationFamily?.map(\.variantID) == ["main", "alt"],
        "resolved family should keep main first and list each variant only once"
    )
}

func testPetAssetLocatorFallsBackAnimationStateOrderThenBaseImage() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let petRoot = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let alertFrame = petRoot
        .appendingPathComponent("alert", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let workingFrame = petRoot
        .appendingPathComponent("working", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let idleFrame = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try writeFixtureFile(at: alertFrame, contents: "alert")
    try writeFixtureFile(at: workingFrame, contents: "working")
    try writeFixtureFile(at: idleFrame, contents: "idle")

    let locator = PetAssetLocator(repoRootURL: root)
    let fallbackAnimation = locator.resolveAnimation(for: "capybara", preferredAction: "focus")
    try expect(
        fallbackAnimation?.stateID == "alert" && fallbackAnimation?.frameURLs == [alertFrame],
        "missing state should fall back in alert -> working -> idle order"
    )

    try? FileManager.default.removeItem(at: alertFrame)
    let workingFallback = locator.resolveAnimation(for: "capybara", preferredAction: "focus")
    try expect(
        workingFallback?.stateID == "working" && workingFallback?.frameURLs == [workingFrame],
        "missing state should next fall back to working"
    )

    try? FileManager.default.removeItem(at: workingFrame)
    let idleFallback = locator.resolveAnimation(for: "capybara", preferredAction: "focus")
    try expect(
        idleFallback?.stateID == "idle" && idleFallback?.frameURLs == [idleFrame],
        "missing state should then fall back to idle"
    )

    try? FileManager.default.removeItem(at: idleFrame)
    let base = petRoot.appendingPathComponent("base.png", isDirectory: false)
    try writeFixtureFile(at: base, contents: "base")
    let baseFallback = locator.resolveAnimation(for: "capybara", preferredAction: "focus")
    try expect(baseFallback?.stateID == "base", "state fallback should eventually return base image")
    try expect(
        standardizedFileURLs(baseFallback?.frameURLs ?? []) == standardizedFileURLs([base]),
        "base fallback should use base.png as single frame"
    )
}
