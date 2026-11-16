import Foundation

/// 背包窗口要画的东西：孵化位、排队的宝箱、碎片、图鉴（按档次分组的全部材料）。
/// 纯数据，从背包状态和配置算出来，窗口只管画
struct BackpackContent: Equatable {
    struct Slot: Equatable {
        let kind: ChestKind
        /// 0...1
        let progress: Double
        let minutesLeft: Int
    }

    struct Entry: Equatable {
        let id: String
        /// 没拿到过的是 nil（图鉴里显示「？？？」）
        let name: String?
        let count: Int
        let isNew: Bool
    }

    struct Group: Equatable {
        let tier: LootTier
        let entries: [Entry]
    }

    /// 长度 = 孵化位个数；空位是 nil
    let slots: [Slot?]
    let queuedChests: Int
    let shards: Int
    let shardsPerChest: Int
    let discoveredCount: Int
    let materialCount: Int
    let groups: [Group]

    /// 图鉴里档次的顺序：正面的从常见到稀有，负面的放后面
    static let tierOrder: [LootTier] = [.white, .blue, .purple, .gray, .black]

    init(state: LootState, config: LootConfig) {
        let slotCount = config.rules.incubatorSlots
        let incubating = state.incubating.prefix(slotCount).map { slot -> Slot in
            let total = max(1, config.chest(slot.chest.kind).hatchSeconds)
            let left = max(0, total - slot.progressSeconds)
            return Slot(
                kind: slot.chest.kind,
                progress: min(1, Double(slot.progressSeconds) / Double(total)),
                minutesLeft: Int((Double(left) / 60).rounded(.up))
            )
        }
        slots = incubating + Array(repeating: nil, count: max(0, slotCount - incubating.count))
        queuedChests = state.storage.count
        shards = state.shards
        shardsPerChest = config.rules.overflowShardsPerChest
        materialCount = config.materials.count
        discoveredCount = config.materials.filter { state.discovered.contains($0.id) }.count
        groups = Self.tierOrder.compactMap { tier in
            let entries = config.materials.filter { $0.tier == tier }.map { material in
                let known = state.discovered.contains(material.id)
                return Entry(
                    id: material.id,
                    name: known ? LootText.materialName(material) : nil,
                    count: state.materials[material.id] ?? 0,
                    isNew: state.unseen.contains(material.id)
                )
            }
            return entries.isEmpty ? nil : Group(tier: tier, entries: entries)
        }
    }
}
