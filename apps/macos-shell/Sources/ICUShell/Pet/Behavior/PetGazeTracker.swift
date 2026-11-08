import CoreGraphics
import Foundation

/// 转头看鼠标（参考 oneko / OpenDesktopPets）：鼠标在附近、停在另一侧一会儿，就转过身去。
///
/// - 鼠标在身上（摸头、点它）时不算，免得摸着摸着翻来翻去
/// - 离得太远、或就在正上 / 正下方中间那一条时不理
/// - 鼠标要在另一侧停够 `dwell` 秒，两次转身至少隔 `cooldown` 秒
///
/// 不可变：`observing` 返回新状态和要转向的方向（nil 表示不动）。
struct PetGazeTracker: Equatable {
    static let attentionRadius: CGFloat = 420
    /// 身体中线左右各这么宽（占身体宽度的比例）算「正中间」
    static let deadZoneFraction: CGFloat = 0.25
    static let bodyMargin: CGFloat = 12
    static let dwell: TimeInterval = 0.4
    static let cooldown: TimeInterval = 1.5

    /// 鼠标想让它朝的方向（true = 朝右），以及从什么时候开始一直在那边
    private var pendingFacingRight: Bool?
    private var pendingSince: TimeInterval = 0
    private var lastTurn: TimeInterval = -.infinity

    /// - Parameters:
    ///   - cursor: 鼠标的屏幕坐标
    ///   - body: 身体在屏幕上的矩形
    func observing(
        cursor: CGPoint,
        body: CGRect,
        facingRight: Bool,
        at time: TimeInterval
    ) -> (PetGazeTracker, Bool?) {
        guard let wanted = wantedFacing(cursor: cursor, body: body), wanted != facingRight else {
            return (withPending(nil, since: time), nil)
        }
        guard pendingFacingRight == wanted else {
            return (withPending(wanted, since: time), nil)
        }
        guard time - pendingSince >= Self.dwell, time - lastTurn >= Self.cooldown else {
            return (self, nil)
        }
        let turned = PetGazeTracker(pendingFacingRight: nil, pendingSince: time, lastTurn: time)
        return (turned, wanted)
    }

    /// 暂时不能转身：忘掉鼠标在另一侧停了多久，冷却时间照算
    func paused() -> PetGazeTracker {
        withPending(nil, since: 0)
    }

    private func wantedFacing(cursor: CGPoint, body: CGRect) -> Bool? {
        if body.insetBy(dx: -Self.bodyMargin, dy: -Self.bodyMargin).contains(cursor) { return nil }
        let center = CGPoint(x: body.midX, y: body.midY)
        if hypot(cursor.x - center.x, cursor.y - center.y) > Self.attentionRadius { return nil }
        let dx = cursor.x - center.x
        if abs(dx) < body.width * Self.deadZoneFraction { return nil }
        return dx > 0
    }

    private func withPending(_ facingRight: Bool?, since time: TimeInterval) -> PetGazeTracker {
        PetGazeTracker(pendingFacingRight: facingRight, pendingSince: time, lastTurn: lastTurn)
    }
}
