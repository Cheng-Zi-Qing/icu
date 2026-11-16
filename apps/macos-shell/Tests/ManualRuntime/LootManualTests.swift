import Foundation

private func repoLootConfig() throws -> LootConfig {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    func json(_ name: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("config/loot/\(name)")))
    }
    return LootConfig(chestsJSON: try json("chests.json"), materialsJSON: try json("materials.json"))
}

private let lootNow = Date(timeIntervalSince1970: 1_794_470_400)
private let lootDay = "2026-11-12"

private func granting(_ events: [LootEvent], to state: LootState = .empty, config: LootConfig, day: String = lootDay) -> (LootState, [LootGrant]) {
    let engine = LootEngine(config: config)
    return events.reduce((state, [LootGrant]())) { result, event in
        let (next, grant) = engine.grant(event, to: result.0, day: day, at: lootNow)
        return (next, result.1 + [grant])
    }
}

func testLootConfigFromRepoHasEveryMaterialAndChest() throws {
    let config = try repoLootConfig()
    try expect(config.materials.count == 26, "every material in PRD 2.1 §4.2 (got \(config.materials.count))")
    try expect(config.chests.count == ChestKind.allCases.count, "five chest kinds")
    try expect(config.chest(.wood).hatchMinutes == 10 && config.chest(.iron).hatchMinutes == 25 && config.chest(.gold).hatchMinutes == 60, "hatch times from the PRD")
    try expect(config.rules == .default, "rules in chests.json match the PRD defaults")
    let positive = config.materials.filter { !$0.task.isNegative }
    try expect(positive.allSatisfy { [.white, .blue, .purple].contains($0.tier) }, "chests only give white to purple for good tasks")
    try expect(config.materials.filter { $0.task == .slack }.allSatisfy { $0.tier == .gray }, "slack gives gray")
    try expect(config.materials.filter { $0.task == .roughDay }.allSatisfy { $0.tier == .black }, "a rough day gives black")
}

func testLootConfigFallsBackWhenBrokenAndIgnoresOutOfRangeRules() throws {
    try expect(LootConfig(chestsJSON: nil, materialsJSON: nil) == .builtIn, "missing files use the built-in tables")
    let onlyWater: [String: Any] = ["materials": [["id": "dew", "tier": "white", "task": "hydration"]]]
    try expect(LootConfig(chestsJSON: nil, materialsJSON: onlyWater).materials == LootConfig.builtInMaterials, "materials that leave a chest empty are unusable")
    let rules = LootRules(jsonObject: ["incubator_slots": 99, "chest_storage": true, "daily_gray_chest_cap": 2])
    try expect(rules.incubatorSlots == 3 && rules.chestStorage == 10, "out of range or wrong type keeps the default")
    try expect(rules.dailyGrayChestCap == 2, "a valid value is used")
}

func testChestTierRatesMatchTheConfigWithinHalfAPercent() throws {
    let config = try repoLootConfig()
    let roller = LootRoller(config: config)
    var random = SeededLootRandom(seed: 2026)
    let draws = 100_000
    for kind in [ChestKind.wood, .iron, .gold] {
        var counts: [LootTier: Int] = [:]
        for _ in 0..<draws {
            counts[roller.rollTier(for: kind, using: &random), default: 0] += 1
        }
        let weights = config.chest(kind).tierWeights
        let total = weights.values.reduce(0, +)
        for (tier, weight) in weights {
            let observed = Double(counts[tier, default: 0]) / Double(draws)
            let expected = weight / total
            try expect(abs(observed - expected) < 0.005, "\(kind) \(tier): expected \(expected), got \(observed)")
        }
    }
}

func testCompletedRemindersGiveWoodChestsThatStartIncubatingRightAway() throws {
    let config = try repoLootConfig()
    let (state, grants) = granting([.reminderCompleted(.hydration), .reminderCompleted(.eyeCare)], config: config)
    try expect(grants.allSatisfy { if case .chest = $0 { return true } else { return false } }, "each completion gives a chest")
    try expect(state.incubating.map(\.chest.kind) == [.wood, .wood], "both go straight into free incubator slots")
    try expect(state.incubating.map(\.chest.task) == [.hydration, .eyeCare], "the task decides the attributes")
    try expect(state.daily.positiveChests == 2, "counted against today's cap")
}

