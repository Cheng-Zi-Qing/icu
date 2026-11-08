import AppKit

// 拎起来：身体挂在后颈上跟着鼠标甩，整只都要露出来（不被 128pt 的桌宠窗口裁掉）

private func transformed(_ t: CATransform3D, _ point: CGPoint) -> CGPoint {
    let x = t.m11 * point.x + t.m21 * point.y + t.m41
    let y = t.m12 * point.x + t.m22 * point.y + t.m42
    let w = t.m14 * point.x + t.m24 * point.y + t.m44
    return CGPoint(x: x / w, y: y / w)
}

private let liftCanvas = CGRect(x: 0, y: 0, width: 128, height: 128)

func testAnimationEngineLiftSwingsTheBodyAroundTheScruff() throws {
    let anchor = CGPoint(x: 0, y: 0)
    for swing in [CGFloat(-30), 30] {
        let lift = PetAnimationEngine.liftedTransform(
            drag: DragOutput(pose: .hold(tilt: 0), stretchY: 1.2, swingDegrees: swing, landingSquash: 1),
            layerBounds: liftCanvas,
            anchorPoint: anchor
        )
        let scruff = transformed(lift, CGPoint(x: 64, y: 128))
        let feet = transformed(lift, CGPoint(x: 64, y: 0))
        try expect(abs(scruff.x - 64) < 0.001 && abs(scruff.y - 128) < 0.001, "the grab point stays under the cursor (got \(scruff))")
        try expect(
            swing < 0 ? feet.x < 64 - 40 : feet.x > 64 + 40,
            "a \(swing)° swing should throw the feet far to that side (feet at \(feet))"
        )
    }
}

func testPetLiftWindowLeavesRoomForTheWildestSwing() throws {
    let config = DragPhysicsConfig()
    let room = CGRect(origin: .zero, size: PetLiftWindow.frame(around: liftCanvas).size)
    let canvasInRoom = liftCanvas.offsetBy(dx: PetLiftWindow.sideMargin, dy: PetLiftWindow.bottomMargin)
    for swing in [-config.maxSwingDegrees, 0, config.maxSwingDegrees] {
        let lift = PetAnimationEngine.liftedTransform(
            drag: DragOutput(pose: .hold(tilt: 0), stretchY: 1 + config.holdStretch + config.maxExtraStretch, swingDegrees: swing, landingSquash: 1),
            layerBounds: liftCanvas,
            anchorPoint: .zero
        )
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: 128, y: 0), CGPoint(x: 0, y: 128), CGPoint(x: 128, y: 128)] {
            let moved = transformed(lift, corner)
            let inRoom = CGPoint(x: moved.x + canvasInRoom.minX, y: moved.y + canvasInRoom.minY)
            try expect(room.insetBy(dx: -0.5, dy: -0.5).contains(inRoom), "at \(swing)° the corner \(corner) lands at \(inRoom), outside \(room)")
        }
    }
}

func testDragPoseMirrorsItsLeanWhenThePetFacesRight() throws {
    try expect(DragPose.hold(tilt: -2).mirrored == .hold(tilt: 2), "a mirrored left lean becomes a right lean")
    try expect(DragPose.dizzy(tilt: 1, twinkle: 1).mirrored == .dizzy(tilt: -1, twinkle: 1), "dizzy frames mirror their lean too")
    try expect(DragPose.landing(frame: 1).mirrored == .landing(frame: 1), "landing frames have no lean")
    try expect(DragPose.hold(tilt: 0).isLifted && DragPose.dizzy(tilt: 0, twinkle: 0).isLifted, "hold and dizzy hang in the air")
    try expect(!DragPose.landing(frame: 0).isLifted && !DragPose.none.isLifted, "landing and resting are on the ground")
}

private func makeLiftablePet() throws -> (DesktopPetView, NSWindow) {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    let brown = NSColor(deviceRed: 0.7, green: 0.45, blue: 0.3, alpha: 1)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: brown)
    for tilt in -2...2 {
        try makeColorPNG(at: petRoot.appendingPathComponent("drag/hold_\(tilt).png"), color: brown)
    }
    try makeColorPNG(at: petRoot.appendingPathComponent("drag/land_0.png"), color: brown)
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let window = NSWindow(contentRect: NSRect(x: 600, y: 300, width: 128, height: DesktopPetView.compactContentSize.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    return (view, window)
}

func testDesktopPetViewHangsTheLiftedPetInABiggerWindow() throws {
    let (view, window) = try makeLiftablePet()
    defer { window.close() }

    view.applyDragPose(.hold(tilt: 0))
    guard let lift = view.liftWindow else {
        throw TestFailure(message: "lifting should open the bigger lift window")
    }
    try expect(lift.isVisible, "the lift window is on screen while held")
    try expect(lift.parent === window, "the lift window rides along with the pet window while it is dragged")
    try expect(lift.ignoresMouseEvents, "the lift window never steals the drag")
    try expect(view.imageView.alphaValue == 0, "the clipped pet in the small window steps aside")
    try expect(lift.spriteLayer.contents != nil, "the hold frame is drawn in the lift window")
    let canvas = window.convertToScreen(view.convert(view.imageView.frame, to: nil))
    try expect(
        lift.frame.insetBy(dx: PetLiftWindow.sideMargin - 1, dy: 0).contains(CGPoint(x: canvas.midX, y: canvas.midY))
            && lift.frame.width >= canvas.width + 2 * PetLiftWindow.sideMargin,
        "the lift window surrounds the pet with room to swing (lift \(lift.frame), canvas \(canvas))"
    )

    view.applyDragPose(.landing(frame: 0))
    try expect(!lift.isVisible, "landing puts it back into the normal window")
    try expect(view.imageView.alphaValue == 1, "the normal pet shows again on landing")
}
