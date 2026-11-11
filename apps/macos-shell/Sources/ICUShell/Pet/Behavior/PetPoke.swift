import CoreGraphics
import Foundation

/// 戳到了哪儿：按侧身坐姿（脸朝左）的 32×32 素材格子分区，App 按部位挑反应。
///
///     y  0 ┌──────── 头顶装扮 / 头 ────────┐
///          │ 鼻子 │    头     │    背 / 屁股 │
///     y 17 ├──────┴─── 肚子 ───┤              │
///     y 27 ├──────────── 腿脚 ───────────────┤
///     y 32 └─────────────────────────────────┘
enum PetPokeZone: Equatable, CaseIterable {
    case head
    case nose
    case belly
    case back
    case legs

    /// 素材边长（格）
    static let spriteSize: CGFloat = 32
    /// 鼻头最右边一格：再往右就是脸 / 头
    static let noseMaxX: CGFloat = 6.5
    /// 头和身体的分界（下巴底下）
    static let headMaxY: CGFloat = 17
    /// 胸口 / 肚子和背 / 屁股的分界
    static let backMinX: CGFloat = 19
    /// 腿脚从这一行往下
    static let legsMinY: CGFloat = 27

    /// - Parameters:
    ///   - x: 素材格子坐标，0 在脸那一侧（朝右时调用方先镜像）
    ///   - y: 素材格子坐标，0 在头顶、向下增大
    static func zone(spriteX x: CGFloat, spriteY y: CGFloat) -> PetPokeZone {
        if y >= legsMinY { return .legs }
        if y < headMaxY {
            if x <= noseMaxX { return .nose }
            return x >= backMinX ? .back : .head
        }
        return x >= backMinX ? .back : .belly
    }

    /// 视图里一点 → 部位。`imageRect` 是素材画在视图里的矩形（视图坐标 y 向上），
    /// `facingRight` 时画面是镜像的；点在素材外面返回 nil
    static func zone(at point: CGPoint, imageRect: CGRect, facingRight: Bool) -> PetPokeZone? {
        guard imageRect.width > 0, imageRect.height > 0, imageRect.contains(point) else { return nil }
        let normalizedX = (point.x - imageRect.minX) / imageRect.width
        let fromTop = (imageRect.maxY - point.y) / imageRect.height
        let faceSideX = facingRight ? 1 - normalizedX : normalizedX
        return zone(spriteX: faceSideX * spriteSize, spriteY: fromTop * spriteSize)
    }

    /// 戳这儿的反应：头 → 头顶的橙子晃一晃；鼻子 → 打喷嚏；肚子 → 怕痒；背 → 吓一跳；腿 → 不耐烦
    var reaction: PetActionClip {
        switch self {
        case .head: return .yuzuWobble
        case .nose: return .sneezed
        case .belly: return .tickled
        case .back: return .startled
        case .legs: return .annoyed
        }
    }
}

/// 戳得太勤：`window` 秒里戳够 `overdoneCount` 下，水豚就生气了。不可变：`registering` 返回新状态
struct PetPokeTracker: Equatable {
    static let overdoneCount = 5
    static let window: TimeInterval = 4

    private var times: [TimeInterval] = []

    /// 记一下；返回新状态，以及这一下是不是戳过头了（戳过头就清零，生完气重新数）
    func registering(at time: TimeInterval) -> (PetPokeTracker, overdone: Bool) {
        let recent = times.filter { time - $0 < Self.window } + [time]
        guard recent.count >= Self.overdoneCount else {
            return (PetPokeTracker(times: recent), false)
        }
        return (PetPokeTracker(), true)
    }
}

/// 被戳时冒的一句话（`config/copy/` 里的 `poke.*` 文案池）
enum PetPokeCopy {
    static func lines(for clip: PetActionClip) -> [String] {
        switch clip {
        case .tickled: return TextCatalog.shared.texts("poke.tickle")
        case .annoyed: return TextCatalog.shared.texts("poke.annoyed")
        case .sneezed: return TextCatalog.shared.texts("poke.sneeze")
        case .startled: return TextCatalog.shared.texts("poke.startled")
        case .grumpy: return TextCatalog.shared.texts("poke.grumpy")
        case .petted, .doze, .nap, .wake, .yuzuWobble, .birdVisit: return []
        }
    }

    /// 这句话是不是被戳时冒的（是的话下一下戳可以换掉它）
    static func isPokeLine(_ text: String) -> Bool {
        PetActionClip.allCases.contains { lines(for: $0).contains(text) }
    }

    static func line(for clip: PetActionClip, random: Double) -> String? {
        let pool = lines(for: clip)
        guard !pool.isEmpty else { return nil }
        let index = min(pool.count - 1, Int(max(0, random) * Double(pool.count)))
        return pool[index]
    }
}
