import Foundation

/// 互动 / 打盹的逐帧片段。素材由 tools/pixel_pets/capybara/build.mjs 生成：
///
///   react/petted_<0...3>.png   被摸头：眯眼 + 爱心往上飘
///   sleep/doze_0.png           犯困：闭眼低头
///   sleep/nap_<0...15>.png     睡着：慢呼吸 + z 往上飘
///   sleep/wake_0.png           被吵醒：头上一个「!」
///   idle_act/wobble_<0...9>.png  待机小动作：柚子左右晃，抬眼看它
///   idle_act/bird_<0...17>.png   待机小动作：小鸟飞来落在额头上，歇一会儿飞走
enum PetActionClip: Equatable, CaseIterable {
    case petted
    case doze
    case nap
    case wake
    case yuzuWobble
    case birdVisit

    var directory: String {
        switch self {
        case .petted: return "react"
        case .doze, .nap, .wake: return "sleep"
        case .yuzuWobble, .birdVisit: return "idle_act"
        }
    }

    var frameNames: [String] {
        switch self {
        case .petted: return (0..<4).map { "petted_\($0).png" }
        case .doze: return ["doze_0.png"]
        case .nap: return (0..<16).map { "nap_\($0).png" }
        case .wake: return ["wake_0.png"]
        case .yuzuWobble: return (0..<10).map { "wobble_\($0).png" }
        case .birdVisit: return (0..<18).map { "bird_\($0).png" }
        }
    }

    var framesPerSecond: Double {
        switch self {
        case .doze, .nap, .wake: return 4
        case .petted, .yuzuWobble, .birdVisit: return 6
        }
    }

    /// 打盹那几段一直放到打盹节奏换阶段；其余的放固定几遍就结束
    var loops: Bool {
        switch self {
        case .doze, .nap, .wake: return true
        case .petted, .yuzuWobble, .birdVisit: return false
        }
    }

    /// 不循环的片段放几遍（摸头放两遍，爱心冒两次）
    private var playCount: Int {
        self == .petted ? 2 : 1
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
}
