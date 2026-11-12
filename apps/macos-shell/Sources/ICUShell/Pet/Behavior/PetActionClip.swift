import Foundation

/// 互动 / 打盹的逐帧片段。素材由 tools/pixel_pets/capybara/build.mjs 生成：
///
///   react/petted_<0...3>.png   被摸头：眯眼 + 爱心往上飘
///   react/tickle_<0...13>.png  戳肚子：怕痒，眯眼大笑往后仰
///   react/annoyed_<0...13>.png 戳腿：不耐烦，斜眼拍地冒青筋
///   react/sneeze_<0...14>.png  戳鼻子：打喷嚏，草喷飞了再叼回来
///   react/startled_<0...11>.png 戳背：吓一跳，冒「!」和冷汗
///   react/grumpy_<0...17>.png  戳太多下：生气，仰头「哼」
///   sleep/doze_0.png           犯困：闭眼低头
///   sleep/nap_<0...15>.png     睡着：慢呼吸 + z 往上飘
///   sleep/wake_0.png           被吵醒：头上一个「!」
///   idle_act/wobble_<0...9>.png  待机小动作：柚子左右晃，抬眼看它
///   idle_act/bird_<0...17>.png   待机小动作：小鸟飞来落在额头上，歇一会儿飞走
///   idle_act/sunbathe_<0...7>.png 待机小动作：戴墨镜往后一仰晒太阳（idle-extras.mjs）
///   idle_act/bath_<0...7>.png     待机小动作：坐进木盆泡澡，头顶毛巾冒热气（idle-extras.mjs）
///
/// 被戳的几段帧数、帧率和 tools/pixel_pets/capybara/poke-reactions.mjs 一致
/// （testPokeReactionFramesExistInTheRepoAssets 会对着仓库里的素材查）
enum PetActionClip: Equatable, CaseIterable {
    case petted
    case tickled
    case annoyed
    case sneezed
    case startled
    case grumpy
    case doze
    case nap
    case wake
    case yuzuWobble
    case birdVisit
    case sunbathe
    case bath

    var directory: String {
        switch self {
        case .petted, .tickled, .annoyed, .sneezed, .startled, .grumpy: return "react"
        case .doze, .nap, .wake: return "sleep"
        case .yuzuWobble, .birdVisit, .sunbathe, .bath: return "idle_act"
        }
    }

    var frameNames: [String] {
        switch self {
        case .petted: return Self.numbered("petted", count: 4)
        case .tickled: return Self.numbered("tickle", count: 14)
        case .annoyed: return Self.numbered("annoyed", count: 14)
        case .sneezed: return Self.numbered("sneeze", count: 15)
        case .startled: return Self.numbered("startled", count: 12)
        case .grumpy: return Self.numbered("grumpy", count: 18)
        case .doze: return ["doze_0.png"]
        case .nap: return Self.numbered("nap", count: 16)
        case .wake: return ["wake_0.png"]
        case .yuzuWobble: return Self.numbered("wobble", count: 10)
        case .birdVisit: return Self.numbered("bird", count: 18)
        case .sunbathe: return Self.numbered("sunbathe", count: 8)
        case .bath: return Self.numbered("bath", count: 8)
        }
    }

    var framesPerSecond: Double {
        switch self {
        case .doze, .nap, .wake, .sunbathe, .bath: return 4
        case .petted, .yuzuWobble, .birdVisit, .grumpy: return 6
        case .tickled, .annoyed, .sneezed, .startled: return 8
        }
    }

    /// 打盹那几段一直放到打盹节奏换阶段；其余的放固定几遍就结束
    var loops: Bool {
        switch self {
        case .doze, .nap, .wake: return true
        default: return false
        }
    }

    /// 被戳的反应（摸头、睡觉、待机小动作以外的那几段）
    var isPokeReaction: Bool {
        switch self {
        case .tickled, .annoyed, .sneezed, .startled, .grumpy: return true
        default: return false
        }
    }

    /// 不循环的片段放几遍（摸头放两遍，爱心冒两次；晒太阳、泡澡一轮才 2 秒，多泡一会儿）
    private var playCount: Int {
        switch self {
        case .petted: return 2
        case .sunbathe, .bath: return 3
        default: return 1
        }
    }

    /// 不循环的片段放完要多久
    var duration: TimeInterval {
        Double(frameNames.count * playCount) / framesPerSecond
    }

    /// 播放开始 `elapsed` 秒后该显示的帧；放完返回 nil
    func frameName(after elapsed: TimeInterval) -> String? {
        if !loops && elapsed >= duration { return nil }
        let index = Int((max(0, elapsed) * framesPerSecond).rounded(.down)) % frameNames.count
        return frameNames[index]
    }

    private static func numbered(_ name: String, count: Int) -> [String] {
        (0..<count).map { "\(name)_\($0).png" }
    }
}
