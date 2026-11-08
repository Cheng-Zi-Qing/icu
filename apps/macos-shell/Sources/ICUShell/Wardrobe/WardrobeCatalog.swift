import Foundation

/// 装扮位：衣柜里四页，顺序就是页签顺序
enum WardrobeSlot: String, CaseIterable, Equatable {
    case head
    case mouth
    case neck
    case face

    var title: String {
        switch self {
        case .head: return "头顶"
        case .mouth: return "嘴里"
        case .neck: return "脖子"
        case .face: return "脸上"
        }
    }
}

enum WardrobeRarity: String, Equatable {
    case common
    case rare
}

struct WardrobeItem: Equatable {
    let id: String
    let slot: WardrobeSlot
    let name: String
    let rarity: WardrobeRarity
    /// 一开始就有（橙子、草帽）
    let isDefaultOwned: Bool
    /// 戴上后用哪套帧（`assets/pets/<pet>/outfits/<spriteSet>/`）；nil = 画在默认帧里
    let spriteSet: String?
}

/// 套装：一键换上几件；缺件时锁着
struct WardrobeSuit: Equatable {
    let id: String
    let name: String
    let items: [WardrobeSlot: String]
}

/// 装扮表（`config/wardrobe.json`）：有哪些装扮、哪些一开始就有、有哪些套装。
/// 配置坏了或缺了默认头顶装扮时退回内置的表，衣柜永远能打开
struct WardrobeCatalog: Equatable {
    let items: [WardrobeItem]
    let suits: [WardrobeSuit]

    static let builtIn = WardrobeCatalog(
        items: [
            WardrobeItem(id: "orange", slot: .head, name: "橙子", rarity: .common, isDefaultOwned: true, spriteSet: nil),
            WardrobeItem(id: "straw_hat", slot: .head, name: "草帽", rarity: .common, isDefaultOwned: true, spriteSet: "straw_hat"),
        ],
        suits: [
            WardrobeSuit(id: "default", name: "默认", items: [.head: "orange"]),
            WardrobeSuit(id: "summer", name: "夏天", items: [.head: "straw_hat"]),
        ]
    )

    init(items: [WardrobeItem], suits: [WardrobeSuit]) {
        self.items = items
        self.suits = suits
    }

    init(jsonObject: Any?) {
        guard
            let root = jsonObject as? [String: Any],
            let rawItems = root["items"] as? [[String: Any]]
        else {
            self = .builtIn
            return
        }
        let items = Self.parseItems(rawItems)
        guard items.contains(where: { $0.slot == .head && $0.isDefaultOwned }) else {
            self = .builtIn
            return
        }
        let knownIDs = Set(items.map(\.id))
        let suits = (root["suits"] as? [[String: Any]] ?? []).compactMap { Self.parseSuit($0, knownIDs: knownIDs) }
        self.init(items: items, suits: suits)
    }

    func item(_ id: String) -> WardrobeItem? {
        items.first { $0.id == id }
    }

    func items(in slot: WardrobeSlot) -> [WardrobeItem] {
        items.filter { $0.slot == slot }
    }

    /// 默认戴在头上的那件（表里第一件一开始就有的头顶装扮）
    var defaultHead: WardrobeItem {
        items.first { $0.slot == .head && $0.isDefaultOwned } ?? Self.builtIn.items[0]
    }

    // MARK: - 解析

    private static func parseItems(_ raw: [[String: Any]]) -> [WardrobeItem] {
        raw.reduce(into: [WardrobeItem]()) { result, object in
            guard
                let id = nonEmptyString(object["id"]),
                let slot = (object["slot"] as? String).flatMap(WardrobeSlot.init(rawValue:)),
                let name = nonEmptyString(object["name"]),
                !result.contains(where: { $0.id == id })
            else {
                return
            }
            result.append(WardrobeItem(
                id: id,
                slot: slot,
                name: name,
                rarity: (object["rarity"] as? String).flatMap(WardrobeRarity.init(rawValue:)) ?? .common,
                isDefaultOwned: object["default_owned"] as? Bool ?? false,
                spriteSet: nonEmptyString(object["sprite_set"])
            ))
        }
    }

    private static func parseSuit(_ object: [String: Any], knownIDs: Set<String>) -> WardrobeSuit? {
        guard
            let id = nonEmptyString(object["id"]),
            let name = nonEmptyString(object["name"]),
            let rawItems = object["items"] as? [String: String],
            !rawItems.isEmpty
        else {
            return nil
        }
        var pieces: [WardrobeSlot: String] = [:]
        for (slotName, itemID) in rawItems {
            guard let slot = WardrobeSlot(rawValue: slotName), knownIDs.contains(itemID) else { return nil }
            pieces[slot] = itemID
        }
        return WardrobeSuit(id: id, name: name, items: pieces)
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}
