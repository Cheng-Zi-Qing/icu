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

    static func resolveInitialOrigin(
        saved: SavedWindowPlacement?,
        visibleFrame: CGRect,
        windowSize: CGSize,
        margin: CGFloat = defaultMargin
    ) -> CGPoint {
        guard let saved else {
            return defaultOrigin(visibleFrame: visibleFrame, windowSize: windowSize, margin: margin)
        }

        let rightEdge = visibleFrame.origin.x + visibleFrame.size.width
        let topEdge = visibleFrame.origin.y + visibleFrame.size.height
        let savedOrigin = saved.origin
        let isFullyVisible =
            savedOrigin.x >= visibleFrame.origin.x &&
            savedOrigin.y >= visibleFrame.origin.y &&
            savedOrigin.x + windowSize.width <= rightEdge &&
            savedOrigin.y + windowSize.height <= topEdge

        guard isFullyVisible else {
            return defaultOrigin(visibleFrame: visibleFrame, windowSize: windowSize, margin: margin)
        }

        return savedOrigin
    }
}
