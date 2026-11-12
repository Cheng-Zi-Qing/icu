import Foundation

/// 会掉宝箱的事（PRD 2.1 §4.2–4.3）
enum LootEvent: Equatable {
    case reminderCompleted(HealthReminderType)
    case reminderSkipped(HealthReminderType)
    /// 同一条提醒这是第几次推迟
    case reminderSnoozed(HealthReminderType, times: Int)
    case focusFinished(seconds: Int)
    case breakFinished(seconds: Int)
    /// 当天全部达标（每天 1 个金宝箱）
    case allGoalsMet
    /// 当天结算状态很差（每天最多 1 个黑匣）
    case roughDay
}

/// 这件事换来了什么
enum LootGrant: Equatable {
    case chest(Chest)
    /// 超了每天上限或背包满了：变成碎片；`exchanged` = 碎片攒够换了一个木宝箱
    case shard(exchanged: Chest?)
    /// 不掉东西（不算任务、负面上限到了、背包满了）
    case nothing
}

/// 判宝箱、每日上限、碎片兑换、放进孵化位。纯函数，不碰文件
struct LootEngine {
    let config: LootConfig

    private var rules: LootRules { config.rules }

    /// 这件事掉不掉宝箱、掉哪种、开出什么属性
    func chestKind(for event: LootEvent) -> (ChestKind, LootTask)? {
        switch event {
        case .reminderCompleted(.hydration):
            return (.wood, .hydration)
        case .reminderCompleted(.eyeCare):
            return (.wood, .eyeCare)
        case let .focusFinished(seconds):
            return seconds >= rules.focusMinMinutes * 60 ? (.wood, .focus) : nil
        case let .breakFinished(seconds):
            // 离开屏幕够久：比点一下「喝了」费劲，给铁宝箱
            return seconds >= rules.breakMinMinutes * 60 ? (.iron, .standUp) : nil
        case .allGoalsMet:
            return (.gold, .fullDay)
        case .reminderSkipped:
            return (.grayBox, .slack)
        case let .reminderSnoozed(_, times):
            return times == rules.snoozesForGrayBox ? (.grayBox, .slack) : nil
        case .roughDay:
            return (.blackBox, .roughDay)
        }
    }

    /// `day` 是这件事发生在哪一天（每日上限按它算）
    func grant(_ event: LootEvent, to state: LootState, day: String, at date: Date) -> (LootState, LootGrant) {
        let current = state.onDay(day)
        guard let (kind, task) = chestKind(for: event) else { return (current, .nothing) }
        let chest = Chest(id: UUID(), kind: kind, task: task, earnedAt: date)

        switch kind {
        case .gold:
            guard !current.daily.goldGranted else { return (current, .nothing) }
            return store(chest, in: current.with { $0.daily.goldGranted = true }, overflowToShard: true)
        case .wood, .iron:
            guard current.daily.positiveChests < rules.dailyPositiveChestCap else {
                return addShard(to: current, at: date)
            }
            return store(chest, in: current.with { $0.daily.positiveChests += 1 }, overflowToShard: true)
        case .grayBox:
            guard current.daily.grayBoxes < rules.dailyGrayChestCap else { return (current, .nothing) }
            let (next, grant) = store(chest, in: current, overflowToShard: false)
            guard grant != .nothing else { return (current, .nothing) }
            return (next.with { $0.daily.grayBoxes += 1 }, grant)
        case .blackBox:
            return store(chest, in: current, overflowToShard: false)
        }
    }

    /// 有空的孵化位就从背包里按先来后到放进去
    func fillingSlots(_ state: LootState) -> LootState {
        let free = max(0, rules.incubatorSlots - state.incubating.count)
        guard free > 0, !state.storage.isEmpty else { return state }
        return state.with { next in
            let moving = next.storage.prefix(free)
            next.incubating += moving.map { IncubatingChest(chest: $0, progressSeconds: 0) }
            next.storage.removeFirst(moving.count)
        }
    }

    // MARK: - 私有

    private var capacity: Int { rules.chestStorage + rules.incubatorSlots }

    private func store(_ chest: Chest, in state: LootState, overflowToShard: Bool) -> (LootState, LootGrant) {
        guard state.totalChestCount < capacity else {
            return overflowToShard ? addShard(to: state, at: chest.earnedAt) : (state, .nothing)
        }
        let next = fillingSlots(state.with { $0.storage.append(chest) })
        return (next, .chest(chest))
    }

    /// 加一片碎片；攒够了而且背包放得下，就换一个什么属性都可能出的木宝箱
    private func addShard(to state: LootState, at date: Date) -> (LootState, LootGrant) {
        let withShard = state.with { $0.shards += 1 }
        guard withShard.shards >= rules.overflowShardsPerChest, withShard.totalChestCount < capacity else {
            return (withShard, .shard(exchanged: nil))
        }
        let exchanged = Chest(id: UUID(), kind: .wood, task: nil, earnedAt: date)
        let next = fillingSlots(withShard.with {
            $0.shards -= rules.overflowShardsPerChest
            $0.storage.append(exchanged)
        })
        return (next, .shard(exchanged: exchanged))
    }
}
