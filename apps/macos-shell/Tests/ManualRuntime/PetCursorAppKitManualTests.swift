import AppKit

// 桌宠上的像素手型光标：头上摸摸、身上张手、拖着走时握拳

func testPetCursorKindFollowsWhatThePointerIsOver() throws {
    for (zone, expected) in [(PetPokeZone.head, PetCursorKind.pat), (.belly, .tickle), (.back, .poke),
                             (.nose, .grab), (.legs, .grab)] {
        try expect(PetCursorKind.kind(isDragging: false, overBody: true, zone: zone, activeClip: nil) == expected,
                   "hovering \(zone) shows \(expected)")
        try expect(PetCursorKind.kind(isDragging: true, overBody: true, zone: zone, activeClip: .tickled) == .grabbing,
                   "actual drag overrides the zone and active clip")
    }
    try expect(PetCursorKind.kind(isDragging: false, overBody: true, zone: nil, activeClip: nil) == .grab, "unknown body: open hand")
    try expect(PetCursorKind.kind(isDragging: true, overBody: false, zone: nil, activeClip: nil) == .grabbing, "fast drag keeps its grip off-body")
    try expect(PetCursorKind.kind(isDragging: false, overBody: false, zone: .head, activeClip: .petted) == nil, "transparent pixels override patting")
    try expect(PetCursorKind.kind(isDragging: false, overBody: false, zone: .belly, activeClip: .tickled) == nil, "transparent pixels override tickling")
    try expect(PetCursorKind.kind(isDragging: false, overBody: true, zone: .back, activeClip: .petted) == .pat, "patting clip overrides the hovered zone")
    try expect(PetCursorKind.kind(isDragging: false, overBody: true, zone: .head, activeClip: .tickled) == .tickle, "tickling clip overrides the hovered zone")
}

/// 透明区域盖在别的 App 上（比如 Otty 的文字）：桌宠不能每动一下就设箭头，跟人家的光标抢
func testPetCursorOnlyTouchesTheCursorOverThePet() throws {
    try expect(PetCursorKind.update(from: nil, to: .grab) == .show(.grab), "entering the body shows the hand")
    try expect(PetCursorKind.update(from: .grab, to: .grab) == .show(.grab), "over the body it keeps re-asserting the hand")
    try expect(PetCursorKind.update(from: .grab, to: nil) == .restoreArrow, "leaving the body hands back the arrow once")
    try expect(PetCursorKind.update(from: nil, to: nil) == .leaveAlone, "over transparent pixels the app underneath owns the cursor")
}

