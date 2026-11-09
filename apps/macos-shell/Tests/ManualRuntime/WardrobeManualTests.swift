import Foundation

private func repoCatalog() throws -> WardrobeCatalog {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("config/wardrobe.json")
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    return WardrobeCatalog(jsonObject: object)
}

func testWardrobeCatalogFromConfigStartsWithOrangeAndStrawHat() throws {
    let catalog = try repoCatalog()
    let owned = catalog.items.filter(\.isDefaultOwned).map(\.id)
    try expect(owned == ["orange", "straw_hat"], "only the orange and the straw hat are owned at first (got \(owned))")
    try expect(catalog.defaultHead.id == "orange", "the orange is worn by default")
    try expect(catalog.item("straw_hat")?.spriteSet == "straw_hat", "the straw hat has its own frame set")
    try expect(catalog.item("orange")?.spriteSet == nil, "the orange is drawn in the base frames")
    try expect(catalog.items(in: .head).count == 7, "head: orange, straw hat and five drops (got \(catalog.items(in: .head).count))")
    try expect(WardrobeSlot.allCases.map(\.title) == ["头顶", "嘴里", "脖子", "脸上"], "four slots in wardrobe order")
    try expect(catalog.suits.map(\.name) == ["默认", "夏天", "程序员", "春天"], "suits from the design (got \(catalog.suits.map(\.name)))")
}

func testWardrobeCatalogFallsBackWhenTheConfigIsBroken() throws {
    try expect(WardrobeCatalog(jsonObject: nil) == .builtIn, "missing config uses the built-in catalog")
    try expect(WardrobeCatalog(jsonObject: ["items": "nope"]) == .builtIn, "garbage uses the built-in catalog")

    let noDefaultHead: [String: Any] = ["items": [["id": "bell", "slot": "neck", "name": "铃铛"]]]
    try expect(WardrobeCatalog(jsonObject: noDefaultHead) == .builtIn, "a catalog without a default head item is unusable")

    let messy: [String: Any] = [
        "items": [
            ["id": "orange", "slot": "head", "name": "橙子", "default_owned": true],
            ["id": "orange", "slot": "head", "name": "重复"],
            ["id": "cape", "slot": "back", "name": "披风"],
            ["slot": "head", "name": "没有 id"],
        ],
        "suits": [
            ["id": "default", "name": "默认", "items": ["head": "orange"]],
            ["id": "ghost", "name": "幽灵", "items": ["head": "missing"]],
        ],
    ]
    let catalog = WardrobeCatalog(jsonObject: messy)
    try expect(catalog.items.map(\.id) == ["orange"], "duplicates, unknown slots and items without ids are dropped (got \(catalog.items.map(\.id)))")
    try expect(catalog.suits.map(\.id) == ["default"], "suits that use unknown items are dropped")
}

func testWardrobeStateStartsWithTheDefaultsAndOnlyEquipsOwnedItems() throws {
    let catalog = try repoCatalog()
    let start = WardrobeState.initial(for: catalog)
    try expect(start.owned == ["orange", "straw_hat"], "owns the two defaults")
    try expect(start.equipped == [.head: "orange"], "wears the orange")
    try expect(start.outfitID(in: catalog) == nil, "the orange uses the base frames")

    guard let hat = start.equipping("straw_hat", in: catalog) else {
        throw TestFailure(message: "an owned item should be wearable")
    }
    try expect(hat.equipped[.head] == "straw_hat" && start.equipped[.head] == "orange", "equipping returns a new state")
    try expect(hat.outfitID(in: catalog) == "straw_hat", "the straw hat switches to its frame set")
    try expect(start.equipping("duck", in: catalog) == nil, "items not owned yet cannot be worn")
    try expect(start.equipping("nope", in: catalog) == nil, "unknown items cannot be worn")
}

func testWardrobeSuitsNeedEveryPieceAndKeepOtherSlots() throws {
    let catalog = try repoCatalog()
    let start = WardrobeState.initial(for: catalog)
    let summer = try requireSuit("summer", in: catalog)
    let programmer = try requireSuit("programmer", in: catalog)
    try expect(start.canWear(summer), "summer only needs the straw hat")
    try expect(!start.canWear(programmer), "programmer needs drops first")
    try expect(start.wearing(programmer, in: catalog) == nil, "a locked suit cannot be worn")
    try expect(start.wearing(summer, in: catalog)?.equipped == [.head: "straw_hat"], "wearing summer puts the hat on")
    let defaultSuit = try requireSuit("default", in: catalog)
    try expect(start.isWearing(defaultSuit), "the default suit is what you start in")
}

func testWardrobeStateSanitizesWhateverWasSaved() throws {
    let catalog = try repoCatalog()
    let saved = WardrobeState(jsonObject: ["owned": ["straw_hat", "ufo"], "equipped": ["head": "ufo", "neck": "bell", "tail": "x"]])
    let clean = saved.sanitized(for: catalog)
    try expect(clean.owned == ["orange", "straw_hat"], "defaults are always owned, unknown items are dropped (got \(clean.owned))")
    try expect(clean.equipped == [.head: "orange"], "unowned or unknown equipment falls back to the default head (got \(clean.equipped))")
}

func testWardrobeStoreRoundTripsAndSurvivesACorruptFile() throws {
    let catalog = try repoCatalog()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = WardrobeStore(fileURL: root.appendingPathComponent("state/wardrobe.json"))

    try expect(store.load(catalog: catalog) == .initial(for: catalog), "no file yet gives the starting wardrobe")
    let hat = WardrobeState.initial(for: catalog).equipping("straw_hat", in: catalog)!
    try store.save(hat)
    try expect(store.load(catalog: catalog) == hat, "what was saved comes back")

    try Data("{oops".utf8).write(to: root.appendingPathComponent("state/wardrobe.json"))
    try expect(store.load(catalog: catalog) == .initial(for: catalog), "a corrupt file falls back to the starting wardrobe")
}

private func requireSuit(_ id: String, in catalog: WardrobeCatalog) throws -> WardrobeSuit {
    guard let suit = catalog.suits.first(where: { $0.id == id }) else {
        throw TestFailure(message: "expected suit \(id)")
    }
    return suit
}
