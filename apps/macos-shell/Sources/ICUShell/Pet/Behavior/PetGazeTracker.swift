import CoreGraphics
import Foundation

/// 转头看鼠标（参考 oneko / OpenDesktopPets）：鼠标在附近、停在另一侧一会儿，就转过身去。
///
/// - 鼠标在身上（摸头、点它）时不算，免得摸着摸着翻来翻去
/// - 离得太远、或就在正上 / 正下方中间那一条时不理
/// - 鼠标要在另一侧停够 `dwell` 秒，两次转身至少隔 `cooldown` 秒
/// - 鼠标走远了，过 `homeDwell` 秒再转回「家」的朝向：在屏幕右半边脸朝左，左半边脸朝右（朝着屏幕中间蹲）
///
/// 只理离得近、停得久的鼠标：范围大、反应快时，平常干活鼠标路过就会让它左右乱翻（用户 2026-11-09 反馈）。
///
/// 不可变：`observing` 返回新状态和要转向的方向（nil 表示不动）。
struct PetGazeTracker: Equatable {
    /// 鼠标离身体中心这么近才理它（约两个身位）
    static let attentionRadius: CGFloat = 200
    /// 身体中线左右各这么宽（占身体宽度的比例）算「正中间」
    static let deadZoneFraction: CGFloat = 0.25
    static let bodyMargin: CGFloat = 12
    static let dwell: TimeInterval = 1.5
    static let cooldown: TimeInterval = 5
    /// 鼠标走开后多久才转回家的朝向
    static let homeDwell: TimeInterval = 4

    /// 鼠标想让它朝的方向（true = 朝右），以及从什么时候开始一直在那边
    private var pendingFacingRight: Bool?
    private var pendingSince: TimeInterval = 0
    private var lastTurn: TimeInterval = -.infinity

    /// - Parameters:
    ///   - cursor: 鼠标的屏幕坐标
    ///   - body: 身体在屏幕上的矩形
    ///   - homeFacingRight: 鼠标不在附近时该朝哪边（nil = 保持不动）
    func observing(
        cursor: CGPoint,
        body: CGRect,
        facingRight: Bool,
        homeFacingRight: Bool? = nil,
        at time: TimeInterval
    ) -> (PetGazeTracker, Bool?) {
        let wanted = isAway(cursor: cursor, body: body) ? homeFacingRight : wantedFacing(cursor: cursor, body: body)
        guard let wanted, wanted != facingRight else {
            return (withPending(nil, since: time), nil)
        }
        guard pendingFacingRight == wanted else {
            return (withPending(wanted, since: time), nil)
        }
        let needed = isAway(cursor: cursor, body: body) ? Self.homeDwell : Self.dwell
        guard time - pendingSince >= needed, time - lastTurn >= Self.cooldown else {
            return (self, nil)
        }
        let turned = PetGazeTracker(pendingFacingRight: nil, pendingSince: time, lastTurn: time)
        return (turned, wanted)
    }

    /// 朝着屏幕中间：身体在右半边就朝左，在左半边就朝右
    static func homeFacingRight(body: CGRect, screen: CGRect) -> Bool {
        body.midX < screen.midX
    }

    /// 暂时不能转身：忘掉鼠标在另一侧停了多久，冷却时间照算
    func paused() -> PetGazeTracker {
        withPending(nil, since: 0)
    }

    private func isAway(cursor: CGPoint, body: CGRect) -> Bool {
        hypot(cursor.x - body.midX, cursor.y - body.midY) > Self.attentionRadius
    }

    private func wantedFacing(cursor: CGPoint, body: CGRect) -> Bool? {
        if body.insetBy(dx: -Self.bodyMargin, dy: -Self.bodyMargin).contains(cursor) { return nil }
        if isAway(cursor: cursor, body: body) { return nil }
        let dx = cursor.x - body.midX
        if abs(dx) < body.width * Self.deadZoneFraction { return nil }
        return dx > 0
    }

    private func withPending(_ facingRight: Bool?, since time: TimeInterval) -> PetGazeTracker {
        PetGazeTracker(pendingFacingRight: facingRight, pendingSince: time, lastTurn: lastTurn)
    }
}
