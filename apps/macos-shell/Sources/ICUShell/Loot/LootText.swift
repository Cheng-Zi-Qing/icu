import Foundation

/// 掉落相关的显示名：先按 id 找文案，找不到用配置里写的名字
enum LootText {
    static func materialName(_ material: MaterialDefinition) -> String {
        TextCatalog.shared.text("loot.material.\(material.id)", fallback: material.name)
    }

    static func chestName(_ kind: ChestKind) -> String {
        TextCatalog.shared.text("loot.chest.\(kind.rawValue)", fallback: kind.rawValue)
    }

    static func tierName(_ tier: LootTier) -> String {
        TextCatalog.shared.text("loot.tier.\(tier.rawValue)", fallback: tier.rawValue)
    }

    static func outfitName(_ id: String) -> String {
        TextCatalog.shared.text("wardrobe.item.\(id)", fallback: id)
    }
}
