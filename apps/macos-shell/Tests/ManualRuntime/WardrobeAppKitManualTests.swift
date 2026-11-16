import AppKit

/// 一只有两套帧的测试桌宠：默认（橙子）是棕色，草帽那套是黄色
private func makeDressablePetView() throws -> (DesktopPetView, URL) {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    let brown = NSColor(deviceRed: 0.7, green: 0.45, blue: 0.3, alpha: 1)
    let yellow = NSColor(deviceRed: 0.9, green: 0.8, blue: 0.4, alpha: 1)
    for (root, color) in [(petRoot, brown), (petRoot.appendingPathComponent("outfits/straw_hat"), yellow)] {
        try makeColorPNG(at: root.appendingPathComponent("idle/main/0.png"), color: color)
        for frame in 0...3 {
            try makeColorPNG(at: root.appendingPathComponent("edge/peek_\(frame).png"), color: color)
        }
    }
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.layoutSubtreeIfNeeded()
    return (view, petRoot)
}

func testDesktopPetViewSwitchesToTheOutfitFramesAndBack() throws {
    let (view, petRoot) = try makeDressablePetView()
    let firstFrame = { view.currentAnimationFamily.first?.frameURLs.first?.standardizedFileURL }
    try expect(firstFrame() == petRoot.appendingPathComponent("idle/main/0.png").standardizedFileURL, "starts with the orange frames")

    view.setOutfit("straw_hat")
    try expect(view.outfitID == "straw_hat", "remembers the outfit")
    try expect(
        firstFrame() == petRoot.appendingPathComponent("outfits/straw_hat/idle/main/0.png").standardizedFileURL,
        "wearing the straw hat swaps in its idle frames (got \(String(describing: firstFrame())))"
    )

    view.setOutfit(nil)
    try expect(firstFrame() == petRoot.appendingPathComponent("idle/main/0.png").standardizedFileURL, "taking it off goes back to the orange")
}

func testDesktopPetViewKeepsPeekingWhenTheOutfitChanges() throws {
    let (view, _) = try makeDressablePetView()
    view.setEdgePeek(true)
    view.setOutfit("straw_hat")
    try expect(view.isPeeking, "changing clothes while peeking keeps the peek pose")
    try expect(view.shownPeekFrame != nil, "a peek frame is still shown")
}

// MARK: - 衣柜窗口

private func repoWardrobeCatalog() throws -> WardrobeCatalog {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("config/wardrobe.json")
    return WardrobeCatalog(jsonObject: try JSONSerialization.jsonObject(with: Data(contentsOf: url)))
}

private final class WardrobeProbe {
    var saved: [WardrobeState] = []
    var previews: [WardrobeState] = []
    var failNextSave = false
}

private struct SaveFailure: Error {}

private func makeWardrobe(_ probe: WardrobeProbe) throws -> WardrobeWindowController {
    let catalog = try repoWardrobeCatalog()
    let art = WardrobeArt(
        itemIcon: { _ in NSImage(size: NSSize(width: 16, height: 16)) },
        preview: { state in probe.previews.append(state); return nil },
        decoration: { _ in nil }
    )
    return WardrobeWindowController(catalog: catalog, state: .initial(for: catalog), art: art) { state in
        if probe.failNextSave {
            probe.failNextSave = false
            throw SaveFailure()
        }
        probe.saved.append(state)
    }
}

private func cell(_ id: String, in controller: WardrobeWindowController) throws -> WardrobeItemCell {
    guard let cell = controller.view.cells.first(where: { $0.itemID == id }) else {
        throw TestFailure(message: "expected a cell for \(id) (have \(controller.view.cells.map(\.itemID)))")
    }
    return cell
}

private func lookOf(_ id: String, _ controller: WardrobeWindowController) -> WardrobeItemCell.Look? {
    controller.view.cells.first { $0.itemID == id }?.look
}

func testWardrobeWindowOpensOnTheHeadPageWearingTheOrange() throws {
    let controller = try makeWardrobe(WardrobeProbe())
    let view = controller.view
    try expect(view.selectedSlot == .head, "opens on 头顶")
    try expect(view.tabButtons.keys.count == 4, "four slot tabs")
    try expect(view.tabButtons[.head]?.title == "头顶", "tab titles come from the slots")
    try expect(view.cells.count == 7, "orange, straw hat and five locked drops (got \(view.cells.count))")
    try expect(lookOf("orange", controller) == .equipped, "the orange is worn")
    try expect(lookOf("straw_hat", controller) == .owned, "the straw hat is owned but not worn")
    let locked = view.cells.filter { $0.look == .locked }
    try expect(locked.count == 5 && locked.allSatisfy { !$0.isEnabled }, "drops not yet found are locked")
    try expect(locked.allSatisfy { $0.accessibilityLabel() == "还没拿到，开宝箱有机会掉落" }, "locked cells never say what the item is")
}

func testWardrobeWindowPutsOnAnOwnedItemAndSavesRightAway() throws {
    let probe = WardrobeProbe()
    let controller = try makeWardrobe(probe)
    try cell("straw_hat", in: controller).performClick(nil)

    try expect(probe.saved.last?.equipped[.head] == "straw_hat", "clicking the straw hat wears it and saves (got \(probe.saved))")
    try expect(lookOf("straw_hat", controller) == .equipped, "the straw hat cell is now ticked")
    try expect(lookOf("orange", controller) == .owned, "the orange comes off")
    try expect(probe.previews.last?.equipped[.head] == "straw_hat", "the fitting stand shows the new look")

    let savesBefore = probe.saved.count
    try cell("straw_hat", in: controller).performClick(nil)
    try expect(probe.saved.count == savesBefore, "clicking what you already wear saves nothing")
}

