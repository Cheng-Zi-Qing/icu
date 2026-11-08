import AppKit

// 桌宠上的像素手型光标：头上摸摸、身上张手、拖着走时握拳

func testPetCursorKindFollowsWhatThePointerIsOver() throws {
    try expect(PetCursorKind.kind(isGrabbing: false, overBody: true, overHead: true) == .pat, "over the head: pat")
    try expect(PetCursorKind.kind(isGrabbing: false, overBody: true, overHead: false) == .grab, "over the body: open hand")
    try expect(PetCursorKind.kind(isGrabbing: true, overBody: true, overHead: true) == .grabbing, "holding it: fist, even over the head")
    try expect(PetCursorKind.kind(isGrabbing: true, overBody: false, overHead: false) == .grabbing, "the fist stays while the pet lags behind a fast drag")
    try expect(PetCursorKind.kind(isGrabbing: false, overBody: false, overHead: false) == nil, "transparent pixels keep the normal arrow")
}

private func writeCursorAssets(in directory: URL) throws {
    for kind in PetCursorKind.allCases {
        try makeColorPNG(at: directory.appendingPathComponent("\(kind.rawValue).png"), color: .white)
    }
    let manifest = """
    {
      "pixelSize": 16,
      "pointSize": 24,
      "cursors": {
        "grab": { "file": "grab.png", "hotSpot": [9, 9] },
        "grabbing": { "file": "grabbing.png", "hotSpot": [8, 9] },
        "pat": { "file": "pat.png", "hotSpot": [7, 8] }
      }
    }
    """
    try manifest.write(to: directory.appendingPathComponent("cursors.json"), atomically: true, encoding: .utf8)
}

func testPetCursorSetLoadsPixelCursorsWithTheirHotSpots() throws {
    let directory = try makeTemporaryDirectory().appendingPathComponent("cursor", isDirectory: true)
    try writeCursorAssets(in: directory)
    let cursors = PetCursorSet(directory: directory)

    let grab = cursors.cursor(for: .grab)
    try expect(grab !== NSCursor.openHand, "uses the pixel cursor instead of the system hand")
    try expect(grab.image.size == NSSize(width: 24, height: 24), "pixel cursor is 24pt (got \(grab.image.size))")
    try expect(grab.hotSpot == NSPoint(x: 13.5, y: 13.5), "hot spot scales from pixels to points (got \(grab.hotSpot))")
    try expect(cursors.cursor(for: .pat).hotSpot == NSPoint(x: 10.5, y: 12), "each cursor keeps its own hot spot")
}

func testPetCursorSetFallsBackToSystemHands() throws {
    let missing = try makeTemporaryDirectory().appendingPathComponent("nope", isDirectory: true)
    for directory in [nil, missing] {
        let cursors = PetCursorSet(directory: directory)
        try expect(cursors.cursor(for: .grab) === NSCursor.openHand, "no pixel art: open hand")
        try expect(cursors.cursor(for: .grabbing) === NSCursor.closedHand, "no pixel art: closed hand")
        try expect(cursors.cursor(for: .pat) === NSCursor.pointingHand, "no pixel art: pointing hand")
    }
}

func testBackgroundCursorCanBeEnabled() throws {
    // 桌宠所在的 App 平时不在前台，不打开这个开关系统会无视它设的光标
    try expect(BackgroundCursor.enable(), "the pet should be allowed to change the cursor while another app is in front")
}

func testDesktopPetViewSwitchesCursorsAcrossHeadAndBody() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeCursorAssets(in: petRoot.appendingPathComponent("cursor", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.layoutSubtreeIfNeeded()
    guard let body = view.petBodyRect else { throw TestFailure(message: "pet body should be known") }

    func move(to point: NSPoint) throws {
        guard let event = NSEvent.mouseEvent(
            with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0
        ) else { throw TestFailure(message: "mouse event") }
        view.mouseMoved(with: event)
    }

    try move(to: NSPoint(x: body.midX, y: body.maxY - body.height * 0.2))
    try expect(view.currentCursorKind == .pat, "head shows the patting hand (got \(String(describing: view.currentCursorKind)))")
    try move(to: NSPoint(x: body.midX, y: body.minY + body.height * 0.2))
    try expect(view.currentCursorKind == .grab, "body shows the open hand")
}
