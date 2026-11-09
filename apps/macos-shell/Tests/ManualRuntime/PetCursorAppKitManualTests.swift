import AppKit

// 桌宠上的像素手型光标：头上摸摸、身上张手、拖着走时握拳

func testPetCursorKindFollowsWhatThePointerIsOver() throws {
    try expect(PetCursorKind.kind(isGrabbing: false, overBody: true, overHead: true) == .pat, "over the head: pat")
    try expect(PetCursorKind.kind(isGrabbing: false, overBody: true, overHead: false) == .grab, "over the body: open hand")
    try expect(PetCursorKind.kind(isGrabbing: true, overBody: true, overHead: true) == .grabbing, "holding it: fist, even over the head")
    try expect(PetCursorKind.kind(isGrabbing: true, overBody: false, overHead: false) == .grabbing, "the fist stays while the pet lags behind a fast drag")
    try expect(PetCursorKind.kind(isGrabbing: false, overBody: false, overHead: false) == nil, "transparent pixels keep the normal arrow")
}

/// 透明区域盖在别的 App 上（比如 Otty 的文字）：桌宠不能每动一下就设箭头，跟人家的光标抢
func testPetCursorOnlyTouchesTheCursorOverThePet() throws {
    try expect(PetCursorKind.update(from: nil, to: .grab) == .show(.grab), "entering the body shows the hand")
    try expect(PetCursorKind.update(from: .grab, to: .grab) == .show(.grab), "over the body it keeps re-asserting the hand")
    try expect(PetCursorKind.update(from: .grab, to: nil) == .restoreArrow, "leaving the body hands back the arrow once")
    try expect(PetCursorKind.update(from: nil, to: nil) == .leaveAlone, "over transparent pixels the app underneath owns the cursor")
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
    // 原图 16px 按 24pt 显示，系统得自己缩放；后台换光标时它缩坏了就是白方块。所以 1 倍 / 2 倍的像素图都提前备好
    let widths = grab.image.representations.compactMap { ($0 as? NSBitmapImageRep)?.pixelsWide }.sorted()
    try expect(widths == [24, 48], "ready-made 1x and 2x bitmaps (got \(widths))")
    try expect(grab.image.representations.allSatisfy { $0.size == NSSize(width: 24, height: 24) }, "every bitmap is 24pt")
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
    let gate = BackgroundCursorGate.live()
    try expect(gate.setOpen(true), "the pet should be allowed to change the cursor while another app is in front")
    try expect(gate.isOpen, "gate reports open")
    try expect(gate.setOpen(false), "and give the cursor back afterwards")
    try expect(!gate.isOpen, "gate reports closed")
}

/// 开关只在状态变化时才去碰窗口服务器；打不开就当关着
func testBackgroundCursorGateOnlyCallsTheWindowServerOnChanges() throws {
    var calls: [Bool] = []
    var succeeds = true
    let gate = BackgroundCursorGate { open in
        calls.append(open)
        return succeeds
    }
    try expect(!gate.isOpen, "starts closed: other apps own the cursor")
    gate.setOpen(false)
    gate.setOpen(true)
    gate.setOpen(true)
    gate.setOpen(false)
    try expect(calls == [true, false], "only real changes reach the window server (got \(calls))")
    succeeds = false
    try expect(!gate.setOpen(true), "a failed switch reports false")
    try expect(!gate.isOpen, "and stays closed")
}

/// 白方块：鼠标停在别的 App 上时，系统隔一阵会把 ICU 上次设的手型又套回来（图像没传过去，就是白方块）。
/// 所以「后台改光标」只在鼠标真在豚鼠身上时打开，离开时先还箭头再关
@MainActor
func testDesktopPetViewOnlyOpensTheBackgroundCursorWhileOverThePet() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeCursorAssets(in: petRoot.appendingPathComponent("cursor", isDirectory: true))
    var calls: [Bool] = []
    let gate = BackgroundCursorGate { open in
        calls.append(open)
        return true
    }
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        cursorGate: gate
    )
    try expect(calls.isEmpty, "the gate stays closed until the pointer reaches the pet (got \(calls))")
    view.layoutSubtreeIfNeeded()
    guard let body = view.petBodyRect else { throw TestFailure(message: "pet body should be known") }

    func move(to point: NSPoint) throws {
        guard let event = NSEvent.mouseEvent(
            with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0
        ) else { throw TestFailure(message: "mouse event") }
        view.mouseMoved(with: event)
    }

    view.updateCursor(at: nil)
    try expect(calls.isEmpty, "pointer not on the pet: other apps keep their cursor (got \(calls))")
    try move(to: NSPoint(x: body.midX, y: body.maxY - body.height * 0.2))
    try expect(gate.isOpen && calls == [true], "over the head: open so the patting hand shows (got \(calls))")
    try move(to: NSPoint(x: body.midX, y: body.minY + body.height * 0.2))
    try expect(calls == [true], "head to body: no extra switching (got \(calls))")
    view.updateCursor(at: nil)
    try expect(!gate.isOpen && calls == [true, false], "left the pet: closed again (got \(calls))")
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

/// 状态条刷新、窗口变大小时 AppKit 可能补发过期的鼠标事件：鼠标其实在别的 App 上（比如 Otty），
/// 这时设手型会和前台 App 抢光标，光标变成白方块
@MainActor
func testDesktopPetViewIgnoresMouseEventsWhenThePointerIsElsewhere() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory.appendingPathComponent("pets/capybara", isDirectory: true)
    try makeColorPNG(at: petRoot.appendingPathComponent("idle/main/0.png"), color: .brown)
    try writeCursorAssets(in: petRoot.appendingPathComponent("cursor", isDirectory: true))
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: 200, y: 200), size: DesktopPetView.compactContentSize),
                          styleMask: [.borderless], backing: .buffered, defer: true)
    window.contentView = view
    defer { window.close() }
    view.layoutSubtreeIfNeeded()
    guard let body = view.petBodyRect else { throw TestFailure(message: "pet body should be known") }
    let head = NSPoint(x: body.midX, y: body.maxY - body.height * 0.2)
    guard let event = NSEvent.mouseEvent(
        with: .mouseMoved, location: head, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0
    ) else { throw TestFailure(message: "mouse event") }

    view.pointerLocation = { CGPoint(x: 1_000, y: 900) }
    view.mouseMoved(with: event)
    try expect(view.currentCursorKind == nil, "the event says head, but the pointer is over another app: leave the cursor alone (got \(String(describing: view.currentCursorKind)))")

    view.pointerLocation = { window.convertPoint(toScreen: view.convert(head, to: nil)) }
    view.mouseMoved(with: event)
    try expect(view.currentCursorKind == .pat, "pointer really on the head: patting hand (got \(String(describing: view.currentCursorKind)))")
}