func testFocusAndBreakNeedToLastLongEnough() throws {
    let config = try repoLootConfig()
    let engine = LootEngine(config: config)
    try expect(engine.chestKind(for: .focusFinished(seconds: 14 * 60)) == nil, "a short focus does not count")
    try expect(engine.chestKind(for: .focusFinished(seconds: 15 * 60))! == (.wood, .focus), "a 15 min focus gives a wood chest")
    try expect(engine.chestKind(for: .breakFinished(seconds: 4 * 60)) == nil, "a short break does not count")
    try expect(engine.chestKind(for: .breakFinished(seconds: 5 * 60))! == (.iron, .standUp), "leaving the screen 5 min gives an iron chest")
}

func testDailyPositiveCapTurnsExtrasIntoShardsAndShardsIntoAWoodChest() throws {
    var config = try repoLootConfig()
    var rules = config.rules
    rules.dailyPositiveChestCap = 6
    rules.chestStorage = 30
    rules.overflowShardsPerChest = 5
    config = LootConfig(rules: rules, chests: config.chests, materials: config.materials)

    let (capped, grants) = granting(Array(repeating: .reminderCompleted(.hydration), count: 10), config: config)
    try expect(capped.daily.positiveChests == 6 && capped.totalChestCount == 6, "only six chests a day")
    try expect(capped.shards == 4, "the four extras became shards (got \(capped.shards))")
    try expect(grants.last == .shard(exchanged: nil), "an extra says it became a shard")

    let (exchanged, last) = granting([.reminderCompleted(.eyeCare)], to: capped, config: config)
    guard case let .shard(exchanged: chest?) = last.first else { throw TestFailure(message: "the fifth shard should be exchanged") }
    try expect(chest.kind == .wood && chest.task == nil, "shards buy a wood chest with any attribute")
    try expect(exchanged.shards == 0 && exchanged.totalChestCount == 7, "shards are spent and the chest is stored")

    let (nextDay, nextGrant) = granting([.reminderCompleted(.hydration)], to: exchanged, config: config, day: "2026-11-13")
    try expect(nextDay.daily.positiveChests == 1, "the cap resets on a new day")
    if case .chest = nextGrant.first {} else { throw TestFailure(message: "a new day gives chests again") }
}

func testGrayBoxesForSkipsAndTheThirdSnoozeWithADailyCap() throws {
    let config = try repoLootConfig()
    let (snoozed, snoozeGrants) = granting([
        .reminderSnoozed(.hydration, times: 1), .reminderSnoozed(.hydration, times: 2),
        .reminderSnoozed(.hydration, times: 3), .reminderSnoozed(.hydration, times: 4),
    ], config: config)
    try expect(snoozeGrants.filter { $0 != .nothing }.count == 1, "only the third snooze of one reminder gives a gray box")
    try expect(snoozed.incubating.first?.chest.kind == .grayBox, "it is a gray box")

    let (skipped, _) = granting(Array(repeating: .reminderSkipped(.eyeCare), count: 6), config: config)
    try expect(skipped.daily.grayBoxes == 4 && skipped.totalChestCount == 4, "at most four gray boxes a day")
    try expect(skipped.shards == 0, "gray boxes never turn into shards")
}

func testGoldOncePerDayAndFullStorageDropsNegativeBoxes() throws {
    var config = try repoLootConfig()
    var rules = config.rules
    rules.chestStorage = 5
    rules.incubatorSlots = 1
    config = LootConfig(rules: rules, chests: config.chests, materials: config.materials)

    let (gold, goldGrants) = granting([.allGoalsMet, .allGoalsMet], config: config)
    try expect(goldGrants[1] == .nothing && gold.totalChestCount == 1, "one gold chest a day")

    let (full, _) = granting(Array(repeating: .reminderCompleted(.hydration), count: 5), to: gold, config: config)
    try expect(full.totalChestCount == 6 && full.storage.count == 5, "five in storage plus one incubating")
    let (afterBlack, black) = granting([.roughDay, .reminderCompleted(.eyeCare)], to: full, config: config)
    try expect(black[0] == .nothing, "no room: the black box is not given")
    try expect(black[1] == .shard(exchanged: nil) && afterBlack.shards == 1, "no room: a good chest becomes a shard")
}

