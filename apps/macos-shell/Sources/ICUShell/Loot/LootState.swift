import Foundation

/// 当天的掉落计数，换天就清零
struct LootDailyCounters: Codable, Equatable {
    let day: String
    var positiveChests = 0
    var grayBoxes = 0
    var goldGranted = false
    var outfitDrops = 0

    init(day: String) {
        self.day = day
    }
}

/// 背包、孵化位、图鉴（`state/loot.json`）。不可变：每次变化返回新的状态
struct LootState: Codable, Equatable {
    /// 还没孵的宝箱，先来先孵
    var storage: [Chest] = []
    var incubating: [IncubatingChest] = []
    /// 材料 id → 数量
    var materials: [String: Int] = [:]
    var shards = 0
    /// 拿到过的材料（图鉴），哪怕已经用掉了
    var discovered: Set<String> = []
    /// 新拿到、还没在背包里看过的材料
    var unseen: Set<String> = []
    var daily = LootDailyCounters(day: "")
    /// 连续多少个正面宝箱没掉装扮（保底用）
    var outfitDryStreak = 0
    /// 上过班的最近一天，以及已经结算到哪一天（黑匣只看结算过的那天）
    var lastActiveDay: String?
    var lastSettledDay: String?

    static let empty = LootState()

    var totalChestCount: Int { storage.count + incubating.count }

    /// 换天了就把当天计数清零
    func onDay(_ day: String) -> LootState {
        guard daily.day != day else { return self }
        var next = self
        next.daily = LootDailyCounters(day: day)
        return next
    }

    func with(_ change: (inout LootState) -> Void) -> LootState {
        var next = self
        change(&next)
        return next
    }

    /// 读回来的存档收拾干净：不认识的材料丢掉，数量不为负，孵化位不超过上限
    func sanitized(for config: LootConfig) -> LootState {
        let known = Set(config.materials.map(\.id))
        return with { state in
            state.materials = state.materials.filter { known.contains($0.key) && $0.value > 0 }
            state.discovered = state.discovered.intersection(known)
            state.unseen = state.unseen.intersection(known)
            state.shards = max(0, state.shards)
            state.outfitDryStreak = max(0, state.outfitDryStreak)
            let slots = config.rules.incubatorSlots
            if state.incubating.count > slots {
                state.storage = state.incubating.dropFirst(slots).map(\.chest) + state.storage
                state.incubating = Array(state.incubating.prefix(slots))
            }
        }
    }
}

/// 读存档时缺的字段用默认值（以后加字段，老存档照样能读）
extension LootState {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        storage = try container.decodeIfPresent([Chest].self, forKey: .storage) ?? []
        incubating = try container.decodeIfPresent([IncubatingChest].self, forKey: .incubating) ?? []
        materials = try container.decodeIfPresent([String: Int].self, forKey: .materials) ?? [:]
        shards = try container.decodeIfPresent(Int.self, forKey: .shards) ?? 0
        discovered = try container.decodeIfPresent(Set<String>.self, forKey: .discovered) ?? []
        unseen = try container.decodeIfPresent(Set<String>.self, forKey: .unseen) ?? []
        daily = try container.decodeIfPresent(LootDailyCounters.self, forKey: .daily) ?? LootDailyCounters(day: "")
        outfitDryStreak = try container.decodeIfPresent(Int.self, forKey: .outfitDryStreak) ?? 0
        lastActiveDay = try container.decodeIfPresent(String.self, forKey: .lastActiveDay)
        lastSettledDay = try container.decodeIfPresent(String.self, forKey: .lastSettledDay)
    }
}

extension LootDailyCounters {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(day: try container.decodeIfPresent(String.self, forKey: .day) ?? "")
        positiveChests = try container.decodeIfPresent(Int.self, forKey: .positiveChests) ?? 0
        grayBoxes = try container.decodeIfPresent(Int.self, forKey: .grayBoxes) ?? 0
        goldGranted = try container.decodeIfPresent(Bool.self, forKey: .goldGranted) ?? false
        outfitDrops = try container.decodeIfPresent(Int.self, forKey: .outfitDrops) ?? 0
    }
}

/// 按本机时区把时刻换成「哪一天」
struct LootDayKey {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// `key(for:)` 反过来：那一天的中午（避开夏令时切换的零点）；格式不对返回 nil
    func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}