private func writeCursorAssets(in directory: URL, omittingImages: Set<PetCursorKind> = []) throws {
    for kind in PetCursorKind.allCases where !omittingImages.contains(kind) {
        try makeColorPNG(at: directory.appendingPathComponent("\(kind.rawValue).png"), color: .white)
    }
    let manifest = """
    {
      "pixelSize": 16,
      "pointSize": 24,
      "cursors": {
        "grab": { "file": "grab.png", "hotSpot": [9, 9] },
        "grabbing": { "file": "grabbing.png", "hotSpot": [8, 9] },
        "pat": { "file": "pat.png", "hotSpot": [7, 8] },
        "tickle": { "file": "tickle.png", "hotSpot": [6, 7] },
        "poke": { "file": "poke.png", "hotSpot": [5, 6] }
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
    try expect(cursors.cursor(for: .tickle).hotSpot == NSPoint(x: 9, y: 10.5), "tickle cursor loads its own asset")
    try expect(cursors.cursor(for: .poke).hotSpot == NSPoint(x: 7.5, y: 9), "poke cursor loads its own asset")
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
        try expect(cursors.cursor(for: .tickle) === NSCursor.pointingHand, "no tickle art: pointing hand")
        try expect(cursors.cursor(for: .poke) === NSCursor.pointingHand, "no poke art: pointing hand")
    }
    let partial = try makeTemporaryDirectory()
    try writeCursorAssets(in: partial, omittingImages: [.tickle, .poke])
    let cursors = PetCursorSet(directory: partial)
    try expect(cursors.cursor(for: .tickle) === NSCursor.pointingHand, "missing tickle.png uses the system hand")
    try expect(cursors.cursor(for: .poke) === NSCursor.pointingHand, "missing poke.png uses the system hand")
    try expect(cursors.cursor(for: .grab) !== NSCursor.openHand, "existing assets still load when new images are missing")
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
    view.behavior = PetBehaviorCoordinator(sprites: { _ in nil }, startsTimer: false)
    view.layoutSubtreeIfNeeded()

    func move(to point: NSPoint) throws {
        view.mouseMoved(with: try cursorMouseEvent(.mouseMoved, at: point))
    }

    guard let image = view.currentImage else { throw TestFailure(message: "pet image should be known") }
    let rect = view.aspectFitRect(for: image.size, in: view.petCanvasRect)
    func point(x: CGFloat, y: CGFloat, mirrored: Bool) -> NSPoint {
        NSPoint(x: rect.minX + (mirrored ? 32 - x : x) / 32 * rect.width,
                y: rect.maxY - y / 32 * rect.height)
    }
    for mirrored in [false, true] {
        view.setFacingRight(mirrored)
        for (x, y, expected) in [(CGFloat(12), CGFloat(10), PetCursorKind.pat),
                                 (12, 22, .tickle), (25, 22, .poke), (4, 10, .grab), (12, 29, .grab)] {
            let local = point(x: x, y: y, mirrored: mirrored)
            try move(to: local)
            try expect(view.currentCursorKind == expected, "\(mirrored ? "right" : "left") facing hover shows \(expected)")
            view.mouseDown(with: try cursorMouseEvent(.leftMouseDown, at: local))
            try expect(view.isPressingPet && !view.isDraggingPet && view.currentCursorKind == expected,
                       "press before drag keeps \(expected)")
            view.mouseUp(with: try cursorMouseEvent(.leftMouseUp, at: local))
            try expect(view.currentCursorKind == expected, "release restores \(expected)")
        }
    }
    view.setFacingRight(false)
    try move(to: NSPoint(x: rect.minX - 1, y: rect.midY))
    try expect(view.currentCursorKind == nil, "transparent space beside the sprite has no pet cursor")

    view.setWorkActivity(.write)
    try move(to: point(x: 12, y: 10, mirrored: false))
    try expect(view.currentCursorKind == .grab, "front-facing work scenes use a generic grab hand")
    view.setWorkActivity(nil)
    let edge = petRoot.appendingPathComponent("edge", isDirectory: true)
    try makeColorPNG(at: edge.appendingPathComponent(PetPeekFrame.rest.fileName), color: .brown)
    view.reloadPoseSprites()
    view.setEdgePeek(true)
    defer { view.setEdgePeek(false) }
    view.showPeekFrame(.turned)
    try move(to: point(x: 12, y: 22, mirrored: false))
    try expect(view.currentCursorKind == .pat, "a rotated peeking head never becomes a belly")
    view.setEdgePeek(false)
    try verifyCursorDragEvents(view, at: point(x: 25, y: 22, mirrored: false))
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
    try verifyStationaryCursorFollowsActionClips(view, window: window)
}

private func cursorMouseEvent(_ type: NSEvent.EventType, at point: NSPoint, windowNumber: Int = 0) throws -> NSEvent {
    guard let event = NSEvent.mouseEvent(
        with: type, location: point, modifierFlags: [], timestamp: 0,
        windowNumber: windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
    ) else { throw TestFailure(message: "cursor mouse event") }
    return event
}

private func verifyCursorDragEvents(_ view: DesktopPetView, at point: NSPoint) throws {
    let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: 200, y: 200), size: view.bounds.size),
                          styleMask: [.borderless], backing: .buffered, defer: true)
    window.contentView = view
    defer { window.close() }
    view.pointerLocation = { window.convertPoint(toScreen: view.convert(point, to: nil)) }
    view.mouseDown(with: try cursorMouseEvent(.leftMouseDown, at: point, windowNumber: window.windowNumber))
    try expect(view.currentCursorKind == .poke && !view.isDraggingPet, "butt press stays poke before threshold")
    view.mouseDragged(with: try cursorMouseEvent(.leftMouseDragged, at: point, windowNumber: window.windowNumber))
    try expect(view.currentCursorKind == .poke && !view.isDraggingPet, "drag event below threshold keeps the poke hand")
    // Seed the existing controller's press point; the event still uses the real system pointer for dragging.
    let actual = NSEvent.mouseLocation
    view.dragController.mouseDown(mouseLocation: CGPoint(x: actual.x - 20, y: actual.y), windowOrigin: window.frame.origin)
    view.mouseDragged(with: try cursorMouseEvent(.leftMouseDragged, at: point, windowNumber: window.windowNumber))
    try expect(view.isDraggingPet && view.currentCursorKind == .grabbing, "the first actual drag event immediately closes the hand")
    view.pointerLocation = { window.convertPoint(toScreen: CGPoint(x: -100, y: -100)) }
    view.updateCursor(at: point)
    try expect(view.currentCursorKind == .grabbing, "drag keeps its grip when the pointer briefly leaves the body")
    view.pointerLocation = { window.convertPoint(toScreen: view.convert(point, to: nil)) }
    view.mouseUp(with: try cursorMouseEvent(.leftMouseUp, at: point, windowNumber: window.windowNumber))
    try expect(!view.isDraggingPet && view.currentCursorKind == .poke, "release returns to the butt poke hand")
    view.updateCursor(at: nil)
}

private func verifyStationaryCursorFollowsActionClips(_ view: DesktopPetView, window: NSWindow) throws {
    let directory = try makeTemporaryDirectory()
    for clip in [PetActionClip.petted, .tickled] {
        for name in clip.frameNames {
            try makeColorPNG(at: directory.appendingPathComponent(name), color: .brown)
        }
    }
    let sprites = PetPoseSprites(directory: directory, canvasPointSize: DesktopPetView.compactContentSize)
    var time: TimeInterval = 1000
    let coordinator = PetBehaviorCoordinator(sprites: { _ in sprites }, userIdle: { 0 }, now: { time }, startsTimer: false)
    view.behavior = coordinator
    coordinator.onImageChanged = { [weak view] in view?.applyActionImage($0) }
    guard let image = view.currentImage else { throw TestFailure(message: "pet image") }
    let rect = view.aspectFitRect(for: image.size, in: view.petCanvasRect)
    let head = NSPoint(x: rect.minX + rect.width * 12 / 32, y: rect.maxY - rect.height * 10 / 32)
    let belly = NSPoint(x: head.x, y: rect.maxY - rect.height * 22 / 32)
    var pointer = head
    var reads = 0
    view.pointerLocation = {
        reads += 1
        return window.convertPoint(toScreen: view.convert(pointer, to: nil))
    }
    view.updateCursor(at: head)
    try expect(view.currentCursorKind == .pat, "stationary pointer starts on head")
    coordinator.poked(.belly)
    try expect(coordinator.activeClip == .tickled && view.currentCursorKind == .tickle, "tickled starts without a mouse event")
    reads = 0
    time += 1 / PetActionClip.tickled.framesPerSecond
    coordinator.tick()
    try expect(reads == 0, "another frame of the same clip does not reapply the cursor")
    time += PetActionClip.tickled.duration
    coordinator.tick()
    try expect(coordinator.activeClip == nil && view.currentCursorKind == .pat, "tickled ends back on head without mouse movement")

    pointer = belly
    view.updateCursor(at: belly)
    try expect(view.currentCursorKind == .tickle, "belly starts with tickle")
    for x: CGFloat in [40, 50, 60, 50, 40, 50, 60] {
        time += 0.08
        coordinator.pointerMoved(x: x, overHead: true)
    }
    try expect(coordinator.activeClip == .petted && view.currentCursorKind == .pat, "petted starts without a pointer event")
    time += PetActionClip.petted.duration
    coordinator.tick()
    try expect(coordinator.activeClip == nil && view.currentCursorKind == .tickle, "petted ends back on belly without mouse movement")

    pointer = NSPoint(x: rect.minX - 5, y: rect.midY)
    coordinator.poked(.belly)
    try expect(view.currentCursorKind == nil && !view.cursorGate.isOpen, "clip start on transparent space leaves cursor alone")
    view.pointerLocation = { window.convertPoint(toScreen: CGPoint(x: -100, y: -100)) }
    time += PetActionClip.tickled.duration
    coordinator.tick()
    try expect(view.currentCursorKind == nil && !view.cursorGate.isOpen, "clip end over another app does not claim the cursor")
}
