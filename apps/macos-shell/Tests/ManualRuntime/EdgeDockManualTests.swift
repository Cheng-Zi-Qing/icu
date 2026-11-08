import CoreGraphics
import Foundation

// 屏幕可见区域：左下角 (0, 25)，Dock 占了底部 25pt
private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
// 128×128 窗口里身体只占左边 104pt（右侧是透明留白），脚贴窗口底
private let body = CGRect(x: 0, y: 4, width: 104, height: 116)

func testEdgeSnapSettingsParseConfigAndFallBackOnInvalidValues() throws {
    let parsed = EdgeSnapSettings(settingsObject: [
        "edge_snap": [
            "enabled": true,
            "snap_distance": 30,
            "peek_width": 40,
            "auto_hide_delay": 1500,
        ],
    ])
    try expect(parsed.isEnabled, "edge snap should be enabled")
    try expect(parsed.snapDistance == 30, "snap distance should come from config (got \(parsed.snapDistance))")
    try expect(parsed.peekWidth == 40, "peek width should come from config (got \(parsed.peekWidth))")
    try expect(abs(parsed.autoHideDelay - 1.5) < 0.0001, "auto hide delay is stored in milliseconds (got \(parsed.autoHideDelay))")

    let disabled = EdgeSnapSettings(settingsObject: ["edge_snap": ["enabled": false]])
    try expect(!disabled.isEnabled, "enabled=false should turn snapping off")

    let missing = EdgeSnapSettings(settingsObject: nil)
    try expect(missing == .default, "missing config should use defaults")

    let invalid = EdgeSnapSettings(settingsObject: [
        "edge_snap": ["snap_distance": -5, "peek_width": "wide", "auto_hide_delay": -1],
    ])
    try expect(invalid.snapDistance == EdgeSnapSettings.default.snapDistance, "negative snap distance should fall back")
    try expect(invalid.peekWidth == EdgeSnapSettings.default.peekWidth, "non-numeric peek width should fall back")
    try expect(invalid.autoHideDelay == EdgeSnapSettings.default.autoHideDelay, "negative delay should fall back")
}

func testEdgeDockClampLetsBodyReachScreenEdge() throws {
    // 窗口右侧透明留白可以出屏，但身体必须完整留在屏幕里
    let pastRight = EdgeDockLayout.clampedOrigin(CGPoint(x: 1400, y: 300), keepVisible: body, visibleFrame: screen)
    try expect(pastRight.x == 1336, "body's right side should stop exactly at the screen edge (got \(pastRight.x))")

    let pastLeft = EdgeDockLayout.clampedOrigin(CGPoint(x: -80, y: 300), keepVisible: body, visibleFrame: screen)
    try expect(pastLeft.x == 0, "body's left side should stop at the screen edge (got \(pastLeft.x))")

    let belowDock = EdgeDockLayout.clampedOrigin(CGPoint(x: 400, y: -50), keepVisible: body, visibleFrame: screen)
    try expect(belowDock.y == 21, "feet should stop on top of the dock (got \(belowDock.y))")

    let inside = EdgeDockLayout.clampedOrigin(CGPoint(x: 400, y: 300), keepVisible: body, visibleFrame: screen)
    try expect(inside == CGPoint(x: 400, y: 300), "positions inside should be kept")
}

func testEdgeDockDetectsNearbyEdgesFromBodyNotWindow() throws {
    // 身体右边离屏幕右边 15pt（窗口本身离右边还有 39pt）
    let nearRight = EdgeDockLayout.dock(
        for: CGPoint(x: 1321, y: 300), bodyRect: body, visibleFrame: screen, snapDistance: 20
    )
    try expect(nearRight == EdgeDock(horizontal: .right, sitsOnBottom: false), "body near the right edge should dock right (got \(nearRight))")

    let nearLeftAndBottom = EdgeDockLayout.dock(
        for: CGPoint(x: 12, y: 30), bodyRect: body, visibleFrame: screen, snapDistance: 20
    )
    try expect(
        nearLeftAndBottom == EdgeDock(horizontal: .left, sitsOnBottom: true),
        "corner drops should dock to both edges (got \(nearLeftAndBottom))"
    )

    let middle = EdgeDockLayout.dock(
        for: CGPoint(x: 600, y: 400), bodyRect: body, visibleFrame: screen, snapDistance: 20
    )
    try expect(middle == .none, "drops away from edges should not dock (got \(middle))")
}

