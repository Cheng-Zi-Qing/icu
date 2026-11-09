import Foundation

struct SavedWindowPlacement: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(origin: CGPoint) {
        self.init(x: origin.x, y: origin.y)
    }

    var origin: CGPoint {
        CGPoint(x: x, y: y)
    }
}

enum WindowPlacement {
    static let defaultMargin: CGFloat = 24

    static func defaultOrigin(
        visibleFrame: CGRect,
        windowSize: CGSize,
        margin: CGFloat = defaultMargin
    ) -> CGPoint {
        let rightEdge = visibleFrame.origin.x + visibleFrame.size.width
        return CGPoint(
            x: rightEdge - windowSize.width - margin,
            y: visibleFrame.origin.y + margin
        )
    }

    /// 拖拽时把窗口限制在可见区域内（不钻进 Dock、不顶到菜单栏）
    static func clampedOrigin(_ origin: CGPoint, windowSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY)
        )
    }

    static func resolveInitialOrigin(
        saved: SavedWindowPlacement?,
        visibleFrame: CGRect,
        windowSize: CGSize,
        margin: CGFloat = defaultMargin
    ) -> CGPoint {
        guard let saved else {
            return defaultOrigin(visibleFrame: visibleFrame, windowSize: windowSize, margin: margin)
        }

        // 贴边时窗口的透明留白会伸出屏幕，只要大部分还在屏幕里就沿用
        let savedFrame = CGRect(origin: saved.origin, size: windowSize)
        let visiblePart = savedFrame.intersection(visibleFrame)
        let windowArea = windowSize.width * windowSize.height
        let isMostlyVisible = !visiblePart.isNull
            && windowArea > 0
            && (visiblePart.width * visiblePart.height) / windowArea >= minimumVisibleFraction

        guard isMostlyVisible else {
            return defaultOrigin(visibleFrame: visibleFrame, windowSize: windowSize, margin: margin)
        }

        return saved.origin
    }

    /// 恢复上次位置时，窗口至少要有这么多面积在屏幕内
    static let minimumVisibleFraction: CGFloat = 0.6
}
