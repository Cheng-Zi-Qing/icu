import Foundation

/// 字跟着画面走：另外画的那几种演法（冲浪、翻箱子、摔一跤……）和待机小动作（晒太阳、看小鸟……）
/// 各有一组话，演到它时状态条说它那组，演完回到平时那句。
///
/// Agent 的活（干活、出错）在 `agent.lines.<演法>`，桌宠自己的（休息、待机小动作）在 `pet.lines.<名字>`
enum SceneLinePool: String, CaseIterable {
    // Agent 干活 / 出错的另几种演法：rawValue 就是 scenes.json 里的场景名
    case thinkDots = "think_dots"
    case thinkBulb = "think_bulb"
    case paper, rummage, button, surf, fall
    // 休息时钓鱼摸鱼
    case restFish = "rest_fish"
    // 待机小动作
    case sunbathe, bath, bird, wobble, nap
    // 健康提醒挂着时跟着做的动作（捧杯喝水、望远处）
    case drink
    case lookAway = "look_away"

    var key: String {
        switch self {
        case .thinkDots, .thinkBulb, .paper, .rummage, .button, .surf, .fall:
            return "agent.lines.\(rawValue)"
        case .restFish, .sunbathe, .bath, .bird, .wobble, .nap, .drink, .lookAway:
            return "pet.lines.\(rawValue)"
        }
    }

    /// 另外画的演法（scenes.json 里的场景名）对应的那组；场景自己那种演法没有单独的一组
    init?(variant name: String) {
        guard let pool = SceneLinePool(rawValue: name), pool.isSceneVariant else { return nil }
        self = pool
    }

    /// 待机小动作 / 打盹对应的那组；被摸、被戳的反应不单独说
    init?(clip: PetActionClip) {
        switch clip {
        case .sunbathe: self = .sunbathe
        case .bath: self = .bath
        case .birdVisit: self = .bird
        case .yuzuWobble: self = .wobble
        case .doze, .nap: self = .nap
        case .petted, .tickled, .annoyed, .sneezed, .startled, .grumpy, .wake: return nil
        }
    }

    private var isSceneVariant: Bool {
        switch self {
        case .thinkDots, .thinkBulb, .paper, .rummage, .button, .surf, .fall, .restFish: return true
        case .sunbathe, .bath, .bird, .wobble, .nap, .drink, .lookAway: return false
        }
    }

    /// 健康提醒挂着时说的一句：提醒卡在屏幕中央，桌宠这边一直说它，Agent 那边再忙也不抢
    static func line(reminder: HealthReminderType, catalog: TextCatalog = .shared) -> String? {
        (reminder == .hydration ? SceneLinePool.drink : .lookAway).line(catalog: catalog)
    }

    /// 正在演的那种演法该说的一句；不是另外画的、或者这组还没写，就是 nil（照常说原来那句）
    static func line(variant name: String?, catalog: TextCatalog = .shared) -> String? {
        name.flatMap { SceneLinePool(variant: $0) }.flatMap { $0.line(catalog: catalog) }
    }

    /// 正在放的待机小动作该说的一句；没在放、或者是被戳的反应，就是 nil
    static func line(clip: PetActionClip?, catalog: TextCatalog = .shared) -> String? {
        clip.flatMap { SceneLinePool(clip: $0) }.flatMap { $0.line(catalog: catalog) }
    }

    /// 同一段画面一直是同一句，换了画面才重新抽（见 PlayfulLines.line）
    private func line(catalog: TextCatalog) -> String? {
        guard !catalog.texts(key).isEmpty else { return nil }
        return PlayfulLines.sceneStatus.line(pool: key, fallback: key, catalog: catalog)
    }
}
