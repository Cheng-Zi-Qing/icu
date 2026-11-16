import Foundation

/// 贴边时的一帧：保持正面扒边，轻轻张望或看小鸟掠过
enum PetPeekFrame: Equatable {
    case rest
    case blink
    /// 往屏幕里多探出一格
    case reach
    case lookLeft
    case lookRight
    case birdFlyIn
    case birdFlyPast
    case birdFlyOut
    /// 旧侧面帧保留兼容，不再参与自动循环
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
        case .lookLeft: return "look_left.png"
        case .lookRight: return "look_right.png"
        case .birdFlyIn: return "bird_0.png"
        case .birdFlyPast: return "bird_1.png"
        case .birdFlyOut: return "bird_2.png"
        case .turned: return "turn_0.png"
        case .turnedBlink: return "turn_1.png"
        }
    }
}

/// 贴边时播放的顺序：大部分时间安静正面休息，偶尔轻微左右张望找小鸟。
/// 保留旧 turn 命名及概率，但不再切换侧面轮廓。
enum PetPeekScript {
    static let framesPerSecond: Double = 4

    /// 平时的一轮，约 6 秒
    static let frontLoop: [PetPeekFrame] =
        Array(repeating: .rest, count: 8) + [.reach, .rest, .reach]
        + Array(repeating: .rest, count: 6) + [.blink]
        + Array(repeating: .rest, count: 8)

    /// 稀有小彩蛋：慢慢扫视两边，小鸟掠过，再回到中性帧
    static let turnLoop: [PetPeekFrame] =
        [.rest, .blink, .lookLeft, .lookLeft, .lookLeft, .rest, .rest,
         .lookRight, .lookRight, .lookRight, .rest, .lookLeft,
         .birdFlyIn, .birdFlyPast, .birdFlyOut, .lookRight, .lookRight,
         .blink, .rest, .rest]

    /// 每轮结束时张望找鸟的机会：平均约 3 分钟一次
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

    /// 往后走一拍；`roll` 是 [0, 1) 的随机数，只在正面一轮播完时决定要不要张望
    func advanced(roll: Double) -> PetPeekPlayback {
        let segment = isTurning ? PetPeekScript.turnLoop : PetPeekScript.frontLoop
        if index + 1 < segment.count {
            return PetPeekPlayback(isTurning: isTurning, index: index + 1)
        }
        let turnsNow = !isTurning && roll < PetPeekScript.turnChancePerLoop
        return PetPeekPlayback(isTurning: turnsNow, index: 0)
    }
}