func testEdgeDockSnapsBodyFlushAgainstEdges() throws {
    let right = EdgeDockLayout.dockedOrigin(
        CGPoint(x: 1321, y: 300), dock: EdgeDock(horizontal: .right, sitsOnBottom: false),
        bodyRect: body, visibleFrame: screen
    )
    try expect(right == CGPoint(x: 1336, y: 300), "right dock should put the body flush with the edge (got \(right))")

    let leftBottom = EdgeDockLayout.dockedOrigin(
        CGPoint(x: 12, y: 30), dock: EdgeDock(horizontal: .left, sitsOnBottom: true),
        bodyRect: body, visibleFrame: screen
    )
    try expect(leftBottom == CGPoint(x: 0, y: 21), "corner dock should touch both edges (got \(leftBottom))")
}

func testEdgeDockHidesAllButPeekWidthOfBody() throws {
    let docked = CGPoint(x: 1336, y: 300)
    let hiddenRight = EdgeDockLayout.hiddenOrigin(
        dockedOrigin: docked, edge: .right, bodyRect: body, visibleFrame: screen, peekWidth: 40
    )
    try expect(hiddenRight == CGPoint(x: 1400, y: 300), "only 40pt of the body should stay on screen (got \(hiddenRight))")

    // 贴左边时形象镜像，身体在窗口右侧
    let mirroredBody = CGRect(x: 24, y: 4, width: 104, height: 116)
    let hiddenLeft = EdgeDockLayout.hiddenOrigin(
        dockedOrigin: CGPoint(x: -24, y: 300), edge: .left, bodyRect: mirroredBody, visibleFrame: screen, peekWidth: 40
    )
    try expect(hiddenLeft == CGPoint(x: -88, y: 300), "left hide should leave the body's right 40pt visible (got \(hiddenLeft))")
}

func testResolveInitialOriginKeepsEdgeDockedPlacement() throws {
    // 贴右边时窗口右侧透明留白在屏幕外，重启后也应留在原位
    let origin = WindowPlacement.resolveInitialOrigin(
        saved: SavedWindowPlacement(x: 1336, y: 300),
        visibleFrame: screen,
        windowSize: CGSize(width: 128, height: 128)
    )
    try expect(origin == CGPoint(x: 1336, y: 300), "mostly visible docked placement should be restored (got \(origin))")
}

func testEdgeDockMapsNormalizedBodyIntoViewAndMirrors() throws {
    let canvas = CGRect(x: 0, y: 0, width: 128, height: 128)
    // 32px 精灵里身体占 x 0..26、y 0..29（左下为原点）
    let normalized = CGRect(x: 0, y: 0, width: 26.0 / 32, height: 29.0 / 32)

    let facingLeft = EdgeDockLayout.bodyRect(normalizedBounds: normalized, facingRight: false, in: canvas)
    try expect(facingLeft == CGRect(x: 0, y: 0, width: 104, height: 116), "body should scale into the canvas (got \(facingLeft))")

    let facingRight = EdgeDockLayout.bodyRect(normalizedBounds: normalized, facingRight: true, in: canvas)
    try expect(facingRight == CGRect(x: 24, y: 0, width: 104, height: 116), "mirrored body should sit on the other side (got \(facingRight))")
}

func testAvatarSettingsStoreLoadsEdgeSnapSettings() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configDir = root.appendingPathComponent("config", isDirectory: true)
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = AvatarSettingsStore(repoRootURL: root)
    try expect(store.loadEdgeSnapSettings() == .default, "missing settings file should give default edge snap settings")

    let json = #"{"edge_snap": {"enabled": true, "snap_distance": 24, "peek_width": 36, "auto_hide_delay": 3000}}"#
    try json.data(using: .utf8)!.write(to: configDir.appendingPathComponent("settings.json"))
    let loaded = store.loadEdgeSnapSettings()
    try expect(
        loaded == EdgeSnapSettings(isEnabled: true, snapDistance: 24, peekWidth: 36, autoHideDelay: 3),
        "edge snap settings should be read from settings.json (got \(loaded))"
    )
}

func testEdgeDockBehindOriginTucksWholeBodyPastEdge() throws {
    let right = EdgeDockLayout.behindOrigin(dockedOrigin: CGPoint(x: 1336, y: 300), edge: .right, bodyRect: body, visibleFrame: screen)
    try expect(right == CGPoint(x: 1440, y: 300), "body should be completely past the right edge (got \(right))")

    let mirroredBody = CGRect(x: 24, y: 4, width: 104, height: 116)
    let left = EdgeDockLayout.behindOrigin(dockedOrigin: CGPoint(x: -24, y: 300), edge: .left, bodyRect: mirroredBody, visibleFrame: screen)
    try expect(left == CGPoint(x: -128, y: 300), "body should be completely past the left edge (got \(left))")
}
