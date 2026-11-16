import Foundation

/// 掉落接到 app 上：听记账发出的事给宝箱、每分钟按上班时长孵化、换天时结算黑匣、
/// 孵好了让桌宠头顶冒一句，开出的装扮交给衣柜。每次变化都存进 `state/loot.json`
@MainActor
final class LootCoordinator {
    /// 一次孵化最多算多少秒：计时器漏了几拍、电脑刚醒，都不会一下子补很多
    static let maxTickSeconds = 90

    /// 掉落要从 app 其他地方问的东西
    @MainActor
    struct Hooks {
        /// 某一天的统计（判金宝箱、黑匣）
        var daySummary: (Date) -> HealthDaySummary?
        /// 今天该喝几杯、上几小时班
        var goals: () -> (cupsGoal: Int, workHours: Double)
        /// 衣柜里还没拥有的装扮
        var unownedOutfits: () -> [OutfitCandidate]
        /// 把开出来的装扮放进衣柜；放不进返回 false
        var grantOutfit: (String) -> Bool
        /// 现在能不能让桌宠说话（专注、全屏时先攒着）
        var canAnnounce: () -> Bool
        var announce: (String) -> Void
    }

    let config: LootConfig
    private let store: LootStore
    private let hooks: Hooks
    private let dayKey: LootDayKey
    private let verdict: LootDayVerdict
    private var random: SeededLootRandom
    private(set) var state: LootState
    private var lastTickAt: Date?
    /// 这次启动里已经给过东西的提醒（同一条提醒的结果只算一次）
    private var handledReminderIDs: Set<UUID> = []
    private(set) var pendingNotices: [String] = []
    /// 背包变了（开着的背包窗口跟着刷新）
    var onChange: ((LootState) -> Void)?

    init(
        config: LootConfig,
        store: LootStore,
        hooks: Hooks,
        calendar: Calendar = .current,
        seed: UInt64 = UInt64.random(in: 0...UInt64.max)
    ) {
        self.config = config
        self.store = store
        self.hooks = hooks
        self.dayKey = LootDayKey(calendar: calendar)
        self.verdict = LootDayVerdict(calendar: calendar)
        self.random = SeededLootRandom(seed: seed)
        self.state = store.load(config: config)
    }

    /// 读 `config/loot/chests.json` 和 `materials.json`；读不到的那份用内置的
    static func loadConfig(directory: URL?) -> LootConfig {
        func json(_ name: String) -> Any? {
            guard let url = directory?.appendingPathComponent(name, isDirectory: false),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            do {
                return try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            } catch {
                NSLog("[Loot] could not read \(url.path), using the built-in table: \(error.localizedDescription)")
                return nil
            }
        }
        return LootConfig(chestsJSON: json("chests.json"), materialsJSON: json("materials.json"))
    }

    // MARK: - 得宝箱

    func handle(_ activity: HealthActivity, at date: Date) {
        let today = settlingPastDays(at: date)
        guard let event = event(for: activity) else {
            commit(today)
            flushNotices()
            return
        }
        let engine = LootEngine(config: config)
        let (granted, grant) = engine.grant(event, to: today, day: dayKey.key(for: date), at: date)
        var next = granted.with { $0.lastActiveDay = dayKey.key(for: date) }
        notice(for: grant, after: granted).map { pendingNotices.append($0) }

        if case .reminderCompleted = event, let summary = hooks.daySummary(date),
           verdict.allGoalsMet(summary, cupsGoal: hooks.goals().cupsGoal) {
            let (withGold, goldGrant) = engine.grant(.allGoalsMet, to: next, day: dayKey.key(for: date), at: date)
            next = withGold
            notice(for: goldGrant, after: withGold).map { pendingNotices.append($0) }
        }
        commit(next)
        flushNotices()
    }

    // MARK: - 孵化

