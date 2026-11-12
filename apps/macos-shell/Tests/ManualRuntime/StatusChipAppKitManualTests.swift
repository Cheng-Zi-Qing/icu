import AppKit

// 桌宠下方的状态小标签：贴着文字的胶囊、文字上下居中、探头时藏起来

private func makePeekablePetView() throws -> DesktopPetView {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try makeColorPNG(
        at: petRoot.appendingPathComponent("idle/main/0.png"),
        color: NSColor(deviceRed: 0.7, green: 0.45, blue: 0.3, alpha: 1)
    )
    for frame in 0...2 {
        try makeColorPNG(
            at: petRoot.appendingPathComponent("edge/peek_\(frame).png"),
            color: NSColor(deviceRed: 0.7, green: 0.45, blue: 0.3, alpha: 1)
        )
    }
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    view.layoutSubtreeIfNeeded()
    return view
}

func testDesktopPetStatusChipHugsItsTextAndCentersUnderThePet() throws {
    let view = try makePeekablePetView()
    view.setStatusText("待机中")
    view.layoutSubtreeIfNeeded()

    let chip = try requireStatusLabel(in: view)
    let font = try require(chip.font, "status chip should have a font")
    let textWidth = ("待机中" as NSString).size(withAttributes: [.font: font]).width

    try expect(
        chip.frame.width < view.bounds.width - 40,
        "status chip should hug its text instead of spanning the whole pet (got \(chip.frame.width))"
    )
    try expect(chip.frame.width >= textWidth + 8, "status chip should keep horizontal padding around the text")
    try expect(
        abs(chip.frame.midX - view.bounds.midX) <= 1,
        "status chip should sit centered under the pet body (got midX \(chip.frame.midX))"
    )
    try expect(
        abs((chip.layer?.cornerRadius ?? 0) - chip.frame.height / 2) <= 0.5,
        "status chip should be a pill"
    )

    let cell = try require(chip.cell as? NSTextFieldCell, "status chip should use a text field cell")
    let titleRect = cell.titleRect(forBounds: chip.bounds)
    let lineHeight = ceil(font.ascender - font.descender + font.leading)
    try expect(
        abs(titleRect.midY - chip.bounds.midY) <= 1 && titleRect.height >= lineHeight - 1,
        "status text should be vertically centered in the chip (title \(titleRect), bounds \(chip.bounds))"
    )
}

func testDesktopPetStatusChipUsesAFontThatCoversChineseAndNeverTruncates() throws {
    let view = try makePeekablePetView()
    // 四种状态的标签（中英文都在 config/copy/ 里），桌宠底下的胶囊放得下、不出省略号
    // 状态条上会出现的每一句（平时状态 + Agent 状态的俏皮话，中英文）
    let catalogs = try [AppLanguage.chinese, .english].map {
        try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: $0)
    }
    let labels = catalogs.flatMap { catalog in PlayfulLines.statusPools.flatMap { catalog.texts($0) } }
    for text in labels + ["专注工作中"] {
        view.setStatusText(text)
        view.layoutSubtreeIfNeeded()
        let chip = try requireStatusLabel(in: view)
        let font = try require(chip.font, "status chip should have a font")
        let missing = text.unicodeScalars.filter { !$0.properties.isWhitespace && !font.coveredCharacterSet.contains($0) }
        try expect(missing.isEmpty, "status chip font \(font.fontName) should have glyphs for \(text)")
        let cell = try require(chip.cell, "status chip should have a cell")
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        try expect(
            cell.drawingRect(forBounds: chip.bounds).width >= ceil(textWidth) + 6,
            "status text \(text) should fit without an ellipsis"
        )
    }
}

func testStatusChipCellKeepsThemeFontWhenItCoversTheText() throws {
    let themeFont = try require(NSFont(name: "Menlo-Regular", size: 11), "Menlo should exist on macOS")
    try expect(StatusChipCell.displayFont(for: "Idle", themeFont: themeFont) == themeFont, "latin text keeps the theme font")
    let chinese = StatusChipCell.displayFont(for: "待机中", themeFont: themeFont)
    try expect(chinese != themeFont, "Chinese text should not be forced through a Latin-only font")
    try expect(chinese.pointSize == themeFont.pointSize, "fallback font should keep the theme font size")
}

func testDesktopPetStatusChipRefitsWhenTextChanges() throws {
    let view = try makePeekablePetView()
    view.setStatusText("待机中")
    view.layoutSubtreeIfNeeded()
    let chip = try requireStatusLabel(in: view)
    let shortWidth = chip.frame.width

    view.setStatusText("专注工作中 · 25 分钟")
    try expect(chip.frame.width > shortWidth, "longer status text should widen the chip right away")
    try expect(chip.frame.maxX <= view.bounds.maxX && chip.frame.minX >= 0, "status chip should stay inside the window")
}

func testDesktopPetStatusChipHidesWhilePeekingFromTheEdge() throws {
    let view = try makePeekablePetView()
    view.setStatusText("待机中")
    let chip = try requireStatusLabel(in: view)
    try expect(view.hasPeekPose, "test pet should have peek frames")
    try expect(!chip.isHidden, "status chip should be visible normally")

    view.setEdgePeek(true)
    try expect(chip.isHidden, "status chip should hide while only the head peeks out from the screen edge")

    view.setEdgePeek(false)
    try expect(!chip.isHidden, "status chip should come back when the pet slides back out")
}