func testIncubationCountsOnlyGivenSecondsAndRefillsSlots() throws {
    var config = try repoLootConfig()
    var rules = config.rules
    rules.incubatorSlots = 1
    config = LootConfig(rules: rules, chests: config.chests, materials: config.materials)
    let (state, _) = granting([.reminderCompleted(.hydration), .reminderCompleted(.eyeCare)], config: config)
    let incubator = LootIncubator(config: config)
    var random = SeededLootRandom(seed: 7)

    let (halfway, none) = incubator.advance(state, bySeconds: 599, day: lootDay, unownedOutfits: [], using: &random)
    try expect(none.isEmpty && halfway.incubating.first?.progressSeconds == 599, "not hatched one second early")
    let (zero, _) = incubator.advance(halfway, bySeconds: 0, day: lootDay, unownedOutfits: [], using: &random)
    try expect(zero == halfway, "no on-duty time, no progress")

    let (both, openings) = incubator.advance(halfway, bySeconds: 601, day: lootDay, unownedOutfits: [], using: &random)
    try expect(openings.count == 2, "one call can hatch the first chest and then the one queued behind it (got \(openings.count))")
    try expect(both.totalChestCount == 0, "both chests are gone")
    let tasks = openings.compactMap { $0.materialIDs.first.flatMap(config.material)?.task }
    try expect(tasks == [.hydration, .eyeCare], "materials follow the task (got \(tasks))")
    try expect(both.materials.values.reduce(0, +) == 2 && both.unseen.count == both.discovered.count, "materials land in the backpack as new")
}

func testGoldChestOpensThreeMaterialsOfStarsAndDreams() throws {
    let config = try repoLootConfig()
    let (state, _) = granting([.allGoalsMet], config: config)
    var random = SeededLootRandom(seed: 11)
    let (_, openings) = LootIncubator(config: config).advance(state, bySeconds: 3600, day: lootDay, unownedOutfits: [], using: &random)
    let materials = openings.first?.materialIDs.compactMap(config.material) ?? []
    try expect(materials.count == 3, "a gold chest rolls three times")
    try expect(materials.allSatisfy { $0.task == .fullDay && $0.tier >= .blue }, "stars and dreams, blue or purple")
}

func testOutfitDropsNeverRepeatHonourPityAndTheDailyLimit() throws {
    var config = try repoLootConfig()
    var rules = config.rules
    rules.outfitDropChance = 0
    rules.outfitPityThreshold = 3
    rules.maxOutfitDropsPerDay = 1
    config = LootConfig(rules: rules, chests: config.chests, materials: config.materials)
    let roller = LootRoller(config: config)
    var random = SeededLootRandom(seed: 3)
    let candidates = [OutfitCandidate(id: "duck", isRare: true), OutfitCandidate(id: "bell", isRare: false)]

    var state = LootState.empty.onDay(lootDay)
    for streak in 1...3 {
        let (dropped, next) = roller.rollOutfit(tier: .white, candidates: candidates, state: state, using: &random)
        try expect(dropped == nil && next == streak, "no luck builds the streak")
        state = state.with { $0.outfitDryStreak = next }
    }
    let (pity, reset) = roller.rollOutfit(tier: .white, candidates: candidates, state: state, using: &random)
    try expect(pity == "bell" && reset == 0, "after three misses the next one drops, common for a white roll")
    let (rare, _) = roller.rollOutfit(tier: .purple, candidates: candidates, state: state, using: &random)
    try expect(rare == "duck", "a purple roll prefers a rare outfit")

    let limited = state.with { $0.daily.outfitDrops = 1 }
    try expect(roller.rollOutfit(tier: .white, candidates: candidates, state: limited, using: &random).outfitID == nil, "daily limit")
    try expect(roller.rollOutfit(tier: .white, candidates: [], state: state, using: &random).outfitID == nil, "everything owned: no outfit")

    // 一次孵好两个：同一件装扮不会掉两次；负面匣子不掉装扮
    rules.maxOutfitDropsPerDay = 5
    rules.outfitDropChance = 1
    config = LootConfig(rules: rules, chests: config.chests, materials: config.materials)
    let (two, _) = granting([.reminderCompleted(.hydration), .reminderCompleted(.eyeCare), .reminderSkipped(.hydration)], config: config)
    let (_, openings) = LootIncubator(config: config).advance(two, bySeconds: 900, day: lootDay, unownedOutfits: [candidates[1]], using: &random)
    try expect(openings.compactMap(\.outfitID) == ["bell"], "one outfit cannot drop twice (got \(openings.compactMap(\.outfitID)))")
    try expect(openings.first { $0.chest.kind == .grayBox }?.outfitID == nil, "gray boxes never drop outfits")
}

func testDayVerdictForGoldAndRoughDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let verdict = LootDayVerdict(calendar: calendar)
    let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 9))!
    func day(eye: (Int, Int), water: (Int, Int), work: Int = 8 * 3600, clockOut: Date? = nil) -> HealthDaySummary {
        HealthDaySummary(
            date: morning,
            eyeReminder: HealthReminderCounts(shown: eye.0, completed: eye.1, snoozed: 0, skipped: 0),
            hydrationReminder: HealthReminderCounts(shown: water.0, completed: water.1, snoozed: 0, skipped: 0),
            workDuration: work, focusCount: 0, focusDuration: 0, breakCount: 0,
            shiftCount: 1, firstClockInAt: morning, lastClockOutAt: clockOut ?? morning.addingTimeInterval(TimeInterval(work))
        )
    }
    try expect(verdict.allGoalsMet(day(eye: (5, 4), water: (8, 8)), cupsGoal: 8), "cups done and 80% eyes is gold")
    try expect(!verdict.allGoalsMet(day(eye: (5, 3), water: (8, 8)), cupsGoal: 8), "60% eyes is not")
    try expect(!verdict.allGoalsMet(day(eye: (5, 5), water: (8, 7)), cupsGoal: 8), "one cup short is not")

    try expect(!verdict.isRough(day(eye: (5, 4), water: (8, 8)), workHours: 8), "a good day is not rough")
    try expect(verdict.isRough(day(eye: (5, 1), water: (5, 2)), workHours: 8), "30% completion is rough")
    try expect(!verdict.isRough(day(eye: (2, 0), water: (0, 0)), workHours: 8), "two skipped reminders alone are not")
    try expect(verdict.isRough(day(eye: (0, 0), water: (0, 0), work: 10 * 3600 + 60), workHours: 8), "more than two hours over is rough")
    let late = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 23, minute: 10))!
    try expect(verdict.isRough(day(eye: (0, 0), water: (0, 0), work: 3600, clockOut: late), workHours: 8), "still at work after 23:00 is rough")
}

