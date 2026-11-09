import CoreGraphics

enum HorizontalDockEdge: Equatable {
    case left
    case right
}

/// 桌宠贴着哪些屏幕边
struct EdgeDock: Equatable {
    var horizontal: HorizontalDockEdge?
    /// 坐在屏幕底边（Dock 上沿）
    var sitsOnBottom: Bool

    static let none = EdgeDock(horizontal: nil, sitsOnBottom: false)

    var isDocked: Bool { horizontal != nil || sitsOnBottom }
}

/// 贴边相关的纯几何计算。
///
/// 所有判断都以「身体」为准，而不是窗口：窗口是 128×128 的方块，
/// 形象只占其中一部分，按窗口算会离屏幕边差一截透明留白。
/// `bodyRect` / `keepVisible` 都是窗口内坐标（左下角为原点）。
enum EdgeDockLayout {
    /// 把归一化的身体轮廓（0...1，左下原点）映射到视图里的绘制区域；镜像时左右翻转
    static func bodyRect(normalizedBounds: CGRect, facingRight: Bool, in drawRect: CGRect) -> CGRect {
        let x = facingRight ? 1 - normalizedBounds.maxX : normalizedBounds.minX
        return CGRect(
            x: drawRect.minX + x * drawRect.width,
            y: drawRect.minY + normalizedBounds.minY * drawRect.height,
            width: normalizedBounds.width * drawRect.width,
            height: normalizedBounds.height * drawRect.height
        )
    }

    /// 拖拽时的限位：`keepVisible` 那块必须完整留在屏幕内，窗口的透明部分可以出屏
    static func clampedOrigin(_ origin: CGPoint, keepVisible: CGRect, visibleFrame: CGRect) -> CGPoint {
        let minX = visibleFrame.minX - keepVisible.minX
        let maxX = visibleFrame.maxX - keepVisible.maxX
        let minY = visibleFrame.minY - keepVisible.minY
        let maxY = visibleFrame.maxY - keepVisible.maxY
        return CGPoint(
            x: min(max(origin.x, minX), max(minX, maxX)),
            y: min(max(origin.y, minY), max(minY, maxY))
        )
    }

    /// 松手位置离哪些边足够近
    static func dock(for origin: CGPoint, bodyRect: CGRect, visibleFrame: CGRect, snapDistance: CGFloat) -> EdgeDock {
        let body = bodyRect.offsetBy(dx: origin.x, dy: origin.y)
        let leftGap = body.minX - visibleFrame.minX
        let rightGap = visibleFrame.maxX - body.maxX

        let horizontal: HorizontalDockEdge?
        if leftGap <= snapDistance, leftGap <= rightGap {
            horizontal = .left
        } else if rightGap <= snapDistance {
            horizontal = .right
        } else {
            horizontal = nil
        }

        let bottomGap = body.minY - visibleFrame.minY
        return EdgeDock(horizontal: horizontal, sitsOnBottom: bottomGap <= snapDistance)
    }

    /// 吸附后的窗口原点：身体正好贴住对应的边
    static func dockedOrigin(_ origin: CGPoint, dock: EdgeDock, bodyRect: CGRect, visibleFrame: CGRect) -> CGPoint {
        var result = origin
        switch dock.horizontal {
        case .left:
            result.x = visibleFrame.minX - bodyRect.minX
        case .right:
            result.x = visibleFrame.maxX - bodyRect.maxX
        case nil:
            break
        }
        if dock.sitsOnBottom {
            result.y = visibleFrame.minY - bodyRect.minY
        }
        return result
    }

    /// 整个身体刚好躲到屏幕边外面的窗口原点（藏边 / 探头切换形象的中间点）
    static func behindOrigin(
        dockedOrigin: CGPoint,
        edge: HorizontalDockEdge,
        bodyRect: CGRect,
        visibleFrame: CGRect
    ) -> CGPoint {
        switch edge {
        case .left:
            return CGPoint(x: visibleFrame.minX - bodyRect.maxX, y: dockedOrigin.y)
        case .right:
            return CGPoint(x: visibleFrame.maxX - bodyRect.minX, y: dockedOrigin.y)
        }
    }

    /// 藏边后的窗口原点：身体只露出 `peekWidth`
    static func hiddenOrigin(
        dockedOrigin: CGPoint,
        edge: HorizontalDockEdge,
        bodyRect: CGRect,
        visibleFrame: CGRect,
        peekWidth: CGFloat
    ) -> CGPoint {
        let peek = min(peekWidth, bodyRect.width)
        switch edge {
        case .left:
            return CGPoint(x: visibleFrame.minX + peek - bodyRect.maxX, y: dockedOrigin.y)
        case .right:
            return CGPoint(x: visibleFrame.maxX - peek - bodyRect.minX, y: dockedOrigin.y)
        }
    }
}
