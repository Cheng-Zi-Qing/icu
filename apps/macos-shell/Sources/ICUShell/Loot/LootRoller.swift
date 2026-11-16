import Foundation

/// 开宝箱：先按掉率抽档次，再从这个任务、这个档次的材料里挑一件
struct LootRoller {
    let config: LootConfig

    func rollTier(for kind: ChestKind, using random: inout some LootRandom) -> LootTier {
        let weights = config.chest(kind).tierWeights
        let ordered = LootTier.allCases.compactMap { tier in weights[tier].map { (tier, $0) } }
        return random.pick(ordered) ?? .white
    }

    /// 这个任务没有这个档次的材料（比如全天达标没有白）就挑最接近的档次；`task` 为 nil 时所有正面任务都算
    func rollMaterial(task: LootTask?, tier: LootTier, using random: inout some LootRandom) -> MaterialDefinition? {
        let pool = config.materials.filter { material in
            task.map { material.task == $0 } ?? !material.task.isNegative
        }
        guard !pool.isEmpty else { return nil }
        let exact = pool.filter { $0.tier == tier }
        if !exact.isEmpty {
            return random.pick(uniform: exact)
        }
        let nearestDistance = pool.map { distance($0.tier, tier) }.min() ?? 0
        let nearest = pool.filter { distance($0.tier, tier) == nearestDistance }
        return random.pick(uniform: nearest)
    }

    /// 装扮掉落（沿用 PRD 2.0）：只掉还没有的；连续 `outfitPityThreshold` 个宝箱没掉，下一个必掉；每天最多几件。
    /// 档次对应稀有度：开出紫先挑稀有，白、蓝先挑普通；那一类拿光了就从另一类挑
    func rollOutfit(
        tier: LootTier,
        candidates: [OutfitCandidate],
        state: LootState,
        using random: inout some LootRandom
    ) -> (outfitID: String?, dryStreak: Int) {
        let rules = config.rules
        guard !candidates.isEmpty, state.daily.outfitDrops < rules.maxOutfitDropsPerDay else {
            return (nil, state.outfitDryStreak)
        }
        let guaranteed = state.outfitDryStreak >= rules.outfitPityThreshold
        guard guaranteed || random.unit() < rules.outfitDropChance else {
            return (nil, state.outfitDryStreak + 1)
        }
        let wantsRare = tier >= .purple
        let preferred = candidates.filter { $0.isRare == wantsRare }
        let pick = random.pick(uniform: preferred.isEmpty ? candidates : preferred)
        return (pick?.id, 0)
    }

    private func distance(_ lhs: LootTier, _ rhs: LootTier) -> Int {
        let tiers = LootTier.allCases
        return abs((tiers.firstIndex(of: lhs) ?? 0) - (tiers.firstIndex(of: rhs) ?? 0))
    }
}

/// 孵化：只按上班时长给孵化位上的宝箱长进度，孵好的开出来，空出来的位置从背包里补上
struct LootIncubator {
    let config: LootConfig

    func advance(
        _ state: LootState,
        bySeconds seconds: Int,
        day: String,
        unownedOutfits: [OutfitCandidate],
        using random: inout some LootRandom
    ) -> (LootState, [LootOpening]) {
        guard seconds > 0 else { return (state, []) }
        let engine = LootEngine(config: config)
        var current = engine.fillingSlots(state.onDay(day))
        var openings: [LootOpening] = []
        var candidates = unownedOutfits
        var remaining = seconds

        // 一次给的时间可能够孵好好几轮（比如孵化位后面排着的宝箱）：孵好一个就补一个，接着用剩下的时间
        while remaining > 0, !current.incubating.isEmpty {
            let step = min(remaining, current.incubating.map { secondsLeft($0) }.min() ?? remaining)
            current = current.with { $0.incubating = $0.incubating.map { $0.advanced(by: step) } }
            remaining -= step

            let hatched = current.incubating.filter { secondsLeft($0) == 0 }
            guard !hatched.isEmpty else { break }
            current = current.with { $0.incubating.removeAll { secondsLeft($0) == 0 } }
            for slot in hatched {
                let (opened, opening) = open(slot.chest, in: current, candidates: candidates, using: &random)
                current = opened
                candidates.removeAll { $0.id == opening.outfitID }
                openings.append(opening)
            }
            current = engine.fillingSlots(current)
        }
        return (current, openings)
    }

    private func secondsLeft(_ slot: IncubatingChest) -> Int {
        max(0, config.chest(slot.chest.kind).hatchSeconds - slot.progressSeconds)
    }

    private func open(
        _ chest: Chest,
        in state: LootState,
        candidates: [OutfitCandidate],
        using random: inout some LootRandom
    ) -> (LootState, LootOpening) {
        let roller = LootRoller(config: config)
        let definition = config.chest(chest.kind)
        var materialIDs: [String] = []
        var bestTier = LootTier.black
        for _ in 0..<definition.rolls {
            let tier = roller.rollTier(for: chest.kind, using: &random)
            guard let material = roller.rollMaterial(task: chest.task, tier: tier, using: &random) else { continue }
            materialIDs.append(material.id)
            bestTier = max(bestTier, material.tier)
        }

        var outfitID: String?
        var next = state.with { next in
            for id in materialIDs {
                next.materials[id, default: 0] += 1
                next.discovered.insert(id)
                next.unseen.insert(id)
            }
        }
        // 负面匣子不掉装扮，也不算保底次数
        if !chest.kind.isNegative {
            let (dropped, streak) = roller.rollOutfit(tier: bestTier, candidates: candidates, state: next, using: &random)
            outfitID = dropped
            next = next.with { next in
                next.outfitDryStreak = streak
                if dropped != nil { next.daily.outfitDrops += 1 }
            }
        }
        return (next, LootOpening(chest: chest, materialIDs: materialIDs, outfitID: outfitID))
    }
}
