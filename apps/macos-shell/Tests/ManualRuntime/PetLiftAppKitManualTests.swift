import AppKit

// 拎起来：身体挂在后颈上跟着鼠标甩，整只都要露出来（不被 128pt 的桌宠窗口裁掉）

private func transformed(_ t: CATransform3D, _ point: CGPoint) -> CGPoint {
    let x = t.m11 * point.x + t.m21 * point.y + t.m41
    let y = t.m12 * point.x + t.m22 * point.y + t.m42
    let w = t.m14 * point.x + t.m24 * point.y + t.m44
    return CGPoint(x: x / w, y: y / w)
}

private let liftCanvas = CGRect(x: 0, y: 0, width: 128, height: 128)

/// 拎着时整只的四角：脑袋（脖子以上）不动，身体从脖子往下拉长、收细
private func hangingCorners(stretchY: CGFloat) -> [CGPoint] {
    let neck = liftCanvas.height * PetAnimationEngine.liftedBodyShare
    let body = PetAnimationEngine.liftedBodyTransform(stretchY: stretchY)
    let halfWidth = liftCanvas.width / 2 * body.m11
    let feet = neck - neck * body.m22
    return [
        CGPoint(x: 64 - halfWidth, y: feet), CGPoint(x: 64 + halfWidth, y: feet),
        CGPoint(x: 0, y: 128), CGPoint(x: 128, y: 128),
    ]
}

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
        for corner in hangingCorners(stretchY: 1 + config.holdStretch + config.maxExtraStretch) {
            let moved = transformed(lift, corner)
            let inRoom = CGPoint(x: moved.x + canvasInRoom.minX, y: moved.y + canvasInRoom.minY)
            try expect(room.insetBy(dx: -0.5, dy: -0.5).contains(inRoom), "at \(swing)° the corner \(corner) lands at \(inRoom), outside \(room)")
        }
    }
}

