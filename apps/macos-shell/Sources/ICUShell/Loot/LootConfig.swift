import Foundation

/// 掉落的可调参数（PRD 2.1 §4.3，装扮掉落沿用 PRD 2.0 §4.4）。超出范围的值当作没填
struct LootRules: Equatable {
    var incubatorSlots = 3
    var chestStorage = 10
    var dailyPositiveChestCap = 12
    var dailyGrayChestCap = 4
    var overflowShardsPerChest = 10
    /// 专注至少多久才算「完成一段专注」
    var focusMinMinutes = 15
    /// 休息至少多久才算「离开屏幕」
    var breakMinMinutes = 5
    /// 同一条提醒推迟到第几次掉灰匣
    var snoozesForGrayBox = 3
    var outfitDropChance = 0.12
    var outfitPityThreshold = 10
    var maxOutfitDropsPerDay = 2

    static let `default` = LootRules()

    init() {}

    init(jsonObject: Any?) {
        let root = jsonObject as? [String: Any] ?? [:]
        var rules = LootRules()
        func int(_ key: String, _ range: ClosedRange<Double>) -> Int? {
            SettingsValue.number(root[key], in: range).map { Int($0) }
        }
        rules.incubatorSlots = int("incubator_slots", 1...5) ?? rules.incubatorSlots
        rules.chestStorage = int("chest_storage", 5...30) ?? rules.chestStorage
        rules.dailyPositiveChestCap = int("daily_positive_chest_cap", 6...24) ?? rules.dailyPositiveChestCap
        rules.dailyGrayChestCap = int("daily_gray_chest_cap", 0...8) ?? rules.dailyGrayChestCap
        rules.overflowShardsPerChest = int("overflow_shards_per_chest", 5...20) ?? rules.overflowShardsPerChest
        rules.focusMinMinutes = int("focus_min_minutes", 1...120) ?? rules.focusMinMinutes
        rules.breakMinMinutes = int("break_min_minutes", 1...60) ?? rules.breakMinMinutes
        rules.snoozesForGrayBox = int("snoozes_for_gray_box", 1...10) ?? rules.snoozesForGrayBox
        rules.outfitDropChance = SettingsValue.number(root["outfit_drop_chance"], in: 0...1) ?? rules.outfitDropChance
        rules.outfitPityThreshold = int("outfit_pity_threshold", 1...50) ?? rules.outfitPityThreshold
        rules.maxOutfitDropsPerDay = int("max_outfit_drops_per_day", 1...10) ?? rules.maxOutfitDropsPerDay
        self = rules
    }
}

/// 一种宝箱：孵多久、开几次、每次按什么概率出哪个档次
struct ChestDefinition: Equatable {
    let kind: ChestKind
    let hatchMinutes: Int
    let rolls: Int
    let tierWeights: [LootTier: Double]

    var hatchSeconds: Int { hatchMinutes * 60 }
}

/// 掉落配置：`config/loot/chests.json`（规则 + 宝箱）和 `config/loot/materials.json`。
/// 哪个文件坏了就用内置的那份，掉落永远能跑
struct LootConfig: Equatable {
    let rules: LootRules
    let chests: [ChestKind: ChestDefinition]
    let materials: [MaterialDefinition]

    func chest(_ kind: ChestKind) -> ChestDefinition {
        chests[kind] ?? Self.builtInChests[kind]!
    }

    func material(_ id: String) -> MaterialDefinition? {
        materials.first { $0.id == id }
    }

    init(rules: LootRules, chests: [ChestKind: ChestDefinition], materials: [MaterialDefinition]) {
        self.rules = rules
        self.chests = chests
        self.materials = materials
    }

    init(chestsJSON: Any?, materialsJSON: Any?) {
        let chestRoot = chestsJSON as? [String: Any] ?? [:]
        let parsedChests = Self.parseChests(chestRoot["chests"])
        let parsedMaterials = Self.parseMaterials(materialsJSON)
        self.init(
            rules: LootRules(jsonObject: chestRoot["rules"]),
            chests: parsedChests.count == ChestKind.allCases.count ? parsedChests : Self.builtInChests,
            materials: Self.coversEveryChest(parsedMaterials) ? parsedMaterials : Self.builtInMaterials
        )
    }