func testWardrobeTabsShowEachSlot() throws {
    let controller = try makeWardrobe(WardrobeProbe())
    controller.view.tabButtons[.mouth]?.performClick(nil)
    try expect(controller.view.selectedSlot == .mouth, "the mouth tab opens")
    try expect(controller.view.cells.count == 4 && controller.view.cells.allSatisfy { $0.look == .locked }, "nothing in the mouth yet")
    try expect(controller.view.tabButtons[.mouth]?.fillColor == PixelPalette.yellow, "the open tab is highlighted")
}

func testWardrobeSuitsAreLockedUntilEveryPieceIsOwned() throws {
    let probe = WardrobeProbe()
    let controller = try makeWardrobe(probe)
    let suits = controller.view.suitButtons
    try expect(suits.map(\.title) == ["默认", "夏天", "程序员", "春天"], "suits in design order (got \(suits.map(\.title)))")
    try expect(suits[0].isEnabled && suits[1].isEnabled, "默认 and 夏天 can be worn")
    try expect(!suits[2].isEnabled && !suits[3].isEnabled, "程序员 and 春天 are locked")
    try expect(suits[2].icon == .lock, "locked suits show a padlock")
    try expect(suits[0].fillColor == PixelPalette.yellow, "the suit you are wearing is highlighted")

    suits[1].performClick(nil)
    try expect(probe.saved.last?.equipped[.head] == "straw_hat", "wearing 夏天 puts the straw hat on")
    try expect(controller.view.suitButtons[1].fillColor == PixelPalette.yellow, "夏天 is now highlighted")
}

func testWardrobeWindowSaysSoWhenSavingFails() throws {
    let probe = WardrobeProbe()
    probe.failNextSave = true
    let controller = try makeWardrobe(probe)
    try cell("straw_hat", in: controller).performClick(nil)
    try expect(controller.view.message == "没存上，再点一次试试", "a failed save is shown (got \(String(describing: controller.view.message)))")
    try expect(controller.state.equipped[.head] == "orange", "nothing changes when the save fails")

    try cell("straw_hat", in: controller).performClick(nil)
    try expect(controller.view.message == nil && controller.state.equipped[.head] == "straw_hat", "trying again works and clears the message")
}

func testWardrobeCloseButtonClosesTheWindow() throws {
    let controller = try makeWardrobe(WardrobeProbe())
    controller.present()
    try expect(controller.window?.isVisible == true, "the wardrobe opens")
    controller.view.closeButton.performClick(nil)
    try expect(controller.window?.isVisible == false, "the close button closes it")
}

// MARK: - 接到 app 上

@MainActor
func testWardrobeCoordinatorSavesAndDressesThePet() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("config/wardrobe.json")
    let store = WardrobeStore(fileURL: root.appendingPathComponent("state/wardrobe.json"))
    var outfits: [String?] = []
    let coordinator = WardrobeCoordinator(catalogURL: catalogURL, store: store, makeArt: { _ in .none }) { outfits.append($0) }

    try expect(coordinator.outfitID == nil, "a new user wears the orange (base frames)")
    coordinator.open()
    guard let controller = coordinator.windowController else {
        throw TestFailure(message: "opening the wardrobe should create its window")
    }
    controller.equip("straw_hat")
    try expect(outfits == ["straw_hat"], "the pet switches to the straw hat frames (got \(outfits))")
    try expect(coordinator.outfitID == "straw_hat", "the coordinator remembers the new look")

    let reloaded = WardrobeCoordinator(catalogURL: catalogURL, store: store, makeArt: { _ in .none }) { _ in }
    try expect(reloaded.outfitID == "straw_hat", "the look survives a restart")
    controller.close()
}

@MainActor
func testWardrobeCoordinatorFallsBackToTheBuiltInCatalog() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let coordinator = WardrobeCoordinator(
        catalogURL: root.appendingPathComponent("missing.json"),
        store: WardrobeStore(fileURL: root.appendingPathComponent("state/wardrobe.json")),
        makeArt: { _ in .none }
    ) { _ in }
    try expect(coordinator.catalog == .builtIn, "a missing wardrobe.json still gives the orange and the straw hat")
}

func testWardrobeReloadsItsCopyWhenTheLanguageChanges() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    TextCatalog.installShared(try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: .chinese))

    let controller = try makeWardrobe(WardrobeProbe())
    try expect(controller.view.tabButtons[.head]?.title == "头顶", "tabs start in Chinese")
    let orangeBefore = try cell("orange", in: controller)
    try expect(orangeBefore.accessibilityLabel() == "橙子", "item names start in Chinese")

    TextCatalog.installShared(try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: .english))
    NotificationCenter.default.post(name: .icuCopyDidChange, object: nil)

    try expect(controller.view.tabButtons[.head]?.title == "Head", "tabs follow the language")
    let orangeAfter = try cell("orange", in: controller)
    try expect(orangeAfter.accessibilityLabel() == "Orange", "cells are rebuilt with the new names")
    try expect(controller.view.suitButtons.first?.title == "Default", "suit buttons are rebuilt with the new names")
    let locked = controller.view.cells.first { $0.look == .locked }
    try expect(
        locked?.accessibilityLabel() == "Not unlocked yet. Chests can drop it",
        "the locked hint follows too (got \(String(describing: locked?.accessibilityLabel())))"
    )
}
