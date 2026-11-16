import Foundation

/// 材料的档次（PRD 2.1 §4.1）。宝箱只开得出黑～紫；橙、红只能炼成，后面的阶段再加
enum LootTier: String, Codable, CaseIterable, Comparable {
    case black
    case gray
    case white
    case blue
    case purple

    /// 负面档次：灰、黑。不扣东西，是「另一种口味」
    var isNegative: Bool { self == .black || self == .gray }

    private var rank: Int {
        switch self {
        case .black: return 0
        case .gray: return 1
        case .white: return 2
        case .blue: return 3
        case .purple: return 4
        }
    }

    static func < (lhs: LootTier, rhs: LootTier) -> Bool { lhs.rank < rhs.rank }
}

/// 材料属性跟着任务走：想要「光」就得去看窗外，想要「风」就得起来走动（PRD 2.1 §4.2）
enum LootTask: String, Codable, CaseIterable {
    case hydration
    case eyeCare = "eye_care"
    case standUp = "stand_up"
    case focus
    case fullDay = "full_day"
    /// 提醒被跳过、推迟太多次
    case slack
    /// 当天状态很差
    case roughDay = "rough_day"

    var isNegative: Bool { self == .slack || self == .roughDay }
}

enum ChestKind: String, Codable, CaseIterable {
    case wood
    case iron
    case gold
    case grayBox = "gray_box"
    case blackBox = "black_box"

    var isNegative: Bool { self == .grayBox || self == .blackBox }
}

/// 一件材料的定义（`config/loot/materials.json`）
struct MaterialDefinition: Equatable {
    let id: String
    let tier: LootTier
    let task: LootTask
    let attributes: [String]
    /// 配置里写的名字；显示时先按 id 找文案（`loot.material.<id>`）
    let name: String
}

/// 背包里一个还没孵的宝箱。`task` 决定开出什么属性；nil = 碎片换来的，什么属性都可能
struct Chest: Codable, Equatable {
    let id: UUID
    let kind: ChestKind
    let task: LootTask?
    let earnedAt: Date
}

/// 孵化位上的宝箱：只按上班时长长进度
struct IncubatingChest: Codable, Equatable {
    let chest: Chest
    let progressSeconds: Int

    func advanced(by seconds: Int) -> IncubatingChest {
        IncubatingChest(chest: chest, progressSeconds: progressSeconds + seconds)
    }
}

/// 一个宝箱孵好开出来的东西
struct LootOpening: Equatable {
    let chest: Chest
    let materialIDs: [String]
    /// 顺带掉的装扮（还没拥有的那些里挑）
    let outfitID: String?
}

/// 衣柜里还没拥有、可以从宝箱里掉的装扮
struct OutfitCandidate: Equatable {
    let id: String
    let isRare: Bool
}
