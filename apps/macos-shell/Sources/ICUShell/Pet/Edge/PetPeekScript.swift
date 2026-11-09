import Foundation

/// 贴边时的一帧：正面探头，或者把头转成侧面
enum PetPeekFrame: Equatable {
    case rest
    case blink
    /// 往屏幕里多探出一格
    case reach
    /// 头转成侧面
    case turned
    case turnedBlink
    /// 被鼠标碰到吓一跳：眼睛挤成 > <，头往边后缩一格（不在循环里，只在碰到时播）
    case flinch

    var isTurned: Bool {
        self == .turned || self == .turnedBlink
    }

    /// `<pet>/edge/` 下的文件名
    var fileName: String {
        switch self {
        case .rest: return "peek_0.png"
        case .blink: return "peek_1.png"
        case .reach: return "peek_2.png"
        case .flinch: return "peek_3.png"
        case .turned: return "turn_0.png"
        case .turnedBlink: return "turn_1.png"
        }
    }
}

/// 贴边时播放的顺序：平时一直正面看着你（偶尔多探一下、眨眼）；
/// 每轮结束时有很小的机会把头转向侧面待一会儿，当作小彩蛋
enum PetPeekScript {
    static let framesPerSecond: Double = 4

    /// 平时的一轮，约 6 秒
    static let frontLoop: [PetPeekFrame] =
        Array(repeating: .rest, count: 8) + [.reach, .rest, .reach]
        + Array(repeating: .rest, count: 6) + [.blink]
        + Array(repeating: .rest, count: 8)

    /// 转头彩蛋，约 2.5 秒
    static let turnLoop: [PetPeekFrame] =
        Array(repeating: .turned, count: 5) + [.turnedBlink] + Array(repeating: .turned, count: 4)

    /// 每轮结束时转头的机会：平均约 3 分钟一次
    static let turnChancePerLoop = 1.0 / 30
}

/// 贴边动画播到哪了（不可变：每拍返回新的值）
struct PetPeekPlayback: Equatable {
    private let isTurning: Bool
    private let index: Int

    static let start = PetPeekPlayback(isTurning: false, index: 0)

    var frame: PetPeekFrame {
        (isTurning ? PetPeekScript.turnLoop : PetPeekScript.frontLoop)[index]
    }

    /// 往后走一拍；`roll` 是 [0, 1) 的随机数，只在正面一轮播完时用来决定要不要转头
    func advanced(roll: Double) -> PetPeekPlayback {
        let segment = isTurning ? PetPeekScript.turnLoop : PetPeekScript.frontLoop
        if index + 1 < segment.count {
            return PetPeekPlayback(isTurning: isTurning, index: index + 1)
        }
        let turnsNow = !isTurning && roll < PetPeekScript.turnChancePerLoop
        return PetPeekPlayback(isTurning: turnsNow, index: 0)
    }
}