func testDesktopPetFlinchFreezesOnTheFlinchFrame() throws {
    let view = try makePeekablePetView()
    view.flinchPeek()
    try expect(view.shownPeekFrame == nil, "a pet that is not peeking does not flinch")

    view.setEdgePeek(true)
    try expect(view.shownPeekFrame == .rest, "peeking starts on the rest frame")
    view.flinchPeek()
    try expect(view.shownPeekFrame == .flinch, "touching it shows the flinch frame")
    try expect(view.peekTimer == nil, "the idle peek loop stops so the flinch is not overwritten")

    view.setEdgePeek(false)
    try expect(view.shownPeekFrame == nil, "leaving the peek pose clears the peek frame")
}

/// Core Animation 会按深度给同级图层排序：桌宠图层带上 3D 变换（以前的悬停偏头就是）时，
/// 往前倾的那半边身体会盖住状态标签 / 气泡 / 提醒卡片，所以这些浮层必须固定在更前面。
/// 用以前偏头的最大幅度当最坏情况。
func testDesktopPetOverlaysStayInFrontOfATiltedPet() throws {
    let view = try makePeekablePetView()
    let imageView = try requirePetImageView(in: view)
    let tilt = LayerTransform(
        scaleX: 1.05, scaleY: 1.05,
        rotateX: 5, rotateY: 8,
        perspective: -1.0 / 500
    ).caTransform
    let half = CGPoint(x: imageView.bounds.width / 2, y: imageView.bounds.height / 2)
    let corners = [(-1.0, -1.0), (-1.0, 1.0), (1.0, -1.0), (1.0, 1.0)].map { sx, sy in
        // 行向量约定：z' = x·m13 + y·m23 + m43；正负倾斜都要算，取绝对值
        abs(CGFloat(sx) * half.x * tilt.m13 + CGFloat(sy) * half.y * tilt.m23 + tilt.m43)
    }
    let petDepth = (imageView.layer?.zPosition ?? 0) + (corners.max() ?? 0)

    let overlayIDs = [
        "desktopPet.statusLabel",
        "desktopPet.transientBubbleContainer",
        "desktopPet.transientBubbleTail",
        "desktopPet.waitCard",
    ]
    for id in overlayIDs {
        let overlay = try require(
            view.subviews.first { $0.identifier?.rawValue == id },
            "overlay \(id) should exist"
        )
        let z = overlay.layer?.zPosition ?? 0
        try expect(
            z > petDepth * 2,
            "overlay \(id) should sit in front of the tilted pet (z \(z), pet reaches \(petDepth))"
        )
    }
}

private func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message: message) }
    return value
}

/// 贴在屏幕右边：窗口透明的那一边被推到屏幕外。状态条、气泡、在等你的卡片都得留在看得见的地方，尾巴还指着身体
@MainActor
func testPetOverlaysStayOnScreenWhenDockedAgainstTheEdge() throws {
    guard let screen = NSScreen.main else { return }
    let view = try makePeekablePetView()
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: DesktopPetView.cardExpandedContentSize), styleMask: .borderless, backing: .buffered, defer: true)
    window.contentView = view
    let visible = screen.visibleFrame
    // 窗口右边 40pt 伸出屏幕
    window.setFrameOrigin(NSPoint(x: visible.maxX - window.frame.width + 40, y: visible.midY))
    view.setStatusText("陪你上班中啦")
    view.showTransientMessage("喝口水，慢慢来。")
    let wait: [String: Any] = ["v": 1, "session": "s", "event": "PermissionRequest", "tool": "Bash", "at": 1.0, "project": "icu"]
    let content = try require(AgentWaitCardContent(summary: AgentSummary(kind: .waiting, count: 1, lead: AgentSession(record: wait))), "wait card content")
    view.showWaitCard(content, onJump: { _ in }, onDismiss: {})
    view.layoutOverlaysForWindowPosition()

    let onScreen = view.convert(window.convertFromScreen(visible), from: nil)
    let chip = try requireStatusLabel(in: view)
    let bubble = try require(allSubviews(in: view).first { $0.identifier?.rawValue == "desktopPet.transientBubbleContainer" }, "bubble")
    let card = try require(allSubviews(in: view).first { $0.identifier?.rawValue == "desktopPet.waitCard" }, "wait card")
    for (name, frame) in [("status chip", chip.frame), ("bubble", bubble.frame), ("wait card", card.frame)] {
        try expect(frame.maxX <= onScreen.maxX + 0.5 && frame.minX >= onScreen.minX - 0.5, "\(name) stays on screen (frame \(frame), on screen \(onScreen))")
    }
    let tail = try require(allSubviews(in: view).first { $0.identifier?.rawValue == "desktopPet.transientBubbleTail" }, "tail")
    try expect(tail.frame.midX >= bubble.frame.minX && tail.frame.midX <= bubble.frame.maxX, "the tail stays under the bubble")
    window.close()
}