func testLootStoreRoundTripsReadsOldSavesAndSetsCorruptFilesAside() throws {
    let config = try repoLootConfig()
    let directory = try makeTemporaryDirectory()
    let store = LootStore(fileURL: directory.appendingPathComponent("loot.json"))
    try expect(store.load(config: config) == .empty, "no save is an empty backpack")

    let (state, _) = granting([.reminderCompleted(.hydration)], config: config)
    let saved = state.with { $0.materials = ["dew": 2, "gone": 1]; $0.discovered = ["dew", "gone"] }
    try store.save(saved)
    let loaded = store.load(config: config)
    try expect(loaded.incubating == saved.incubating && loaded.daily == saved.daily, "chests and counters survive")
    try expect(loaded.materials == ["dew": 2] && loaded.discovered == ["dew"], "materials no longer in the config are dropped")

    try writeText(at: store.fileURL, contents: #"{"materials": {"dew": 3}}"#)
    try expect(store.load(config: config).materials == ["dew": 3], "an older save with missing fields still loads")

    try writeText(at: store.fileURL, contents: "not json")
    try expect(store.load(config: config, now: lootNow) == .empty, "a corrupt save starts empty")
    let kept = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    try expect(kept.contains { $0.hasPrefix("loot.json.corrupt-") }, "the corrupt file is kept aside (got \(kept))")
}

func testHealthTrackerReportsFinishedSegmentsAndReminderOutcomesForLoot() throws {
    let store = try HealthMetricsStore(appPaths: try makeTemporaryAppPaths(), calendar: testUTCCalendar)
    let tracker = HealthSessionTracker(store: store)
    var activity: [HealthActivity] = []
    tracker.onActivity = { activity.append($0) }
    let start = Date(timeIntervalSince1970: 1_744_000_000)

    try tracker.recordStateTransition(from: .idle, to: .working, at: start)
    try tracker.recordStateTransition(from: .working, to: .focus, at: start.addingTimeInterval(60))
    try tracker.checkpoint(at: start.addingTimeInterval(660))
    try tracker.suspend(at: start.addingTimeInterval(1_000))
    tracker.resume(at: start.addingTimeInterval(5_000))
    try tracker.recordStateTransition(from: .focus, to: .working, at: start.addingTimeInterval(5_200))
    try expect(activity == [.segmentFinished(.focus, seconds: 1_140)], "focus counts across checkpoints but not while asleep (got \(activity))")

    activity = []
    try tracker.recordStateTransition(from: .working, to: .breakState, at: start.addingTimeInterval(6_000))
    try tracker.recordStateTransition(from: .breakState, to: .idle, at: start.addingTimeInterval(6_400))
    try expect(activity == [.segmentFinished(.breakState, seconds: 400)], "a break ended by clocking out still counts")

    activity = []
    let payload = ReminderPresentationPayload(id: UUID(), type: .hydration, text: "", snoozeCount: 2)
    try tracker.recordReminderShown(payload, at: start)
    try tracker.recordReminderOutcome(for: payload, outcome: .snoozed, at: start)
    try expect(activity == [.reminderOutcome(id: payload.id, type: .hydration, outcome: .snoozed, snoozeCount: 2)], "the outcome carries how often it was snoozed before")
}

// MARK: - 接到 app 上

@MainActor
private final class LootHarness {
    var summaries: [String: HealthDaySummary] = [:]
    var unowned: [OutfitCandidate] = []
    var granted: [String] = []
    var said: [String] = []
    var canSpeak = true
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    func hooks() -> LootCoordinator.Hooks {
        let key = LootDayKey(calendar: calendar)
        return LootCoordinator.Hooks(
            daySummary: { [unowned self] in self.summaries[key.key(for: $0)] },
            goals: { (8, 8) },
            unownedOutfits: { [unowned self] in self.unowned },
            grantOutfit: { [unowned self] in self.granted.append($0); return true },
            canAnnounce: { [unowned self] in self.canSpeak },
            announce: { [unowned self] in self.said.append($0) }
        )
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func summary(day: Int, eye: (Int, Int) = (0, 0), water: (Int, Int) = (0, 0), work: Int = 3600) -> HealthDaySummary {
        HealthDaySummary(
            date: date(day, 9),
            eyeReminder: HealthReminderCounts(shown: eye.0, completed: eye.1, snoozed: 0, skipped: 0),
            hydrationReminder: HealthReminderCounts(shown: water.0, completed: water.1, snoozed: 0, skipped: 0),
            workDuration: work, focusCount: 0, focusDuration: 0, breakCount: 0,
            shiftCount: 1, firstClockInAt: date(day, 9), lastClockOutAt: date(day, 9).addingTimeInterval(TimeInterval(work))
        )
    }
}

@MainActor
private func withChineseCopy(_ body: () throws -> Void) throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    TextCatalog.installShared(try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: .chinese))
    try body()
}

@MainActor
func testLootCoordinatorGivesOneChestPerReminderAndWaitsToSpeak() throws {
    try withChineseCopy {
        let harness = LootHarness()
        let store = LootStore(fileURL: try makeTemporaryDirectory().appendingPathComponent("loot.json"))
        let loot = LootCoordinator(config: try repoLootConfig(), store: store, hooks: harness.hooks(), calendar: harness.calendar, seed: 1)
        let id = UUID()
        let now = harness.date(12, 10)

        harness.canSpeak = false
        loot.handle(.reminderOutcome(id: id, type: .hydration, outcome: .completed, snoozeCount: 0), at: now)
        loot.handle(.reminderOutcome(id: id, type: .hydration, outcome: .completed, snoozeCount: 0), at: now)
        loot.handle(.reminderOutcome(id: UUID(), type: .eyeCare, outcome: .shown, snoozeCount: 0), at: now)
        try expect(loot.state.totalChestCount == 1, "the same reminder only pays once (got \(loot.state.totalChestCount))")
        try expect(store.load(config: loot.config).incubating.count == 1, "the chest is saved right away")
        try expect(harness.said.isEmpty && loot.pendingNotices.count == 1, "quiet while focusing or fullscreen")

        harness.canSpeak = true
        loot.flushNotices()
        try expect(harness.said == ["拿到一个木宝箱，上班时慢慢孵"], "said once it can speak (got \(harness.said))")

        loot.handle(.reminderOutcome(id: UUID(), type: .hydration, outcome: .snoozed, snoozeCount: 2), at: now)
        try expect(loot.state.incubating.last?.chest.kind == .grayBox, "the third snooze of one reminder gives a gray box")
        loot.handle(.segmentFinished(.focus, seconds: 20 * 60), at: now)
        try expect(loot.state.incubating.map(\.chest.task) == [.hydration, .slack, .focus], "a long enough focus gives a chest too")
    }
}

