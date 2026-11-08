import AppKit

func testDesktopPetViewUsesInstalledCopyCatalogForInitialStatusLabel() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "pet": {
            "status_idle": "待机中"
          }
        }
        """,
        overrideJSON: """
        {
          "pet": {
            "status_idle": "空闲待命"
          }
        }
        """
    )

    let manager = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    _ = manager
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )

    let statusLabel = try requireStatusLabel(in: view)

    try expect(
        statusLabel.stringValue == "空闲待命",
        "desktop pet view should use the installed copy catalog for its initial status text"
    )
}

func testDesktopPetViewShowsTransientBubbleSeparateFromStatusChip() throws {
    let manager = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    _ = manager
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    view.setStatusText("待机中")

    let statusLabel = try requireStatusLabel(in: view)
    try expect(statusLabel.stringValue == "待机中", "test setup should keep the persistent status chip visible")
    try expect(
        findTransientBubbleLabel(in: view) == nil,
        "desktop pet should not create a transient bubble before a message is shown"
    )

    view.showTransientMessage("看看远处", duration: 0.05)

    let bubbleLabel = try requireTransientBubbleLabel(in: view)
    try expect(
        bubbleLabel.stringValue == "看看远处",
        "transient message should render inside a dedicated bubble label"
    )
    try expect(
        statusLabel.stringValue == "待机中",
        "transient bubble should not overwrite the persistent status chip text"
    )

    try expect(
        waitForCondition(timeout: 0.3) {
            findTransientBubbleLabel(in: view) == nil
        },
        "transient bubble should dismiss itself after the requested duration"
    )
    try expect(
        statusLabel.stringValue == "待机中",
        "persistent status chip should remain visible after the transient bubble disappears"
    )
}

func testDesktopPetViewAdvancesFramesForMultiFrameIdleAnimation() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let frame0 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let frame1 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("1.png", isDirectory: false)
    try makeColorPNG(at: frame0, color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))
    try makeColorPNG(at: frame1, color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    try expect(view.currentFrameIndexForTesting == 0, "multi-frame animation should start at frame 0")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 0, blue: 0),
        "desktop pet should render the first frame immediately after load"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 1, "frame advance should move to next frame index")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 255, blue: 0),
        "frame advance should render the next frame image"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 0, "frame advance should wrap around for looping animations")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 0, blue: 0),
        "wrapped frame advance should render frame 0 again"
    )
}

func testDesktopPetViewKeepsLegacySingleFrameAnimationStatic() throws {
    let appPaths = try makeTemporaryAppPaths()
    let legacyFrame = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try makeColorPNG(at: legacyFrame, color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    try expect(view.currentFrameIndexForTesting == 0, "legacy single-frame animation should start at frame 0")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 0, blue: 255),
        "legacy animation should render the only available frame"
    )

    view.advanceAnimationFrameForTesting()
    view.advanceAnimationFrameForTesting()

    try expect(view.currentFrameIndexForTesting == 0, "legacy single-frame animation should not advance out of bounds")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 0, blue: 255),
        "legacy single-frame animation should remain visually static when advanced"
    )
}

func testDesktopPetViewDoesNotAutoAdvanceWhileDetachedFromWindow() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let frame0 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let frame1 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("1.png", isDirectory: false)
    try makeColorPNG(at: frame0, color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))
    try makeColorPNG(at: frame1, color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )

    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

    try expect(
        view.currentFrameIndexForTesting == 0,
        "desktop pet should not auto-advance frames before it is attached to a window"
    )
}

func testDesktopPetViewHitTestUsesAspectFitImageRectForTransparency() throws {
    let appPaths = try makeTemporaryAppPaths()
    let frameURL = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try makeRightHalfOpaquePNG(at: frameURL, opaqueColor: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 80, height: 40),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )

    let transparentPaddingPoint = NSPoint(x: 70, y: 34)
    let opaqueImagePoint = NSPoint(x: 50, y: 20)

    try expect(
        view.hitTest(transparentPaddingPoint) == nil,
        "hit testing should click through right-side aspect-fit padding"
    )
    try expect(
        view.hitTest(opaqueImagePoint) != nil,
        "hit testing should still hit opaque pixels inside the drawn image rect"
    )
}

func testDesktopPetViewRoutesOpaquePetHitsToSelfForDragging() throws {
    let appPaths = try makeTemporaryAppPaths()
    let frameURL = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try makeColorPNG(at: frameURL, color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 80, height: 80),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )

    let hitView = view.hitTest(NSPoint(x: 40, y: 40))
    let actualDescription = hitView.map { String(describing: type(of: $0)) } ?? "nil"
    try expect(
        hitView === view,
        "opaque pet clicks should resolve to the desktop pet view so dragging can start (got \(actualDescription))"
    )
}

func testDesktopPetViewRoutesStatusChipHitsToSelfForDragging() throws {
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let statusLabel = try requireStatusLabel(in: view)
    let statusPoint = NSPoint(x: statusLabel.frame.midX, y: statusLabel.frame.midY)

    let hitView = view.hitTest(statusPoint)
    try expect(
        hitView === view,
        "status chip clicks should stay on the desktop pet view so the window remains draggable"
    )
}

func testDesktopPetViewAcceptsFirstMouseForDesktopDragging() throws {
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))

    try expect(
        view.acceptsFirstMouse(for: nil),
        "desktop pet should accept first mouse so dragging works from the inactive desktop"
    )
}

@MainActor
func testDesktopPetViewHandlesDraggingItself() throws {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let stateStore = try StateStore(paths: appPaths)
    let workSessionController = try WorkSessionController(store: stateStore)
    let healthStore = try HealthMetricsStore(appPaths: appPaths)
    let healthTracker = HealthSessionTracker(store: healthStore)
    let assetLocator = PetAssetLocator(appPaths: appPaths)
    let scheduler = ReminderScheduler()

    let controller = DesktopPetWindowController(
        workSessionController: workSessionController,
        reminderScheduler: scheduler,
        healthTracker: healthTracker,
        assetLocator: assetLocator,
        petID: "missing_pet",
        onQuitRequested: {}
    )
    defer { controller.close() }

    // 拖拽由视图自己处理（带拎起 / 摆动 / 落地效果），不能再交给系统移动窗口，
    // 否则视图收不到拖动和松手事件
    try expect(
        controller.window?.isMovableByWindowBackground == false,
        "desktop pet window should not let the system take over dragging"
    )
    let petView = controller.window?.contentView as? DesktopPetView
    try expect(petView != nil, "desktop pet window content should be the pet view")
    try expect(petView?.mouseDownCanMoveWindow == false, "pet view should move the window itself while dragging")
}

func testPetDragControllerMovesWindowWithPointerAfterThreshold() throws {
    var now: TimeInterval = 0
    let controller = PetDragController(timeProvider: { now })
    let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
    // 身体只占窗口左边 104pt，右侧透明留白可以出屏
    let body = CGRect(x: 0, y: 4, width: 104, height: 116)

    controller.mouseDown(mouseLocation: CGPoint(x: 500, y: 300), windowOrigin: CGPoint(x: 440, y: 240))
    now = 0.02
    let beforeThreshold = controller.mouseDragged(mouseLocation: CGPoint(x: 501, y: 301), keepVisible: body, visibleFrame: visibleFrame)
    try expect(beforeThreshold == nil, "tiny movement should not move the window")

    now = 0.05
    let moved = controller.mouseDragged(mouseLocation: CGPoint(x: 540, y: 330), keepVisible: body, visibleFrame: visibleFrame)
    try expect(moved == CGPoint(x: 480, y: 270), "window should follow the pointer offset (got \(String(describing: moved)))")

    now = 0.1
    let clamped = controller.mouseDragged(mouseLocation: CGPoint(x: 1500, y: 330), keepVisible: body, visibleFrame: visibleFrame)
    try expect(clamped?.x == 896, "the body (not the window) should stop at the screen edge (got \(String(describing: clamped)))")

    now = 0.15
    try expect(controller.mouseUp(), "releasing after a drag should report a drag")
    controller.mouseDown(mouseLocation: CGPoint(x: 10, y: 10), windowOrigin: .zero)
    try expect(!controller.mouseUp(), "press and release without moving should report a click")
}

func testDesktopPetViewSetWorkStateImmediatelyReloadsMatchingAnimationFamily() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "idle",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 0, blue: 0),
        "desktop pet should start from the idle animation family"
    )

    view.setWorkState(.working)

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "setWorkState(.working) should immediately load the working animation family"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 255, blue: 0),
        "working state should immediately replace the displayed frame"
    )
}

func testDesktopPetViewMapsFocusToWorkingAndBreakToAlertAnimationFamilies() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    view.setWorkState(.focus)
    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "focus should map onto the working animation family"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 255, blue: 0),
        "focus should reuse the working animation frames"
    )

    view.setWorkState(.breakState)
    try expect(
        view.currentAnimationStateIDForTesting == "alert",
        "break should map onto the alert animation family"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 0, blue: 255),
        "break should immediately switch to the alert frames"
    )
}

func testDesktopPetViewVariantRotationStaysWithinCurrentStateFamily() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([1])
    )
    let imageView = try requirePetImageView(in: view)
    view.setWorkState(.working)

    try expect(view.currentAnimationStateIDForTesting == "working", "test setup should enter working state")
    try expect(view.currentVariantIDForTesting == "main", "working state should start from the default variant")

    view.triggerVariantRotationForTesting()

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "same-state variant rotation must stay inside the working animation family"
    )
    try expect(
        view.currentVariantIDForTesting == "alt",
        "same-state variant rotation should be able to select a sibling working variant"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 255, blue: 0),
        "same-state variant rotation should load the selected working variant frame"
    )
}

func testDesktopPetViewTimedVariantRotationStaysWithinCurrentStateFamily() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 1,
        color: NSColor(deviceRed: 0, green: 0.5, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([0])
    )
    let imageView = try requirePetImageView(in: view)
    view.setWorkState(.working)

    try expect(view.currentAnimationStateIDForTesting == "working", "test setup should enter working state")
    try expect(view.currentVariantIDForTesting == "main", "working state should start from the default variant")

    for tick in 1...4 {
        view.advanceAnimationFrameForTesting()
        try expect(
            view.currentAnimationStateIDForTesting == "working",
            "cooldown tick \(tick) should keep the timed rotation inside the working state family"
        )
        try expect(
            view.currentVariantIDForTesting == "main",
            "cooldown tick \(tick) should not rotate variants before the working cooldown expires"
        )
    }

    view.advanceAnimationFrameForTesting()

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "timed same-state rotation must stay inside the working animation family"
    )
    try expect(
        view.currentVariantIDForTesting == "alt",
        "timed same-state rotation should select a sibling working variant after the cooldown expires"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 255, blue: 0),
        "timed same-state rotation should load the selected working variant frame instead of alert"
    )
}

func testDesktopPetViewTimedVariantRotationWorksForSingleFrameVariants() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([0])
    )
    let imageView = try requirePetImageView(in: view)
    view.setWorkState(.working)

    try expect(view.currentAnimationStateIDForTesting == "working", "test setup should enter working state")
    try expect(view.currentVariantIDForTesting == "main", "single-frame working state should start from the default variant")

    for tick in 1...4 {
        view.advanceAnimationTickForTesting()
        try expect(
            view.currentAnimationStateIDForTesting == "working",
            "single-frame cooldown tick \(tick) should keep the runtime inside the working family"
        )
        try expect(
            view.currentVariantIDForTesting == "main",
            "single-frame cooldown tick \(tick) should not rotate before the working cooldown expires"
        )
    }

    view.advanceAnimationTickForTesting()

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "single-frame timed rotation must stay inside the working animation family"
    )
    try expect(
        view.currentVariantIDForTesting == "alt",
        "single-frame timed rotation should rotate to a sibling working variant after the cooldown expires"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 255, blue: 0),
        "single-frame timed rotation should load the selected working variant frame instead of alert"
    )
}

func testDesktopPetViewVariantRotationWaitsForOneCompletedLoop() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 1,
        color: NSColor(deviceRed: 0, green: 0.5, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([1, 1])
    )
    view.setWorkState(.working)

    try expect(view.currentVariantIDForTesting == "main", "working state should start on the primary variant")

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "main",
        "variant rotation must not interrupt the current variant before one full loop completes"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 1, "test setup should advance into the second frame")

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "main",
        "variant rotation must still be blocked before the first loop wraps to frame 0"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 0, "working variant should wrap after one full loop")

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "alt",
        "variant rotation should unlock after the current variant completes a full loop"
    )
}

func testDesktopPetViewOnceVariantUnlocksRotationAtLastFrame() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 1,
        color: NSColor(deviceRed: 0, green: 0.5, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try writeText(
        at: petRoot.appendingPathComponent("config.json", isDirectory: false),
        contents: """
        {
          "id": "capybara",
          "animations": {
            "working": {
              "variants": {
                "main": { "loop_mode": "once" }
              }
            }
          }
        }
        """
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([0])
    )
    view.setWorkState(.working)

    try expect(view.currentVariantIDForTesting == "main", "working once variant should start on main")

    view.advanceAnimationFrameForTesting()
    try expect(
        view.currentFrameIndexForTesting == 1,
        "once variant should advance to its last frame before unlocking rotation"
    )

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "alt",
        "once variants should unlock same-state rotation after reaching their last frame"
    )
}

func testPetMotionEnhancerProvidesDistinctProfilesPerState() throws {
    let idle = PetMotionEnhancer.profile(for: "idle")
    let working = PetMotionEnhancer.profile(for: "working")
    let alert = PetMotionEnhancer.profile(for: "alert")

    try expect(idle != working, "idle and working motion profiles should differ")
    try expect(working != alert, "working and alert motion profiles should differ")
    try expect(idle != alert, "idle and alert motion profiles should differ")
}

func makeInstalledThemeManager() throws -> ThemeManager {
    let manager = ThemeManager()
    ThemeManager.installShared(manager)
    return manager
}

func requireLabel(in root: NSView, stringValue: String) throws -> NSTextField {
    if let label = allSubviews(in: root).compactMap({ $0 as? NSTextField }).first(where: { $0.stringValue == stringValue }) {
        return label
    }

    throw TestFailure(message: "expected label '\(stringValue)' to exist")
}

func requireStatusLabel(in view: DesktopPetView) throws -> NSTextField {
    if let label = view.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.identifier?.rawValue == "desktopPet.statusLabel" }) {
        return label
    }

    throw TestFailure(message: "desktop pet status label should exist")
}

func findTransientBubbleLabel(in view: DesktopPetView) -> NSTextField? {
    allSubviews(in: view)
        .compactMap { $0 as? NSTextField }
        .first(where: { $0.identifier?.rawValue == "desktopPet.transientBubbleLabel" && !$0.isHidden && !($0.superview?.isHidden ?? false) })
}

func requireTransientBubbleLabel(in view: DesktopPetView) throws -> NSTextField {
    if let label = findTransientBubbleLabel(in: view) {
        return label
    }

    throw TestFailure(message: "desktop pet transient bubble label should exist")
}

func requirePetImageView(in view: DesktopPetView) throws -> NSImageView {
    if let imageView = view.subviews.compactMap({ $0 as? NSImageView }).first {
        return imageView
    }

    throw TestFailure(message: "desktop pet image view should exist")
}

@discardableResult
func waitForCondition(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.01,
    _ condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }

    return condition()
}

func requireButton(in root: NSView, title: String) throws -> NSButton {
    if let button = allSubviews(in: root).compactMap({ $0 as? NSButton }).first(where: { $0.title == title }) {
        return button
    }

    throw TestFailure(message: "expected button '\(title)' to exist")
}

func requireActionButton(in root: NSView, title: String) throws -> NSButton {
    if let button = allSubviews(in: root)
        .compactMap({ $0 as? NSButton })
        .first(where: { $0.title == title && $0.action != nil }) {
        return button
    }

    throw TestFailure(message: "expected actionable button '\(title)' to exist")
}

private func requireTextView(in root: NSView, identifier: String) throws -> NSTextView {
    if let textView = allSubviews(in: root)
        .compactMap({ $0 as? NSTextView })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return textView
    }
    throw TestFailure(message: "missing text view: \(identifier)")
}

func requireTextField(in root: NSView, identifier: String) throws -> NSTextField {
    if let textField = allSubviews(in: root)
        .compactMap({ $0 as? NSTextField })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return textField
    }

    throw TestFailure(message: "missing text field: \(identifier)")
}

func allSubviews(in root: NSView) -> [NSView] {
    var result: [NSView] = [root]
    for subview in root.subviews {
        result.append(contentsOf: allSubviews(in: subview))
    }
    return result
}

func hexString(_ color: NSColor?) -> String? {
    guard let converted = color?.usingColorSpace(.deviceRGB) else {
        return nil
    }

    let red = Int(round(converted.redComponent * 255))
    let green = Int(round(converted.greenComponent * 255))
    let blue = Int(round(converted.blueComponent * 255))
    return String(format: "#%02X%02X%02X", red, green, blue)
}

func matchesColor(
    _ color: NSColor?,
    red: Int,
    green: Int,
    blue: Int,
    tolerance: Int = 4
) -> Bool {
    guard let converted = color?.usingColorSpace(.deviceRGB) else {
        return false
    }

    let actualRed = Int(round(converted.redComponent * 255))
    let actualGreen = Int(round(converted.greenComponent * 255))
    let actualBlue = Int(round(converted.blueComponent * 255))

    return abs(actualRed - red) <= tolerance
        && abs(actualGreen - green) <= tolerance
        && abs(actualBlue - blue) <= tolerance
}

func makeTinyPNG() throws -> URL {
    let url = try makeTemporaryDirectory().appendingPathComponent("preview.png", isDirectory: false)
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.white.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
    image.unlockFocus()

    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw TestFailure(message: "failed to generate preview png")
    }

    try pngData.write(to: url, options: .atomic)
    return url
}

func makeColorPNG(at url: URL, color: NSColor) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
    image.unlockFocus()

    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw TestFailure(message: "failed to generate color png")
    }

    try pngData.write(to: url, options: .atomic)
}

func makeStateColorPNG(
    appPaths: AppPaths,
    petID: String,
    stateID: String,
    variantID: String? = nil,
    frameIndex: Int,
    color: NSColor
) throws {
    var url = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent(petID, isDirectory: true)
        .appendingPathComponent(stateID, isDirectory: true)

    if let variantID {
        url.appendPathComponent(variantID, isDirectory: true)
    }

    url.appendPathComponent("\(frameIndex).png", isDirectory: false)
    try makeColorPNG(at: url, color: color)
}

func makeDeterministicVariantIndexProvider(_ indexes: [Int]) -> (Int) -> Int {
    var remaining = indexes
    return { upperBound in
        guard upperBound > 0 else {
            return 0
        }
        guard !remaining.isEmpty else {
            return 0
        }
        return max(0, min(remaining.removeFirst(), upperBound - 1))
    }
}

func makeRightHalfOpaquePNG(at url: URL, opaqueColor: NSColor) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
    opaqueColor.setFill()
    NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 8)).fill()
    image.unlockFocus()

    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw TestFailure(message: "failed to generate half-opaque png")
    }

    try pngData.write(to: url, options: .atomic)
}

func sampleCenterColor(in image: NSImage?) -> NSColor? {
    guard
        let image,
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        return nil
    }

    let width = cgImage.width
    let height = cgImage.height
    let px = width / 2
    let py = height / 2
    guard px >= 0, py >= 0, px < width, py < height else {
        return nil
    }

    guard let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.translateBy(x: CGFloat(-px), y: CGFloat(-py))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let data = context.data else {
        return nil
    }
    let buffer = data.bindMemory(to: UInt8.self, capacity: 4)
    return NSColor(
        deviceRed: CGFloat(buffer[0]) / 255.0,
        green: CGFloat(buffer[1]) / 255.0,
        blue: CGFloat(buffer[2]) / 255.0,
        alpha: CGFloat(buffer[3]) / 255.0
    )
}

func makeBridgeScript(body: String) throws -> URL {
    let url = try makeTemporaryDirectory().appendingPathComponent("bridge.py", isDirectory: false)
    try writeText(at: url, contents: body)
    return url
}

private final class ImmediateWindowMover: WindowMoving {
    private(set) var moves: [CGPoint] = []
    func move(_ window: NSWindow, to origin: CGPoint, duration: TimeInterval, completion: @escaping () -> Void) {
        moves.append(origin)
        window.setFrameOrigin(origin)
        completion()
    }
    func cancel() {}
}

private final class ManualHideScheduler: HideScheduling {
    private(set) var pending: (() -> Void)?
    private(set) var scheduledDelay: TimeInterval?
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        scheduledDelay = delay
        pending = action
    }
    func cancel() { pending = nil }
    func fire() {
        let action = pending
        pending = nil
        action?()
    }
}

func testPetEdgeDockControllerSnapsHidesAndPeeksOut() throws {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let window = NSWindow(contentRect: NSRect(x: 1321, y: 300, width: 128, height: 128), styleMask: [.borderless], backing: .buffered, defer: true)
    let mover = ImmediateWindowMover()
    let scheduler = ManualHideScheduler()
    var facingRight = false
    var persisted: [CGPoint] = []
    let controller = PetEdgeDockController(
        window: window,
        settings: EdgeSnapSettings(isEnabled: true, snapDistance: 20, peekWidth: 40, autoHideDelay: 2),
        bodyRectProvider: { facingRight ? CGRect(x: 24, y: 4, width: 104, height: 116) : CGRect(x: 0, y: 4, width: 104, height: 116) },
        visibleFrameProvider: { _ in screen },
        mover: mover,
        hideScheduler: scheduler
    )
    controller.onFacingChanged = { facingRight = $0 }
    controller.onDockedOriginSettled = { persisted.append($0) }

    controller.dragEnded()
    try expect(window.frame.origin == CGPoint(x: 1336, y: 300), "release near the right edge should snap the body flush (got \(window.frame.origin))")
    try expect(controller.dock == EdgeDock(horizontal: .right, sitsOnBottom: false), "controller should remember the right dock")
    try expect(persisted.last == CGPoint(x: 1336, y: 300), "docked position should be persisted")
    try expect(scheduler.scheduledDelay == 2, "auto hide should be scheduled with the configured delay")

    scheduler.fire()
    try expect(controller.isHidden, "pet should hide into the edge after the delay")
    try expect(window.frame.origin == CGPoint(x: 1400, y: 300), "only the peek width should stay on screen (got \(window.frame.origin))")
    try expect(persisted.last == CGPoint(x: 1336, y: 300), "hidden position must not overwrite the saved docked position")

    controller.pointerEntered()
    try expect(!controller.isHidden && window.frame.origin == CGPoint(x: 1336, y: 300), "hovering should slide the pet back out")
    try expect(scheduler.pending == nil, "no hide while the pointer is over the pet")
    controller.pointerExited()
    try expect(scheduler.pending != nil, "leaving the pet should re-arm auto hide")

    controller.overlayVisibilityChanged(true)
    try expect(scheduler.pending == nil && !controller.isHidden, "reminder overlays keep the pet out")

    // 拖到左边：形象镜像，脸朝屏幕里
    controller.overlayVisibilityChanged(false)
    controller.dragStarted()
    try expect(scheduler.pending == nil && controller.dock == .none, "dragging should cancel docking")
    window.setFrameOrigin(CGPoint(x: 10, y: 500))
    controller.dragEnded()
    try expect(facingRight, "docking left should mirror the pet so it faces into the screen")
    try expect(window.frame.origin == CGPoint(x: -24, y: 500), "mirrored body should be flush with the left edge (got \(window.frame.origin))")
    scheduler.fire()
    try expect(window.frame.origin == CGPoint(x: -88, y: 500), "left hide should leave 40pt of the body (got \(window.frame.origin))")

    // 中间松手：不吸附也不藏
    controller.dragStarted()
    window.setFrameOrigin(CGPoint(x: 600, y: 400))
    controller.dragEnded()
    try expect(controller.dock == .none && scheduler.pending == nil, "drops away from edges should not dock")
}

/// 转头看鼠标会自己改朝向，贴边时必须重新把脸摆向屏幕里，不能以为「上次已经朝左了」就跳过
func testPetEdgeDockControllerReassertsFacingOnEverySnap() throws {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let window = NSWindow(contentRect: NSRect(x: 1321, y: 300, width: 128, height: 128), styleMask: [.borderless], backing: .buffered, defer: true)
    var facingRight = false
    var reported: [Bool] = []
    let controller = PetEdgeDockController(
        window: window,
        settings: EdgeSnapSettings(isEnabled: true, snapDistance: 20, peekWidth: 40, autoHideDelay: 2),
        bodyRectProvider: { facingRight ? CGRect(x: 24, y: 4, width: 104, height: 116) : CGRect(x: 0, y: 4, width: 104, height: 116) },
        visibleFrameProvider: { _ in screen },
        mover: ImmediateWindowMover(),
        hideScheduler: ManualHideScheduler()
    )
    controller.onFacingChanged = { facingRight = $0; reported.append($0) }

    controller.dragEnded()
    try expect(controller.dock.horizontal == .right && !facingRight, "docked right, facing into the screen")

    // 离开边缘后被鼠标吸引转向右边，又拖回右边贴住
    controller.dragStarted()
    window.setFrameOrigin(CGPoint(x: 700, y: 300))
    controller.dragEnded()
    facingRight = true
    controller.dragStarted()
    window.setFrameOrigin(CGPoint(x: 1321, y: 300))
    controller.dragEnded()
    try expect(!facingRight, "snapping right again should turn the face back into the screen (reported \(reported))")
}

func testPetEdgeDockControllerDucksBehindEdgeThenPeeksOut() throws {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let window = NSWindow(contentRect: NSRect(x: 1321, y: 300, width: 128, height: 152), styleMask: [.borderless], backing: .buffered, defer: true)
    let mover = ImmediateWindowMover()
    let scheduler = ManualHideScheduler()
    var peeking = false
    var peekChanges: [Bool] = []
    // 坐姿身体占左边 104pt；探头图贴着画布右边，占右边 72pt
    let sittingBody = CGRect(x: 0, y: 4, width: 104, height: 116)
    let peekBody = CGRect(x: 56, y: 8, width: 72, height: 112)
    let controller = PetEdgeDockController(
        window: window,
        settings: EdgeSnapSettings(isEnabled: true, snapDistance: 20, peekWidth: 40, autoHideDelay: 2),
        bodyRectProvider: { peeking ? peekBody : sittingBody },
        visibleFrameProvider: { _ in screen },
        mover: mover,
        hideScheduler: scheduler
    )
    controller.canPeek = { true }
    controller.onPeekChanged = { peeking = $0; peekChanges.append($0) }

    controller.dragEnded()
    try expect(window.frame.origin == CGPoint(x: 1336, y: 300), "release near the edge should snap flush first")

    scheduler.fire()
    try expect(peekChanges == [true], "hiding should switch to the peek pose once")
    try expect(mover.moves.contains(CGPoint(x: 1440, y: 300)), "pet should first duck completely behind the edge (moves: \(mover.moves))")
    try expect(window.frame.origin == CGPoint(x: 1312, y: 300), "peek pose should end flush with the screen edge (got \(window.frame.origin))")
    try expect(controller.isHidden, "peeking counts as hidden")

    controller.pointerEntered()
    try expect(peekChanges == [true, false], "hovering should leave the peek pose")
    try expect(window.frame.origin == CGPoint(x: 1336, y: 300), "pet should come back out to the docked spot (got \(window.frame.origin))")

    // 探头时被抓起：立刻恢复正常形象
    controller.pointerExited()
    scheduler.fire()
    try expect(peeking, "should be peeking again after the delay")
    controller.dragStarted()
    try expect(!peeking, "grabbing a peeking pet should restore the normal pose")
}

func testPetEdgeDockControllerDoesNothingWhenDisabled() throws {
    let window = NSWindow(contentRect: NSRect(x: 1321, y: 300, width: 128, height: 128), styleMask: [.borderless], backing: .buffered, defer: true)
    let scheduler = ManualHideScheduler()
    let controller = PetEdgeDockController(
        window: window,
        settings: EdgeSnapSettings(isEnabled: false, snapDistance: 20, peekWidth: 40, autoHideDelay: 2),
        bodyRectProvider: { CGRect(x: 0, y: 4, width: 104, height: 116) },
        visibleFrameProvider: { _ in CGRect(x: 0, y: 25, width: 1440, height: 875) },
        mover: ImmediateWindowMover(),
        hideScheduler: scheduler
    )
    controller.dragEnded()
    try expect(window.frame.origin == CGPoint(x: 1321, y: 300), "disabled edge snap should leave the window where it was dropped")
    try expect(scheduler.pending == nil, "disabled edge snap should never auto hide")
}