    /// 每分钟调一次。只有在上班（含专注、休息）才长进度，按两次调用之间的真实间隔算
    func tick(isOnDuty: Bool, at date: Date) {
        let elapsed = lastTickAt.map { Int(date.timeIntervalSince($0)) } ?? 0
        lastTickAt = date
        let today = settlingPastDays(at: date)
        guard isOnDuty, elapsed > 0 else {
            commit(today)
            flushNotices()
            return
        }

        let seconds = min(elapsed, Self.maxTickSeconds)
        let (advanced, openings) = LootIncubator(config: config).advance(
            today.with { $0.lastActiveDay = dayKey.key(for: date) },
            bySeconds: seconds,
            day: dayKey.key(for: date),
            unownedOutfits: hooks.unownedOutfits(),
            using: &random
        )
        openings.forEach(receive)
        commit(advanced)
        flushNotices()
    }

    /// 电脑睡着 / 醒来：睡着的时间不算孵化
    func resetClock(at date: Date?) {
        lastTickAt = date
    }

    /// 背包打开看过了：「新」标记清掉
    func markAllSeen() {
        guard !state.unseen.isEmpty else { return }
        commit(state.with { $0.unseen = [] })
    }

    /// 能说话了就把攒着的话说出来（一次只说最新的一句，旧的丢掉，免得刷屏）
    func flushNotices() {
        guard let latest = pendingNotices.last, hooks.canAnnounce() else { return }
        pendingNotices = []
        hooks.announce(latest)
    }

    // MARK: - 私有

    private func event(for activity: HealthActivity) -> LootEvent? {
        switch activity {
        case let .reminderOutcome(id, type, outcome, snoozeCount):
            guard handledReminderIDs.insert(id).inserted else { return nil }
            switch outcome {
            case .completed: return .reminderCompleted(type)
            case .skipped: return .reminderSkipped(type)
            case .snoozed: return .reminderSnoozed(type, times: snoozeCount + 1)
            case .shown: return nil
            }
        case let .segmentFinished(.focus, seconds):
            return .focusFinished(seconds: seconds)
        case let .segmentFinished(.breakState, seconds):
            return .breakFinished(seconds: seconds)
        case .segmentFinished:
            return nil
        }
    }

    /// 换天了：上一个上过班的日子还没结算过，就看它是不是「状态很差」，是的话给一个黑匣
    private func settlingPastDays(at date: Date) -> LootState {
        let todayKey = dayKey.key(for: date)
        let current = state.onDay(todayKey)
        guard let last = current.lastActiveDay, last != todayKey, current.lastSettledDay != last else { return current }
        let settled = current.with { $0.lastSettledDay = last }
        guard let lastDate = dayKey.date(for: last), let summary = hooks.daySummary(lastDate),
              verdict.isRough(summary, workHours: hooks.goals().workHours) else { return settled }
        let (next, grant) = LootEngine(config: config).grant(.roughDay, to: settled, day: todayKey, at: date)
        notice(for: grant, after: next).map { pendingNotices.append($0) }
        return next
    }

    private func receive(_ opening: LootOpening) {
        let names = opening.materialIDs.compactMap(config.material).map(LootText.materialName)
        var line = TextCatalog.shared.format("loot.hatched", LootText.chestName(opening.chest.kind), names.joined(separator: "、"))
        if let outfitID = opening.outfitID {
            if hooks.grantOutfit(outfitID) {
                line = TextCatalog.shared.format("loot.hatched_outfit", LootText.outfitName(outfitID))
            } else {
                NSLog("[Loot] a chest dropped outfit \(outfitID) but the wardrobe could not take it")
            }
        }
        pendingNotices.append(line)
    }

    private func notice(for grant: LootGrant, after next: LootState) -> String? {
        switch grant {
        case let .chest(chest):
            let name = LootText.chestName(chest.kind)
            switch chest.kind {
            case .grayBox: return TextCatalog.shared.format("loot.earned_gray", name)
            case .blackBox: return TextCatalog.shared.format("loot.earned_black", name)
            case .wood, .iron, .gold: return TextCatalog.shared.format("loot.earned", name)
            }
        case .shard(exchanged: .some):
            return TextCatalog.shared.text("loot.shard_exchanged")
        case .shard(exchanged: nil):
            return TextCatalog.shared.format("loot.shard", next.shards, config.rules.overflowShardsPerChest)
        case .nothing:
            return nil
        }
    }

    private func commit(_ next: LootState) {
        guard next != state else { return }
        state = next
        do {
            try store.save(next)
        } catch {
            NSLog("[Loot] failed to save the backpack: \(error.localizedDescription)")
        }
        onChange?(next)
    }
}