@MainActor
func testLootCoordinatorHatchesOnlyOnDutyAndHandsOutfitsToTheWardrobe() throws {
    try withChineseCopy {
        let harness = LootHarness()
        harness.unowned = [OutfitCandidate(id: "bell", isRare: false)]
        let base = try repoLootConfig()
        var rules = base.rules
        rules.outfitDropChance = 1
        let config = LootConfig(rules: rules, chests: base.chests, materials: base.materials)
        let store = LootStore(fileURL: try makeTemporaryDirectory().appendingPathComponent("loot.json"))
        let loot = LootCoordinator(config: config, store: store, hooks: harness.hooks(), calendar: harness.calendar, seed: 4)
        let start = harness.date(12, 10)
        loot.handle(.reminderOutcome(id: UUID(), type: .hydration, outcome: .completed, snoozeCount: 0), at: start)
        harness.said = []

        loot.tick(isOnDuty: true, at: start)
        loot.tick(isOnDuty: false, at: start.addingTimeInterval(3600))
        try expect(loot.state.incubating.first?.progressSeconds == 0, "an hour off duty does not hatch anything")
        for minute in 1...9 {
            loot.tick(isOnDuty: true, at: start.addingTimeInterval(3600 + Double(minute) * 60))
        }
        try expect(loot.state.incubating.first?.progressSeconds == 540, "nine on-duty minutes")
        loot.resetClock(at: nil)
        loot.tick(isOnDuty: true, at: start.addingTimeInterval(9 * 3600))
        try expect(loot.state.incubating.first?.progressSeconds == 540, "waking from sleep does not count the night")
        loot.tick(isOnDuty: true, at: start.addingTimeInterval(9 * 3600 + 3600))
        try expect(loot.state.incubating.isEmpty, "a long gap still counts at most \(LootCoordinator.maxTickSeconds) s, enough for the last minute")
        try expect(loot.state.materials.values.reduce(0, +) == 1, "the wood chest opened one material")
        try expect(harness.granted == ["bell"], "the outfit goes to the wardrobe")
        try expect(harness.said == ["宝箱里掉出一件装扮：铃铛！"], "the pet says what fell out (got \(harness.said))")
    }
}

@MainActor
func testLootCoordinatorGivesGoldOnTheGoodDayAndBlackForARoughOneOnce() throws {
    try withChineseCopy {
        let harness = LootHarness()
        let store = LootStore(fileURL: try makeTemporaryDirectory().appendingPathComponent("loot.json"))
        let loot = LootCoordinator(config: try repoLootConfig(), store: store, hooks: harness.hooks(), calendar: harness.calendar, seed: 9)

        harness.summaries["2026-11-11"] = harness.summary(day: 11, eye: (5, 1), water: (5, 1))
        loot.tick(isOnDuty: true, at: harness.date(11, 22))
        loot.tick(isOnDuty: true, at: harness.date(11, 22, 1))
        try expect(loot.state.totalChestCount == 0, "no black box while the day is still going")

        loot.tick(isOnDuty: false, at: harness.date(12, 9))
        try expect(loot.state.storage.map(\.kind) + loot.state.incubating.map(\.chest.kind) == [.blackBox], "a rough yesterday leaves one black box")
        try expect(harness.said.last == "昨天辛苦了，留给你一个黑匣", "said gently (got \(harness.said))")
        loot.tick(isOnDuty: false, at: harness.date(12, 10))
        try expect(loot.state.totalChestCount == 1, "settled only once")

        harness.summaries["2026-11-12"] = harness.summary(day: 12, eye: (5, 4), water: (8, 8))
        loot.handle(.reminderOutcome(id: UUID(), type: .hydration, outcome: .completed, snoozeCount: 0), at: harness.date(12, 17))
        let kinds = loot.state.incubating.map(\.chest.kind) + loot.state.storage.map(\.kind)
        try expect(kinds == [.blackBox, .wood, .gold], "the cup that meets every goal also brings the gold chest (got \(kinds))")
        loot.handle(.reminderOutcome(id: UUID(), type: .hydration, outcome: .completed, snoozeCount: 0), at: harness.date(12, 18))
        try expect(loot.state.totalChestCount == 4, "gold only once a day")
    }
}

