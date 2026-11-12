import Foundation

/// 状态条每次刷新都会重新问一遍字：同一种情况要一直是同一句（不然字一直跳），换了情况才换一句，而且不和上一句一样

private func playfulCatalog(_ values: [String: String]) -> TextCatalog {
    TextCatalog.inMemory(values)
}

private func repoCatalog(language: AppLanguage) throws -> TextCatalog {
    try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: language)
}

func testPlayfulLinesKeepOneLinePerSituationAndChangeWhenItChanges() throws {
    let catalog = playfulCatalog([
        "pool.read.0": "翻书中", "pool.read.1": "啃文档", "pool.read.2": "眯眼细看",
        "pool.write.0": "码字中", "pool.write.1": "奋笔疾书",
        "single": "思考中",
    ])
    var rolls = [0, 0, 1, 0]
    let lines = PlayfulLines(roll: { _ in rolls.isEmpty ? 0 : rolls.removeFirst() })

    let first = lines.line(pool: "pool.read", fallback: "single", catalog: catalog)
    try expect(first == "翻书中", "first roll (got \(first))")
    for _ in 0..<5 {
        try expect(lines.line(pool: "pool.read", fallback: "single", catalog: catalog) == first, "same situation, same line: the chip does not flicker")
    }
    try expect(lines.line(pool: "pool.write", fallback: "single", catalog: catalog) == "码字中", "a new situation rolls a new line")
    let back = lines.line(pool: "pool.read", fallback: "single", catalog: catalog)
    try expect(back == "啃文档", "coming back rolls again (got \(back))")
    try expect(lines.line(pool: "pool.none", fallback: "single", catalog: catalog) == "思考中", "an empty pool falls back to the single line")
}

func testPlayfulLinesNeverRepeatTheLineJustSaid() throws {
    let catalog = playfulCatalog(["pool.0": "阿嚏！", "pool.1": "鼻子痒痒…"])
    let lines = PlayfulLines(roll: { _ in 0 })
    let said = (0..<6).map { _ in lines.fresh(pool: "pool", fallback: "pool.0", catalog: catalog) }
    for (previous, next) in zip(said, said.dropFirst()) {
        try expect(previous != next, "two lines in a row are never the same (got \(said))")
    }
}

func testPlayfulLinesFollowALanguageSwitch() throws {
    let chinese = playfulCatalog(["pool.0": "码字中"])
    let english = playfulCatalog(["pool.0": "Scribbling"])
    let lines = PlayfulLines(roll: { _ in 0 })
    _ = lines.line(pool: "pool", fallback: "pool.0", catalog: chinese)
    try expect(lines.line(pool: "pool", fallback: "pool.0", catalog: english) == "Scribbling", "a line from the old language is not kept")
}

/// 文案池：每个 Agent 活儿、状态、气泡都有中英文两组，而且状态条上的每一句都能整句放进状态条
func testPlayfulPoolsExistInBothLanguages() throws {
    let chinese = try repoCatalog(language: .chinese)
    let english = try repoCatalog(language: .english)
    for pool in PlayfulLines.statusPools + PlayfulLines.bubblePools {
        try expect(chinese.texts(pool).count >= 3, "base.json has at least three lines for \(pool)")
        try expect(english.texts(pool).count >= 3, "en.json has at least three lines for \(pool)")
    }
}

/// 这句话是不是这一组俏皮话里的（其他测试用：状态条的字现在是从一组里抽的）
func isLine(_ text: String?, of pool: AgentLinePool, catalog: TextCatalog = .shared) -> Bool {
    guard let text else { return false }
    return catalog.texts(pool.key).contains(text)
}

func isLine(_ text: String?, of pool: WorkLinePool, catalog: TextCatalog = .shared) -> Bool {
    guard let text else { return false }
    return catalog.texts(pool.key).contains(text)
}

// MARK: - 字跟着画面走：另外画的演法、待机小动作各有自己的一组话

/// scenes.json 里每种另外的演法（variantOf）、每段待机小动作都有一组话，而且算在状态条的池子里
/// （上面那条测试会查中英文都有、下面状态条的测试会查都放得下）
func testEveryAlternativeSceneAndIdleActHasItsOwnLines() throws {
    let url = inferredManualTestRepoRootURL().appendingPathComponent("assets/pets/capybara/work/scenes.json")
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    let scenes = manifest?["scenes"] as? [String: [String: Any]] ?? [:]
    let alternatives = scenes.filter { $0.value["variantOf"] != nil }.keys.sorted()
    try expect(alternatives.count >= 8, "the pipeline draws the alternatives (got \(alternatives))")
    for name in alternatives {
        try expect(SceneLinePool(variant: name) != nil, "\(name) has its own lines")
    }
    for clip in [PetActionClip.sunbathe, .bath, .birdVisit, .yuzuWobble, .nap] {
        try expect(SceneLinePool(clip: clip) != nil, "\(clip) has its own lines")
    }
    let statusPools = Set(PlayfulLines.statusPools)
    try expect(SceneLinePool.allCases.allSatisfy { statusPools.contains($0.key) }, "scene lines are status-chip pools")
}

func testSceneLinesSayWhatIsOnScreen() throws {
    let catalog = playfulCatalog(["agent.lines.surf.0": "终端冲浪…", "pet.lines.bath.0": "泡澡中"])
    try expect(SceneLinePool.line(variant: "surf", catalog: catalog) == "终端冲浪…", "surfing says surfing")
    try expect(SceneLinePool.line(clip: .bath, catalog: catalog) == "泡澡中", "bathing says bathing")
    try expect(SceneLinePool.line(variant: "read", catalog: catalog) == nil, "a scene's own way keeps its usual lines")
    try expect(SceneLinePool.line(variant: "button", catalog: catalog) == nil, "no lines written yet: keep the usual ones")
    try expect(SceneLinePool.line(clip: .tickled, catalog: catalog) == nil, "poke reactions keep the usual line")
    try expect(SceneLinePool.line(clip: nil, catalog: catalog) == nil, "nothing playing: nothing to say")
    let reminders = playfulCatalog(["pet.lines.drink.0": "咕咚咕咚", "pet.lines.look_away.0": "看看远处"])
    try expect(SceneLinePool.line(reminder: .hydration, catalog: reminders) == "咕咚咕咚", "a water reminder says so on the chip")
    try expect(SceneLinePool.line(reminder: .eyeCare, catalog: reminders) == "看看远处", "an eye reminder says so on the chip")
}
