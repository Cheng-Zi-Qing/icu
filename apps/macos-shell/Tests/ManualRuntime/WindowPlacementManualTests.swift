import Foundation

func testDefaultOriginUsesVisibleFrameBottomRight() throws {
    let visibleFrame = CGRect(
        origin: CGPoint(x: 0, y: 0),
        size: CGSize(width: 1440, height: 900)
    )
    let origin = WindowPlacement.defaultOrigin(
        visibleFrame: visibleFrame,
        windowSize: CGSize(width: 128, height: 128)
    )

    try expect(origin.x == 1288, "default origin x should anchor to right edge with margin")
    try expect(origin.y == 24, "default origin y should anchor to bottom edge with margin")
}

func testResolveInitialOriginPrefersSavedVisiblePosition() throws {
    let visibleFrame = CGRect(
        origin: CGPoint(x: 0, y: 0),
        size: CGSize(width: 1440, height: 900)
    )
    let saved = SavedWindowPlacement(x: 900, y: 120)
    let origin = WindowPlacement.resolveInitialOrigin(
        saved: saved,
        visibleFrame: visibleFrame,
        windowSize: CGSize(width: 128, height: 128)
    )

    try expect(origin.x == 900, "saved visible origin x should be restored")
    try expect(origin.y == 120, "saved visible origin y should be restored")
}

func testResolveInitialOriginFallsBackWhenSavedPositionIsOutOfBounds() throws {
    let visibleFrame = CGRect(
        origin: CGPoint(x: 0, y: 0),
        size: CGSize(width: 1440, height: 900)
    )
    let origin = WindowPlacement.resolveInitialOrigin(
        saved: SavedWindowPlacement(x: 5000, y: 5000),
        visibleFrame: visibleFrame,
        windowSize: CGSize(width: 128, height: 128)
    )

    try expect(origin.x == 1288, "out-of-bounds x should fall back to default origin")
    try expect(origin.y == 24, "out-of-bounds y should fall back to default origin")
}

func testClampedOriginKeepsDraggedWindowInsideVisibleFrame() throws {
    let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let size = CGSize(width: 128, height: 128)

    let inside = WindowPlacement.clampedOrigin(CGPoint(x: 400, y: 300), windowSize: size, visibleFrame: visibleFrame)
    try expect(inside == CGPoint(x: 400, y: 300), "origins already inside should be kept")

    let pastRight = WindowPlacement.clampedOrigin(CGPoint(x: 1400, y: 300), windowSize: size, visibleFrame: visibleFrame)
    try expect(pastRight.x == 1312, "window should stop at the right edge (got \(pastRight.x))")

    let belowDock = WindowPlacement.clampedOrigin(CGPoint(x: 400, y: -50), windowSize: size, visibleFrame: visibleFrame)
    try expect(belowDock.y == 25, "window should not slide under the dock (got \(belowDock.y))")

    let aboveMenuBar = WindowPlacement.clampedOrigin(CGPoint(x: -30, y: 880), windowSize: size, visibleFrame: visibleFrame)
    try expect(aboveMenuBar == CGPoint(x: 0, y: 772), "window should stop below the menu bar (got \(aboveMenuBar))")
}
