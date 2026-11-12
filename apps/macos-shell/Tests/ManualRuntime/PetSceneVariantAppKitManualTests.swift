import AppKit

// 一个场景几种演法（scenes.json 里标了 variantOf 的另几种），开演时抽一种；
// 宽的演法（趴着钓鱼、冲浪 40–50 格）上屏时窗口跟着放宽，水豚一样大

/// 宽 × 高像素的透明 PNG（像素管线的帧就是这样：32 格高，宽度看场景）
private func makeBlankPNG(at url: URL, width: Int, height: Int = 32) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let data = rep.representation(using: .png, properties: [:]) else {
        throw TestFailure(message: "could not make a \(width)x\(height) PNG")
    }
    try data.write(to: url)
}

/// eat 有冲浪（侧身、48 宽）和按按钮（还没画，没帧）两种另外的演法；search 自己追球，另一种是翻箱子
private func writeVariantScenes(in directory: URL) throws {
    try makeBlankPNG(at: directory.appendingPathComponent("eat_0.png"), width: 32)
    try makeBlankPNG(at: directory.appendingPathComponent("surf_0.png"), width: 48)
    try makeBlankPNG(at: directory.appendingPathComponent("search_0.png"), width: 38)
    try makeBlankPNG(at: directory.appendingPathComponent("rummage_0.png"), width: 40)
    let manifest = """
    { "fps": 4, "scenes": {
        "eat": { "frames": ["eat_0.png"], "order": [0] },
        "surf": { "frames": ["surf_0.png"], "order": [0], "variantOf": "eat", "side": true },
        "button": { "frames": [], "order": [], "variantOf": "eat" },
        "search": { "frames": ["search_0.png"], "order": [0], "motion": "chase", "side": true },
        "rummage": { "frames": ["rummage_0.png"], "order": [0], "variantOf": "search" }
    } }
    """
    try manifest.write(to: directory.appendingPathComponent("scenes.json"), atomically: true, encoding: .utf8)
}

private func loadVariantScenes() throws -> PetWorkScenes {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-variants-\(UUID().uuidString)", isDirectory: true)
    try writeVariantScenes(in: directory)
    guard let scenes = PetWorkScenes(directory: directory, canvasPointSize: DesktopPetView.workSceneCanvasSize) else {
        throw TestFailure(message: "variant scenes should load")
    }
    return scenes
}

func testPetWorkScenesListEveryWayToPlayAScene() throws {
    let scenes = try loadVariantScenes()
    let eat = scenes.variants(for: .work(.eat))
    try expect(eat.map(\.name) == ["eat", "button", "surf"], "the scene itself first, then its alternatives by name (got \(eat.map(\.name)))")
    try expect(eat.map(\.isAlternative) == [false, true, true], "only the drawn alternatives count as alternatives")
    try expect(scenes.variants(for: .work(.read)).map(\.name) == ["read"], "a scene without alternatives plays itself (even with no frames)")
    try expect(scenes.isSide(eat[2]) && !scenes.isSide(eat[0]), "surfing is drawn side-on, eating is not")
    try expect(scenes.hasFrames(eat[2]) && !scenes.hasFrames(eat[1]), "an alternative without frames has nothing to play")
}

func testPetWorkScenePlayerPicksOnePlayableVariant() throws {
    let scenes = try loadVariantScenes()
    var offered: [[String]] = []
    let player = PetWorkScenePlayer(now: { 0 }, startsTimer: false, pickVariant: { options in
        offered.append(options.map(\.name))
        return options.last
    })
    player.reload(scenes: scenes)

    player.play(.work(.eat))
    try expect(offered == [["eat", "surf"]], "an alternative with no frames is never offered (got \(offered))")
    try expect(player.variant?.name == "surf" && player.variant?.isAlternative == true, "plays the variant it picked")
    try expect(player.facesSideways, "a side-on variant may turn to look at the cursor")
    try expect(player.image?.size.width == 192, "shows the variant's own frames, 48 px at the usual 4 pt each (got \(player.image?.size.width ?? 0))")

    player.play(.work(.search))
    try expect(player.variant?.name == "rummage" && !player.chases, "rummaging stays put")
    player.play(nil)
    try expect(player.variant == nil && !player.chases && player.facesSideways, "nothing playing: no variant, no chase")

    player.play(.work(.search), preferring: "search")
    try expect(offered.count == 2, "a preferred variant is played without asking the picker")
    try expect(player.variant?.name == "search" && player.chases, "the chase variant runs around")
}

/// 换装后的那套帧里没有抽到的演法：重新抽一种
func testPetWorkScenePlayerRepicksWhenTheOutfitLacksTheVariant() throws {
    let scenes = try loadVariantScenes()
    let player = PetWorkScenePlayer(now: { 0 }, startsTimer: false, pickVariant: { $0.last })
    player.reload(scenes: scenes)
    player.play(.work(.eat))
    try expect(player.variant?.name == "surf", "picked surfing")

    player.reload(scenes: nil)
    try expect(player.scene == .work(.eat) && player.variant == .plain(.work(.eat)), "no frames at all: falls back to the scene itself")
}