func testPetLiftWindowKeepsRoomForTheLiftedPet() throws {
    let config = DragPhysicsConfig()
    let room = CGRect(origin: .zero, size: PetLiftWindow.frame(around: liftCanvas).size)
    let canvasInRoom = liftCanvas.offsetBy(dx: PetLiftWindow.sideMargin, dy: PetLiftWindow.bottomMargin)
    // 拎起窗口的头顶留白得装得下这截抬高，再加 20pt 给转起来时翘起的画布角，否则松手后脑袋被裁掉一截
    try expect(
        PetLiftWindow.topMargin >= config.liftHeight + 20,
        "the headroom above the canvas should fit the lift height (got \(PetLiftWindow.topMargin), need \(config.liftHeight))"
    )
    // 拎着和下落全程：摆角在松手瞬间还很大，但几十毫秒内就衰掉了，取衰完后的幅度查四角
    for swing in [-CGFloat(10), 0, 10] {
        let lift = PetAnimationEngine.liftedTransform(
            drag: DragOutput(
                pose: .hold(tilt: 0),
                stretchY: 1 + config.holdStretch + config.maxExtraStretch,
                swingDegrees: swing,
                landingSquash: 1,
                fallOffset: config.liftHeight
            ),
            layerBounds: liftCanvas,
            anchorPoint: .zero
        )
        for corner in hangingCorners(stretchY: 1 + config.holdStretch + config.maxExtraStretch) {
            let moved = transformed(lift, corner)
            let inRoom = CGPoint(x: moved.x + canvasInRoom.minX, y: moved.y + canvasInRoom.minY)
            try expect(room.insetBy(dx: -0.5, dy: -0.5).contains(inRoom), "lifted \(swing)° the corner \(corner) lands at \(inRoom), outside \(room)")
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
    for tilt in -2...2 {
        for twinkle in 0...1 {
            try makeColorPNG(at: petRoot.appendingPathComponent("drag/dizzy_\(tilt)_\(twinkle).png"), color: brown)
        }
    }
    // 甩晕后落地这段走的是单独一套坐姿帧；少写一张，姿势就会提前断掉、回到静止
    for twinkle in 0...1 {
        try makeColorPNG(at: petRoot.appendingPathComponent("drag/dizzy_grounded_\(twinkle).png"), color: brown)
    }
    try makeColorPNG(at: petRoot.appendingPathComponent("drag/land_0.png"), color: brown)
    try makeColorPNG(at: petRoot.appendingPathComponent("drag/land_1.png"), color: brown)
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
    try expect(lift.sprite != nil && lift.rasterLayer.contents != nil, "the hold frame is drawn in the lift window")
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

/// 一帧的实际渲染结果：姿势，加上拎起窗口 / 小窗口里这只到底可不可见
private struct DragRenderFrame {
    var time: TimeInterval
    var pose: DragPose
    var liftVisible: Bool
    var petAlpha: CGFloat
}

/// 甩 5 次换向把豚鼠甩晕，再继续拎着 `holdAfterShake` 秒才松手。
/// 逐帧推进物理，姿势一变就喂给真实的 DesktopPetView（和 PetAnimationEngine.tick 一样），
/// 记录每帧的渲染状态，用来看拎起窗口到底有没有收回去
private func dragAndReleaseTimeline(
    view: DesktopPetView,
    holdAfterShake: TimeInterval,
    secondsAfterRelease: TimeInterval
) throws -> (releasedAt: TimeInterval, frames: [DragRenderFrame]) {
    // 时间必须自己给：CACurrentMediaTime() 是巨大实数，跟这里从 0 开始的合成时间不同基准，
    // elapsed 会一直是负的，姿势卡在落地第一帧不动，看着像代码坏了
    var clock: TimeInterval = 0
    let controller = PetDragController(config: DragPhysicsConfig(), timeProvider: { clock })
    let frame: TimeInterval = 1.0 / 60
    var frames: [DragRenderFrame] = []
    var lastPose: DragPose?

    /// 推进一帧：先给控制器时间，再按姿势变化把新姿势喂给视图
    func tick(at time: TimeInterval, mouseLocation: CGPoint?) {
        clock = time
        if let mouseLocation {
            _ = controller.mouseDragged(mouseLocation: mouseLocation, keepVisible: .zero, visibleFrame: nil)
        }
        let output = controller.output(at: time)
        if output.pose != lastPose {
            lastPose = output.pose
            view.applyDragPose(output.pose)
        }
        frames.append(DragRenderFrame(
            time: time,
            pose: output.pose,
            liftVisible: view.liftWindow?.isVisible == true,
            petAlpha: view.imageView.alphaValue
        ))
    }

    controller.mouseDown(mouseLocation: .zero, windowOrigin: .zero)
    var time: TimeInterval = 0
    var point = CGPoint(x: 80, y: 0)
    // 0.8 秒内左右各甩 3 次（5 次换向），每段 80pt / 0.13s ≈ 600pt/s
    for index in 0..<6 {
        let segmentStart = time
        let from = CGPoint(x: index % 2 == 0 ? 0 : 80, y: 0)
        let to = CGPoint(x: index % 2 == 0 ? 80 : 0, y: 0)
        let steps = max(1, Int(0.13 * 60))
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            point = CGPoint(x: from.x + (to.x - from.x) * CGFloat(progress), y: 0)
            time = segmentStart + 0.13 * progress
            tick(at: time, mouseLocation: point)
        }
        time = segmentStart + 0.13
    }

    // 甩完继续拎着不动：星星熄了以后再松手就该是普通落地
    let shakeEnd = time
    while time < shakeEnd + holdAfterShake {
        time = min(shakeEnd + holdAfterShake, time + frame)
        tick(at: time, mouseLocation: point)
    }

    try expect(controller.mouseUp(), "releasing after a drag should be reported as a drag")
    let releasedAt = time
    let end = releasedAt + secondsAfterRelease
    while time < end {
        time = min(end, time + frame)
        tick(at: time, mouseLocation: nil)
    }
    return (releasedAt, frames)
}

func testDesktopPetViewStaysDizzyOnTheGroundWhenReleasedWhileSeeingStars() throws {
    let (view, window) = try makeLiftablePet()
    defer { window.close() }
    let config = DragPhysicsConfig()
    let frame: TimeInterval = 1.0 / 60

    let (releasedAt, frames) = try dragAndReleaseTimeline(
        view: view,
        holdAfterShake: 0,
        secondsAfterRelease: config.landingDuration + config.groundedDizzyDuration + config.settleDuration + 0.2
    )
    let held = frames.filter { $0.time < releasedAt }
    let after = frames.filter { $0.time > releasedAt }

    try expect(
        held.contains { if case .dizzy = $0.pose { return true }; return false },
        "hard shaking should light up the stars while held (poses \(held.map { $0.pose }))"
    )
    try expect(
        held.allSatisfy { $0.liftVisible && $0.petAlpha == 0 },
        "while held the whole pet is drawn in the lift window and the clipped one steps aside"
    )

    let groundedEnd = releasedAt + config.landingDuration + config.groundedDizzyDuration
    let fallEnd = releasedAt + config.fallDuration
    // 下落这段还拎在拎起窗口里：星星照样挂着，直到落地那一刻才换回主窗口
    try expect(
        after.filter { $0.time < fallEnd - frame }.allSatisfy { $0.liftVisible && $0.petAlpha == 0 && $0.pose.isLifted },
        "while it is still falling the pet should keep hanging in the lift window (got \(after.prefix(30).map { ($0.time, $0.pose, $0.liftVisible, $0.petAlpha) }))"
    )
    try expect(
        after.filter { $0.time > fallEnd + frame }.allSatisfy { !$0.liftVisible && $0.petAlpha == 1 && !$0.pose.isLifted },
        "once it lands the pet should go back on the ground, not hang it back up (got \(after.filter { $0.liftVisible || $0.petAlpha != 1 }))"
    )
    let firstGrounded = after.first { if case .dizzyGrounded = $0.pose { return true }; return false }
    guard let firstGrounded else {
        throw TestFailure(message: "a pet released while seeing stars should keep seeing them on the ground (got \(after.first?.pose ?? DragPose.none))")
    }
    try expect(!firstGrounded.pose.isLifted, "dizziness on the ground must not pull the pet back into the lift window")
    try expect(
        abs(firstGrounded.time - releasedAt - config.fallDuration) <= 1.5 * frame,
        "releasing while seeing stars should be dizzy on the ground from the first frame after the fall (started at \(firstGrounded.time), want \(releasedAt + config.fallDuration))"
    )
    let lastGrounded = after.last { if case .dizzyGrounded = $0.pose { return true }; return false }
    // 松手时补的晕劲儿只保证「至少」这么久：甩的过程中本来就把晕劲儿续得更久时就顺延，
    // 所以 groundedEnd 是下限而不是精确值，不能要求最后一帧正好落在它上面
    try expect(
        (lastGrounded?.time ?? 0) >= groundedEnd - 1.5 * frame,
        "grounded dizziness should last at least until the landing frame plus \(config.groundedDizzyDuration)s (last frame at \(lastGrounded?.time ?? 0), want at least \(groundedEnd))"
    )
    // 晕劲儿一结束就回待机，不拖尾（余量按帧算，顺着顺延的情况）
    let restFrom = (lastGrounded?.time ?? groundedEnd) + 2 * frame
    try expect(
        after.filter { $0.time > restFrom }.allSatisfy { $0.pose == .none },
        "once the dizziness wears off it should return to rest (got \(after.last?.pose ?? DragPose.none))"
    )
}

func testDesktopPetViewLandsNormallyWhenTheStarsAlreadyBurnedOut() throws {
    let (view, window) = try makeLiftablePet()
    defer { window.close() }
    let config = DragPhysicsConfig()
    let frame: TimeInterval = 1.0 / 60

    // 甩晕后继续拎着，等星星熄了、回到拎着的普通状态再松手
    let (releasedAt, frames) = try dragAndReleaseTimeline(
        view: view,
        holdAfterShake: config.dizzyDuration + 1.5,
        secondsAfterRelease: config.landingDuration + config.settleDuration + 0.5
    )
    let held = frames.filter { $0.time < releasedAt }
    let after = frames.filter { $0.time > releasedAt }

    try expect(
        held.contains { if case .hold = $0.pose { return true }; return false },
        "once the stars burn out it should go back to the ordinary hold pose (poses \(held.map { $0.pose }))"
    )
    try expect(held.allSatisfy { $0.liftVisible && $0.petAlpha == 0 }, "still held, so it keeps hanging in the lift window")

    try expect(
        !after.contains { if case .dizzyGrounded = $0.pose { return true }; return false },
        "the stars burned out before the release, so it should just land (got \(after.map { $0.pose }))"
    )
    // 松手后先拎着往下坠，落地那一刻才换成坐姿 + 灰尘的落地帧
    guard case .hold = after.first?.pose else {
        throw TestFailure(message: "a release without dizziness should fall first, still hanging (got \(after.first?.pose ?? DragPose.none))")
    }
    let fallEnd = releasedAt + config.fallDuration
    try expect(
        after.filter { $0.time < fallEnd - frame }.allSatisfy { $0.pose.isLifted && $0.liftVisible && $0.petAlpha == 0 },
        "the pet should keep hanging in the lift window while it falls (got \(after.prefix(30).map { ($0.time, $0.pose, $0.liftVisible, $0.petAlpha) }))"
    )
    try expect(
        after.contains { if case .landing = $0.pose { return true }; return false },
        "once it hits the ground it should play the landing pose (got \(after.map { $0.pose }))"
    )
    try expect(
        after.filter { $0.time > fallEnd + frame }.allSatisfy { !$0.pose.isLifted && !$0.liftVisible && $0.petAlpha == 1 },
        "landing should put the pet back into the normal window (got \(after.filter { $0.liftVisible || $0.petAlpha != 1 }))"
    )
    try expect(after.last?.pose == DragPose.none, "after landing it should return to rest (got \(after.last?.pose ?? DragPose.none))")
}

/// 拎起来：脑袋不被拉，只有脖子以下的身体往下坠得长、收得细（2026-11-11 用户：拉伸多一点、别圆鼓鼓、脑袋不要被拉）
func testLiftedPetStretchesTheBodyButNotTheHead() throws {
    let config = DragPhysicsConfig()
    try expect(config.holdStretch >= 0.3, "held still the body already hangs a third longer (got \(config.holdStretch))")
    let stretch = 1 + config.holdStretch
    let whole = PetAnimationEngine.liftedTransform(
        drag: DragOutput(pose: .hold(tilt: 0), stretchY: stretch, swingDegrees: 0, landingSquash: 1),
        layerBounds: liftCanvas,
        anchorPoint: CGPoint(x: 0.5, y: 0.5)
    )
    try expect(abs(whole.m11 - 1) < 0.001 && abs(whole.m22 - 1) < 0.001, "the whole pet (and so the head) is not scaled, only swung")
    let body = PetAnimationEngine.liftedBodyTransform(stretchY: stretch)
    try expect(abs(body.m22 - stretch) < 0.001, "the body is taller by the stretch (got \(body.m22))")
    try expect(body.m11 < 1 / stretch.squareRoot(), "and slimmer than a plain volume-keeping squeeze (got \(body.m11))")
    let share = PetAnimationEngine.liftedBodyShare
    try expect(share > 0.35 && share < 0.6, "the neck sits around the middle of the canvas (got \(share))")
}

// MARK: - 原像素格上的拉长和甩动

private let outline: UInt32 = 0x2A1A14FF
private let fur: UInt32 = 0xB07048FF
private let belly: UInt32 = 0xD8A070FF

/// 带一格深色描边的圆角身子（20×24 格），肚子一块浅色，像素画常见的样子
private func outlinedBlob() -> PixelSpriteGrid {
    let width = 20, height = 24
    // 上下两头每行左右各缩进几格，收成圆角
    let roundedInsets = [4, 2, 1, 1]
    func inside(_ x: Int, _ y: Int) -> Bool {
        guard y >= 0, y < height else { return false }
        let edge = min(y, height - 1 - y)
        let inset = edge < roundedInsets.count ? roundedInsets[edge] : 0
        return x >= inset && x < width - inset
    }
    let cells = (0..<height).flatMap { y in
        (0..<width).map { x -> UInt32 in
            guard inside(x, y) else { return PixelSpriteGrid.clear }
            let onEdge = !inside(x - 1, y) || !inside(x + 1, y) || !inside(x, y - 1) || !inside(x, y + 1)
            if onEdge { return outline }
            return (6...13).contains(x) && (12...20).contains(y) ? belly : fur
        }
    }
    return PixelSpriteGrid(width: width, height: height, cells: cells)
}

/// 8 邻接下有几块连通的描边
private func outlinePieces(_ grid: PixelSpriteGrid) -> Int {
    var seen = Set<Int>()
    var pieces = 0
    for start in grid.cells.indices where grid.cells[start] == outline && !seen.contains(start) {
        pieces += 1
        var stack = [start]
        seen.insert(start)
        while let next = stack.popLast() {
            let x = next % grid.width, y = next / grid.width
            for dy in -1...1 {
                for dx in -1...1 where grid[x + dx, y + dy] == outline {
                    let index = (y + dy) * grid.width + x + dx
                    if seen.insert(index).inserted { stack.append(index) }
                }
            }
        }
    }
    return pieces
}

func testPixelSpriteHangingStretchesTheBodyByWholeRowsAndKeepsTheHead() throws {
    let blob = outlinedBlob()
    let headRows = blob.height - PetLiftWindow.bodyRows(in: blob)
    let rows = PixelSpriteHanging.stretchedBodyRows(bodyRows: blob.height - headRows, stretch: 1.4)
    let hung = PixelSpriteHanging.hanging(blob, headRows: headRows, stretchedBodyRows: rows, slimming: PetAnimationEngine.liftedSlimming)
    try expect(hung.height == headRows + rows && rows > blob.height - headRows, "the body grows by whole rows (got \(rows))")
    try expect(Array(hung.cells[0..<(headRows * blob.width)]) == Array(blob.cells[0..<(headRows * blob.width)]),
               "the head is copied cell for cell")
    let neck = (0..<blob.width).map { hung[$0, headRows] }
    try expect(neck == (0..<blob.width).map { blob[$0, headRows] }, "the neck row is untouched, so the outline meets the head")
    try expect(Set(hung.cells).isSubset(of: Set(blob.cells)), "stretching never invents colors")
    let feet = hung.height - 1
    try expect((0..<blob.width).allSatisfy { hung[$0, feet] == PixelSpriteGrid.clear || hung[$0, feet] == outline },
               "the bottom outline stays one row thick")
    try expect((0..<blob.width).filter { hung[$0, feet - 1] == outline }.count < (0..<blob.width).filter { hung[$0, feet] == outline }.count,
               "the row above the feet is not a second copy of the bottom outline")
    for row in headRows..<hung.height {
        guard let span = hung.opaqueSpan(row: row) else { continue }
        try expect(hung[span.lowerBound, row] == outline && hung[span.upperBound, row] == outline,
                   "row \(row) keeps its outline on both ends")
    }
    guard let neckSpan = hung.opaqueSpan(row: headRows), let feetSpan = hung.opaqueSpan(row: feet - 1),
          let sourceFeet = blob.opaqueSpan(row: blob.height - 2) else {
        throw TestFailure(message: "the hung body should stay visible")
    }
    try expect(feetSpan.count < sourceFeet.count && neckSpan.count == blob.opaqueSpan(row: headRows)?.count,
               "only the lower body slims: neck \(neckSpan), feet \(feetSpan)")
    try expect(outlinePieces(hung) == 1, "the stretched outline is still one closed stroke")
}

func testPixelSpriteHangingSwingsWithoutBreakingTheOutline() throws {
    let blob = outlinedBlob()
    let rows = PixelSpriteHanging.stretchedBodyRows(bodyRows: PetLiftWindow.bodyRows(in: blob), stretch: 1.32)
    let hung = PixelSpriteHanging.hanging(blob, headRows: blob.height - PetLiftWindow.bodyRows(in: blob),
                                         stretchedBodyRows: rows, slimming: PetAnimationEngine.liftedSlimming)
    let smooth = PixelSpriteHanging.oversampled(hung)
    let pivot = CGPoint(x: CGFloat(blob.width) / 2, y: 0)
    let still = PixelSpriteHanging.placed(hung, oversampled: smooth, degrees: 0, pivot: pivot, origin: (10, 4), canvasWidth: 50, canvasHeight: 50)
    try expect((0..<hung.height).allSatisfy { y in (0..<hung.width).allSatisfy { still[$0 + 10, y + 4] == hung[$0, y] } },
               "at rest the hung sprite is placed cell for cell")
    for degrees in [-40, -23, -7, 3, 12, 31, 40] {
        let swung = PixelSpriteHanging.placed(hung, oversampled: smooth, degrees: degrees, pivot: pivot, origin: (10, 4), canvasWidth: 50, canvasHeight: 50)
        try expect(Set(swung.cells).isSubset(of: Set(hung.cells).union([PixelSpriteGrid.clear])), "swinging never blends colors (\(degrees)°)")
        try expect(outlinePieces(swung) == 1, "at \(degrees)° the outline is one connected stroke, without stray pixels")
        let opaque = swung.cells.filter { $0 != PixelSpriteGrid.clear }.count
        let original = hung.cells.filter { $0 != PixelSpriteGrid.clear }.count
        try expect(abs(opaque - original) * 10 < original, "at \(degrees)° the body keeps its size (\(opaque) vs \(original))")
        try expect(swung[10 + Int(pivot.x), 4] != PixelSpriteGrid.clear || swung[9 + Int(pivot.x), 4] != PixelSpriteGrid.clear,
                   "the scruff stays at the grab point at \(degrees)°")
    }
    let right = PixelSpriteHanging.placed(hung, oversampled: smooth, degrees: 30, pivot: pivot, origin: (10, 4), canvasWidth: 50, canvasHeight: 50)
    let feetRow = (0..<50).last { row in (0..<50).contains { right[$0, row] != PixelSpriteGrid.clear } } ?? 0
    let feetX = (0..<50).filter { right[$0, feetRow] != PixelSpriteGrid.clear }
    try expect((feetX.first ?? 0) > 10 + blob.width / 2, "a positive swing throws the feet to the right (\(feetX))")
}

private struct LiftRasterPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    func pixel(_ x: Int, _ y: Int) -> [UInt8] {
        let offset = (y * width + x) * 4
        return Array(bytes[offset..<(offset + 4)])
    }
}

private func liftPixelSource() -> NSImage {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    let bytes = rep.bitmapData!
    for y in 0..<256 {
        for x in 0..<256 {
            let offset = y * rep.bytesPerRow + x * 4
            let color: [UInt8] = x < 32 || x >= 224 ? [0, 0, 0, 0]
                : y >= 152 ? [0, 0, 255, 255] : x < 96 ? [0, 255, 0, 255] : [255, 0, 0, 255]
            for channel in 0..<4 { bytes[offset + channel] = color[channel] }
        }
    }
    let image = NSImage(size: NSSize(width: 128, height: 128))
    image.addRepresentation(rep)
    return image
}

/// Drive the same display-link path as dragging, including the final on-screen layer tree.
private func drawLiftFrame(_ lift: PetLiftWindow, drag: DragOutput) throws {
    let engine = PetAnimationEngine()
    let target = CALayer()
    target.bounds = liftCanvas
    engine.attachTo(layer: target)
    var ticked = false
    engine.dragOutputProvider = { _ in ticked = true; return drag }
    engine.liftedWindow = { lift }
    engine.start()
    defer { engine.stop() }
    let deadline = Date(timeIntervalSinceNow: 1)
    while !ticked && Date() < deadline {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
    try expect(ticked, "the display link should render a drag frame")
    if drag.pose.isLifted && lift.isVisible {
        try expect(CATransform3DIsIdentity(target.transform), "the small-window image must not get another lift transform")
    } else {
        let fallback = PetAnimationEngine.composedTransform(base: engine.baseTransform(at: 0), drag: drag,
                                                          layerBounds: target.bounds, anchorPoint: target.anchorPoint)
        try expect(CATransform3DEqualToTransform(target.transform, fallback), "without a visible lifted pose the original transform must remain active")
    }
}

private func liftDisplayPixels(_ lift: PetLiftWindow, scale: Int) throws -> LiftRasterPixels {
    let width = Int(lift.frame.width) * scale
    let height = Int(lift.frame.height) * scale
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
          let root = lift.contentView?.layer else {
        throw TestFailure(message: "could not capture the lift display")
    }
    context.interpolationQuality = .none
    context.setShouldAntialias(false)
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    root.render(in: context)
    let bytes = Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
    return LiftRasterPixels(width: width, height: height, bytes: bytes)
}

func testPetLiftRasterKeepsTheOriginalPixelGridWhileSwinging() throws {
    let parent = NSWindow(contentRect: liftCanvas, styleMask: [.borderless], backing: .buffered, defer: false)
    parent.isReleasedWhenClosed = false
    let lift = PetLiftWindow()
    defer { lift.hide(); lift.close(); parent.close() }
    let source = liftPixelSource()
    for right in [false, true] {
        lift.show(image: right ? PixelArtScaler.mirroredHorizontally(source) : source, canvas: liftCanvas, over: parent)
        for (stretch, swing) in [(CGFloat(1.37), CGFloat(-23)), (1.8, 31)] {
            try drawLiftFrame(lift, drag: DragOutput(pose: .hold(tilt: 0), stretchY: stretch,
                                                   swingDegrees: swing, landingSquash: 1, fallOffset: 17.3))
            for scale in [1, 2] {
                let output = try liftDisplayPixels(lift, scale: scale)
                let block = 4 * scale
                var opaque = 0
                for y in stride(from: 0, to: output.height, by: block) {
                    for x in stride(from: 0, to: output.width, by: block) {
                        let first = output.pixel(x, y)
                        try expect(first[3] == 0 || first[3] == 255, "swing edges must not blend alpha at \(x),\(y)")
                        if first[3] != 0 {
                            opaque += 1
                            try expect(first == [255, 0, 0, 255] || first == [0, 255, 0, 255] || first == [0, 0, 255, 255],
                                       "sampling must keep the source palette, got \(first)")
                        }
                        for dy in 0..<block {
                            for dx in 0..<block {
                                try expect(output.pixel(x + dx, y + dy) == first,
                                           "\(scale)x lift tore the \(block)px source block at \(x),\(y), offset \(dx),\(dy), stretch \(stretch), swing \(swing), right \(right)")
                            }
                        }
                    }
                }
                try expect(opaque > 400, "the pixel-grid check must include a visible head and stretched body")
                try expect((0..<output.width).allSatisfy { output.pixel($0, 0)[3] == 0 && output.pixel($0, output.height - 1)[3] == 0 },
                           "the first and last rows should remain clear, without clipped or torn feet")
            }
        }
    }
}

func testPetLiftRasterStretchesOnlyTheBodyAndKeepsTheNeckJoined() throws {
    let parent = NSWindow(contentRect: liftCanvas, styleMask: [.borderless], backing: .buffered, defer: false)
    parent.isReleasedWhenClosed = false
    let lift = PetLiftWindow()
    defer { lift.hide(); lift.close(); parent.close() }
    lift.show(image: liftPixelSource(), canvas: liftCanvas, over: parent)
    var headCounts: [Int] = []
    var bodySizes: [CGSize] = []
    var feetWidths: [Int] = []
    for stretch in [CGFloat(1), 1.37, 1.8] {
        try drawLiftFrame(lift, drag: DragOutput(pose: .hold(tilt: 0), stretchY: stretch, swingDegrees: 0, landingSquash: 1))
        let output = try liftDisplayPixels(lift, scale: 1)
        var headCount = 0
        var bodyPoints: [CGPoint] = []
        var centerRows: [Int] = []
        for y in 0..<output.height {
            for x in 0..<output.width {
                let pixel = output.pixel(x, y)
                if pixel[3] == 255 {
                    if pixel[2] == 255 { bodyPoints.append(CGPoint(x: x, y: y)) } else { headCount += 1 }
                    if x == output.width / 2 { centerRows.append(y) }
                }
            }
        }
        headCounts.append(headCount)
        guard let minX = bodyPoints.map(\.x).min(), let maxX = bodyPoints.map(\.x).max(),
              let minY = bodyPoints.map(\.y).min(), let maxY = bodyPoints.map(\.y).max() else {
            throw TestFailure(message: "the stretched blue body should remain visible")
        }
        bodySizes.append(CGSize(width: maxX - minX + 1, height: maxY - minY + 1))
        // 脖子那行和脑袋最下面一行一样宽：收细从脖子往下渐进，轮廓不会在脖子处错出台阶
        let rowWidth = { (row: Int, isBody: Bool) in
            (0..<output.width).filter { x in let p = output.pixel(x, row); return p[3] == 255 && (p[2] == 255) == isBody }.count
        }
        let neckRow = Int(minY), headBottomRow = Int(minY) - 1
        try expect(rowWidth(neckRow, true) == rowWidth(headBottomRow, false),
                   "the neck row must be as wide as the head above it at stretch \(stretch)")
        feetWidths.append(rowWidth(Int(maxY), true))
        try expect(Set(centerRows).count == centerRows.max()! - centerRows.min()! + 1,
                   "the head/body split must stay joined at zero swing")
    }
    try expect(Set(headCounts).count == 1 && headCounts[0] > 0, "stretch must leave the head's actual rendered area unchanged")
    try expect(bodySizes[1].height > bodySizes[0].height && bodySizes[2].height > bodySizes[1].height,
               "the actual body must get longer: \(bodySizes)")
    try expect(feetWidths[1] < feetWidths[0] && feetWidths[2] < feetWidths[1],
               "the body must taper slimmer towards the feet: \(feetWidths)")
}

func testPetLiftRasterCachesFramesAndPreservesTheLastValidImage() throws {
    let parent = NSWindow(contentRect: liftCanvas, styleMask: [.borderless], backing: .buffered, defer: false)
    parent.isReleasedWhenClosed = false
    let lift = PetLiftWindow()
    defer { lift.hide(); lift.close(); parent.close() }
    lift.show(image: liftPixelSource(), canvas: liftCanvas, over: parent)
    let drag = DragOutput(pose: .hold(tilt: 0), stretchY: 1.37, swingDegrees: -23, landingSquash: 1, fallOffset: 17.3)
    lift.render(drag: drag)
    guard let first = lift.rasterLayer.contents else { throw TestFailure(message: "lifting must produce a bitmap immediately") }
    let raster = first as! CGImage
    try expect(raster.width == 88 && raster.height == 67, "the lift is composed on the original 4pt grid")
    try expect(!lift.rasterLayer.isHidden && CATransform3DIsIdentity(lift.rasterLayer.transform),
               "only the untransformed raster should be visible")
    lift.render(drag: drag)
    try expect(lift.rasterLayer.contents as AnyObject === first as AnyObject, "identical source and drag should reuse the raster")
    lift.setImage(nil)
    try expect(lift.rasterLayer.contents as AnyObject === first as AnyObject, "a missing frame should keep the last valid raster")
    lift.setImage(PixelArtScaler.mirroredHorizontally(liftPixelSource()))
    try expect(lift.rasterLayer.contents as AnyObject !== first as AnyObject, "a changed source must invalidate the drag cache")
    let mirrored = try liftDisplayPixels(lift, scale: 1)
    lift.setImage(liftPixelSource())
    let original = try liftDisplayPixels(lift, scale: 1)
    try expect(mirrored.bytes != original.bytes, "changing direction must change the actual display pixels")
    var still = drag
    still.swingDegrees = 0
    lift.render(drag: still)
    let unswung = try liftDisplayPixels(lift, scale: 1)
    try expect(unswung.bytes != original.bytes, "swing must move the rendered pet while retaining the pixel grid")
    try drawLiftFrame(lift, drag: DragOutput(pose: .landing(frame: 0), stretchY: 1, swingDegrees: 0, landingSquash: 0.8))
    lift.hide()
    try expect(lift.parent == nil && !lift.isVisible, "hiding must detach and remove the raster window")
    try drawLiftFrame(lift, drag: drag)
}
