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