@MainActor
func testBackpackContentShowsSlotsQueueAndACodexWithUnknownMaterials() throws {
    try withChineseCopy {
        let config = try repoLootConfig()
        var rules = config.rules
        rules.incubatorSlots = 2
        let twoSlots = LootConfig(rules: rules, chests: config.chests, materials: config.materials)
        let chest = { (kind: ChestKind) in Chest(id: UUID(), kind: kind, task: .hydration, earnedAt: lootNow) }
        let state = LootState.empty.with {
            $0.incubating = [IncubatingChest(chest: chest(.wood), progressSeconds: 150)]
            $0.storage = [chest(.iron), chest(.gold)]
            $0.shards = 3
            $0.materials = ["dew": 2]
            $0.discovered = ["dew", "pebble"]
            $0.unseen = ["dew"]
        }
        let content = BackpackContent(state: state, config: twoSlots)
        try expect(content.slots.count == 2 && content.slots[1] == nil, "one chest hatching, one empty slot")
        try expect(content.slots[0] == BackpackContent.Slot(kind: .wood, progress: 0.25, minutesLeft: 8), "a quarter done, 7.5 minutes round up to 8")
        try expect(content.queuedChests == 2 && content.shards == 3 && content.shardsPerChest == 10, "queue and shards")
        try expect(content.discoveredCount == 2 && content.materialCount == 26, "codex 2/26")
        try expect(content.groups.map(\.tier) == [.white, .blue, .purple, .gray, .black], "common to rare, then the negative ones")
        let white = content.groups[0].entries
        try expect(white.first { $0.id == "dew" } == BackpackContent.Entry(id: "dew", name: "露珠", count: 2, isNew: true), "owned and new")
        try expect(white.first { $0.id == "pebble" }?.count == 0 && white.first { $0.id == "pebble" }?.name == "小石子", "seen before but used up keeps its name")
        try expect(white.first { $0.id == "warm_sip" }?.name == nil, "never found shows as unknown")
    }
}

func testBackpackMenuEntryOnlyWhenLootIsOn() throws {
    try expect(!DesktopPetMenuModel(state: .idle).items.contains(.openBackpack), "no backpack when loot is off")
    try expect(
        DesktopPetMenuModel(state: .working, showsBackpack: true).sections[1] == [.showTodayReport, .openWardrobe, .openBackpack, .openSettings],
        "the backpack sits next to the wardrobe"
    )
    try expect(
        StatusItemMenuModel(showsBackpack: true).sections[1] == [.showTodayReport, .openWardrobe, .openBackpack, .openSettings],
        "the status menu has it too"
    )
}

func testLootIsOnUnlessSettingsTurnItOff() throws {
    let paths = try makeTemporaryAppPaths()
    let store = AppSettingsStore(appPaths: paths, repoRootURL: try makeTemporaryDirectory())
    try expect(store.loadLootEnabled(), "no settings: loot is on")
    let settings = paths.configDirectory.appendingPathComponent("settings.json")
    try writeText(at: settings, contents: #"{"loot_enabled": false, "user": {"work_hours": 8}}"#)
    try expect(!store.loadLootEnabled(), "loot_enabled false turns it off")
    try writeText(at: settings, contents: #"{"loot_enabled": "no"}"#)
    try expect(store.loadLootEnabled(), "a value that is not a boolean is ignored")
}