func testPetWindowWidthFollowsTheWidestFrame() throws {
    try expect(PetWindowWidth.width(for: nil, normal: 128) == 128, "nothing shown: the usual width")
    try expect(PetWindowWidth.width(for: NSImage(size: NSSize(width: 200, height: 128)), normal: 128) == 200, "a wide frame widens it")
    try expect(PetWindowWidth.width(for: NSImage(size: NSSize(width: 96, height: 128)), normal: 128) == 128, "never narrower than usual")

    let usual = CGRect(x: 400, y: 100, width: 128, height: 152)
    let wide = PetWindowWidth.frame(usual, fittingWidth: 200)
    try expect(wide == CGRect(x: 364, y: 100, width: 200, height: 152), "widens evenly on both sides (got \(wide))")
    try expect(PetWindowWidth.frame(wide, fittingWidth: 128) == usual, "and shrinks back to where it was")
    try expect(PetWindowWidth.frame(usual, fittingWidth: 128) == usual, "already that wide: unchanged")
}

/// 视图上屏一张比平时宽的帧时报新宽度，回到平时的帧再报回来
@MainActor
func testDesktopPetViewReportsTheWidthOfWideFrames() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeVariantScenes(in: petRoot.appendingPathComponent("work", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    var reported: [CGFloat] = []
    view.onPresentedWidthChanged = { reported.append($0) }

    view.workPlayer.play(.work(.eat), preferring: "surf")
    try expect(view.presentedWidth == 192, "surfing needs 192 pt (got \(view.presentedWidth))")
    view.setScene(nil)
    try expect(view.presentedWidth == DesktopPetView.LayoutMetrics.petCanvasWidth, "back to the usual width")
    try expect(reported == [192, DesktopPetView.LayoutMetrics.petCanvasWidth], "reported each change once (got \(reported))")
}

/// 最宽的场景（趴着钓鱼 50 格）也按平时的倍数放大，不会因为宽被缩小
func testTheWidestScenesAreUpscaledLikeTheOthers() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-wide-\(UUID().uuidString)", isDirectory: true)
    let url = directory.appendingPathComponent("rest_fish_0.png")
    try makeBlankPNG(at: url, width: 50)
    guard let image = NSImage(contentsOf: url) else { throw TestFailure(message: "could not read the wide frame") }
    let scaled = PixelArtScaler.upscaledForDisplay(image, canvasPointSize: DesktopPetView.workSceneCanvasSize)
    try expect(scaled.size == NSSize(width: 200, height: 128), "50 px wide at 4 pt each, as tall as usual (got \(scaled.size))")
}

/// 休息：抽到钓鱼就钓鱼（不打盹、不做小动作）；抽到平时坐着（rest 自己没帧）就照常打盹、做小动作、被戳有反应
@MainActor
func testRestingSitsAsUsualOrGoesFishing() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    let work = petRoot.appendingPathComponent("work", isDirectory: true)
    try makeBlankPNG(at: work.appendingPathComponent("rest_fish_0.png"), width: 50)
    let manifest = """
    { "fps": 4, "scenes": { "rest_fish": { "frames": ["rest_fish_0.png"], "order": [0], "variantOf": "rest", "side": true } } }
    """
    try manifest.write(to: work.appendingPathComponent("scenes.json"), atomically: true, encoding: .utf8)
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )

    view.setScene(.rest, preferring: "rest")
    try expect(view.isFreeForIdleActs && view.behavior.isAvailable() && view.canReactToPoke, "resting as usual: naps, idle acts and pokes carry on")

    view.setScene(nil)
    view.setScene(.rest, preferring: "rest_fish")
    try expect(!view.isFreeForIdleActs && !view.behavior.isAvailable(), "fishing: no naps or idle acts on top")
    try expect(view.presentedWidth == 200, "the fishing frame widens the window (got \(view.presentedWidth))")
    try expect(SceneLinePool.line(variant: view.workPlayer.variant?.name) != nil, "fishing has its own lines")
}

/// 贴在左右边上：状态条收起来（半个窗口在屏幕外，摆哪都别扭），鼠标放到身上再露出来；离开边又照常显示
@MainActor
func testStatusChipTucksAwayWhileDockedToASide() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    try expect(!view.statusLabel.isHidden, "shown as usual")
    view.setDockedToSide(true)
    try expect(view.statusLabel.isHidden, "docked to a side: tucked away")
    view.isPointerOverPet = true
    view.updateStatusChipVisibility()
    try expect(!view.statusLabel.isHidden, "hovering the pet shows it")
    view.isPointerOverPet = false
    view.setDockedToSide(false)
    try expect(!view.statusLabel.isHidden, "off the edge: shown again")
}

/// 窗口没放宽时（贴着边），宽的帧不缩小：水豚一样大，两边的道具超出窗口就裁掉
@MainActor
func testAWideFrameInANarrowWindowKeepsThePetSize() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeVariantScenes(in: petRoot.appendingPathComponent("work", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.layoutPetChrome()
    view.workPlayer.play(.work(.eat), preferring: "surf")
    try expect(view.imageView.imageScaling == .scaleNone, "a frame wider than the window is not shrunk")
    view.setScene(nil)
    try expect(view.imageView.imageScaling == .scaleProportionallyUpOrDown, "normal frames fit as before")
}

/// 状态字在脚下面单独一条，不压在水豚身上（以前盖住了腿和屁股）
@MainActor
func testStatusChipSitsBelowThePetNotOnIt() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.setStatusText("静静嚼草")
    view.layoutPetChrome()
    let chip = view.statusLabel.frame
    try expect(chip.height > 0 && chip.maxY <= view.petCanvasRect.minY + 0.5,
               "the chip sits in its own strip under the pet (chip \(chip), pet \(view.petCanvasRect))")
    try expect(view.petCanvasRect.height == DesktopPetView.LayoutMetrics.petCanvasHeight, "the pet keeps its full size")
}
