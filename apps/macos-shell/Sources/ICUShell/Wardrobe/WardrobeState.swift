import Foundation

/// 衣柜里有什么、身上穿着什么。不可变：每次换装返回新的状态
struct WardrobeState: Equatable {
    let owned: Set<String>
    let equipped: [WardrobeSlot: String]

    init(owned: Set<String>, equipped: [WardrobeSlot: String]) {
        self.owned = owned
        self.equipped = equipped
    }

    /// 新用户：拥有默认装扮，头上戴默认那件
    static func initial(for catalog: WardrobeCatalog) -> WardrobeState {
        WardrobeState(
            owned: Set(catalog.items.filter(\.isDefaultOwned).map(\.id)),
            equipped: [.head: catalog.defaultHead.id]
        )
    }

    // MARK: - 换装

    /// 戴上一件；没拥有或不认识的返回 nil
    func equipping(_ itemID: String, in catalog: WardrobeCatalog) -> WardrobeState? {
        guard owned.contains(itemID), let item = catalog.item(itemID) else { return nil }
        return WardrobeState(owned: owned, equipped: equipped.merging([item.slot: item.id]) { _, new in new })
    }

    /// 拿到一件新装扮（宝箱里开出来的）；不认识的返回 nil，已经有了原样返回
    func granting(_ itemID: String, in catalog: WardrobeCatalog) -> WardrobeState? {
        guard catalog.item(itemID) != nil else { return nil }
        return WardrobeState(owned: owned.union([itemID]), equipped: equipped)
    }

    /// 还没拥有、可以从宝箱里掉的装扮
    func unownedOutfits(in catalog: WardrobeCatalog) -> [OutfitCandidate] {
        catalog.items.filter { !owned.contains($0.id) }.map { OutfitCandidate(id: $0.id, isRare: $0.rarity == .rare) }
    }

    func isWearing(_ itemID: String) -> Bool {
        equipped.values.contains(itemID)
    }

    func canWear(_ suit: WardrobeSuit) -> Bool {
        suit.items.values.allSatisfy(owned.contains)
    }

    func isWearing(_ suit: WardrobeSuit) -> Bool {
        suit.items.allSatisfy { equipped[$0.key] == $0.value }
    }

    /// 换上整套：套装里有的装扮位换掉，其余的不动；缺件返回 nil
    func wearing(_ suit: WardrobeSuit, in catalog: WardrobeCatalog) -> WardrobeState? {
        guard canWear(suit) else { return nil }
        return WardrobeState(owned: owned, equipped: equipped.merging(suit.items) { _, new in new })
    }

    /// 头上那件用哪套帧；默认帧（橙子）为 nil
    func outfitID(in catalog: WardrobeCatalog) -> String? {
        equipped[.head].flatMap(catalog.item)?.spriteSet
    }

    /// 读回来的存档按当前装扮表收拾干净：默认装扮总是有；不认识、没拥有的不穿；头上空了就戴默认那件
    func sanitized(for catalog: WardrobeCatalog) -> WardrobeState {
        let known = Set(catalog.items.map(\.id))
        let defaults = Set(catalog.items.filter(\.isDefaultOwned).map(\.id))
        let cleanOwned = owned.intersection(known).union(defaults)
        var cleanEquipped = equipped.filter { slot, id in
            cleanOwned.contains(id) && catalog.item(id)?.slot == slot
        }
        if cleanEquipped[.head] == nil {
            cleanEquipped[.head] = catalog.defaultHead.id
        }
        return WardrobeState(owned: cleanOwned, equipped: cleanEquipped)
    }

    // MARK: - 存档格式

    /// `{"owned": [...], "equipped": {"head": "orange"}}`；不认识的装扮位直接丢掉
    init(jsonObject: Any?) {
        let root = jsonObject as? [String: Any] ?? [:]
        let owned = Set((root["owned"] as? [Any] ?? []).compactMap { $0 as? String })
        let rawEquipped = root["equipped"] as? [String: Any] ?? [:]
        let equipped = rawEquipped.reduce(into: [WardrobeSlot: String]()) { result, entry in
            guard let slot = WardrobeSlot(rawValue: entry.key), let id = entry.value as? String else { return }
            result[slot] = id
        }
        self.init(owned: owned, equipped: equipped)
    }

    var jsonObject: [String: Any] {
        [
            "owned": owned.sorted(),
            "equipped": Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) }),
        ]
    }
}