    static let builtIn = LootConfig(rules: .default, chests: builtInChests, materials: builtInMaterials)

    // MARK: - 解析

    private static func parseChests(_ raw: Any?) -> [ChestKind: ChestDefinition] {
        let entries = raw as? [[String: Any]] ?? []
        return entries.reduce(into: [ChestKind: ChestDefinition]()) { result, entry in
            guard
                let kind = (entry["kind"] as? String).flatMap(ChestKind.init(rawValue:)),
                result[kind] == nil,
                let minutes = SettingsValue.number(entry["hatch_minutes"], in: 1...600),
                let rawWeights = entry["tiers"] as? [String: Any]
            else { return }
            let weights = rawWeights.reduce(into: [LootTier: Double]()) { weights, pair in
                guard let tier = LootTier(rawValue: pair.key), let weight = SettingsValue.number(pair.value, in: 0...1000) else { return }
                weights[tier] = weight
            }
            guard weights.values.contains(where: { $0 > 0 }) else { return }
            let rolls = SettingsValue.number(entry["rolls"], in: 1...5).map { Int($0) } ?? 1
            result[kind] = ChestDefinition(kind: kind, hatchMinutes: Int(minutes), rolls: rolls, tierWeights: weights)
        }
    }

    private static func parseMaterials(_ raw: Any?) -> [MaterialDefinition] {
        let entries = (raw as? [String: Any])?["materials"] as? [[String: Any]] ?? []
        var seen = Set<String>()
        return entries.compactMap { entry in
            guard
                let id = entry["id"] as? String, !id.isEmpty, !seen.contains(id),
                let tier = (entry["tier"] as? String).flatMap(LootTier.init(rawValue:)),
                let task = (entry["task"] as? String).flatMap(LootTask.init(rawValue:))
            else { return nil }
            seen.insert(id)
            return MaterialDefinition(
                id: id,
                tier: tier,
                task: task,
                attributes: (entry["attributes"] as? [Any] ?? []).compactMap { $0 as? String },
                name: entry["name"] as? String ?? id
            )
        }
    }

    /// 每种宝箱至少有一件材料可开，不然配置不能用
    private static func coversEveryChest(_ materials: [MaterialDefinition]) -> Bool {
        let tasks = Set(materials.map(\.task))
        return [LootTask.hydration, .eyeCare, .standUp, .focus, .fullDay, .slack, .roughDay].allSatisfy(tasks.contains)
    }

    // MARK: - 内置

    static let builtInChests: [ChestKind: ChestDefinition] = [
        .wood: ChestDefinition(kind: .wood, hatchMinutes: 10, rolls: 1, tierWeights: [.white: 70, .blue: 25, .purple: 5]),
        .iron: ChestDefinition(kind: .iron, hatchMinutes: 25, rolls: 2, tierWeights: [.white: 50, .blue: 38, .purple: 12]),
        .gold: ChestDefinition(kind: .gold, hatchMinutes: 60, rolls: 3, tierWeights: [.blue: 60, .purple: 40]),
        .grayBox: ChestDefinition(kind: .grayBox, hatchMinutes: 15, rolls: 1, tierWeights: [.gray: 100]),
        .blackBox: ChestDefinition(kind: .blackBox, hatchMinutes: 15, rolls: 1, tierWeights: [.black: 100]),
    ]

    static let builtInMaterials: [MaterialDefinition] = [
        MaterialDefinition(id: "dew", tier: .white, task: .hydration, attributes: ["water"], name: "露珠"),
        MaterialDefinition(id: "window_cloud", tier: .white, task: .eyeCare, attributes: ["sky"], name: "窗外的云"),
        MaterialDefinition(id: "pebble", tier: .white, task: .standUp, attributes: ["earth"], name: "小石子"),
        MaterialDefinition(id: "quiet_spell", tier: .white, task: .focus, attributes: ["time"], name: "一段安静"),
        MaterialDefinition(id: "stardust", tier: .blue, task: .fullDay, attributes: ["star"], name: "星屑"),
        MaterialDefinition(id: "cold_water", tier: .gray, task: .slack, attributes: ["cold"], name: "冷掉的水"),
        MaterialDefinition(id: "midnight_moon", tier: .black, task: .roughDay, attributes: ["night"], name: "熬夜的月亮"),
    ]
}
