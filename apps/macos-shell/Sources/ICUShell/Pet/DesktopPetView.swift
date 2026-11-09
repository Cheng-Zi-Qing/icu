import AppKit
import QuartzCore

/// 桌宠主视图
///
/// 职责：
/// - 加载并展示桌宠图片（PNG，保留透明通道）
/// - 透明区域不响应点击（点击穿透到桌面）
/// - 鼠标事件路由给 PetAnimationEngine
/// - 拖拽事件传递给父 window
class DesktopPetView: NSView {
    enum OverlayLayoutMode {
        case compact
        case transientBubble
        case reminderCard
    }

    enum LayoutMetrics {
        static let petCanvasWidth: CGFloat = 128
        static let petCanvasHeight: CGFloat = 128
        /// 形象上方的留白：悬停放大、点击弹跳时头顶的柚子不会被窗口裁掉
        static let petHeadroom: CGFloat = 24
        static let petStageHeight: CGFloat = petCanvasHeight + petHeadroom
        static let transientBubbleMaxHeight: CGFloat = 56
        static let transientBubbleTailSize: CGFloat = 8
        static let transientBubbleGap: CGFloat = 6
        static let transientBubbleTopInset: CGFloat = 8
        static let reminderCardHeight: CGFloat = ReminderCardView.maximumHeight
        static let reminderGap: CGFloat = 8
        static let reminderTopInset: CGFloat = 8
        static let statusChipMargin: CGFloat = 8
        /// Core Animation 按深度给同级图层排序：桌宠图层一旦带上 3D 变换（比如以前的悬停偏头，
        /// 前倾半边能凸出约 15pt）就会盖住状态标签。浮层固定放在更靠前的深度
        static let overlayZPosition: CGFloat = 100
    }

    static let compactContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petStageHeight
    )
    static let reminderExpandedContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petStageHeight
            + LayoutMetrics.reminderGap
            + LayoutMetrics.reminderCardHeight
            + LayoutMetrics.reminderTopInset
    )
    static let transientBubbleExpandedContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petStageHeight
            + LayoutMetrics.transientBubbleGap
            + LayoutMetrics.transientBubbleTailSize
            + LayoutMetrics.transientBubbleMaxHeight
            + LayoutMetrics.transientBubbleTopInset
    )

    var imageView: NSImageView!
    var statusLabel: NSTextField!
    /// 主题指定的状态字体；实际显示时按文字内容可能换成能显示中文的字体
    var statusChipThemeFont: NSFont?
    var transientBubbleContainer: NSView!
    var transientBubbleLabel: NSTextField!
    var transientBubbleTail: NSView!
    var reminderCardView: ReminderCardView!
    var currentImage: NSImage?
    let assetLocator: PetAssetLocator
    let animationPlayer = PetAnimationPlayer()
    let variantIndexProvider: (Int) -> Int
    var petID: String
    /// 衣柜里换的装（头顶那件对应的整套帧，`outfits/<id>/`）；nil = 默认的橙子
    private(set) var outfitID: String?
    var currentWorkState: ShellWorkState = .idle
    var currentAnimationStateID = "idle"
    var currentAnimationVariant: PetAnimationDescriptor?
    var currentAnimationFamily: [PetAnimationDescriptor] = []
    /// 当前动画家族放大后的帧：每帧的 URL 固定，读盘解码 + 像素放大只做一次
    var frameImageCache: [URL: NSImage] = [:]
    let animationEngine = PetAnimationEngine()
    let dragController = PetDragController()
    var poseSprites: PetPoseSprites?
    var isShowingDragPose = false
    /// 贴左边时镜像，让脸朝屏幕里
    private(set) var isFacingRight = false
    /// 拎在半空时用的大画框（第一次拎起时才创建）
    private(set) var liftWindow: PetLiftWindow?
    /// 当前上屏图的原图（未镜像）与实际上屏的图
    var presentedSource: NSImage?
    var presentedImage: NSImage?
    /// 身体不透明区域（归一化、未镜像），每个形象算一次
    var normalizedBodyBounds: CGRect?
    /// 贴边探头
    var peekFrames: PetPeekFrames?
    var peekTimer: Timer?
    var peekPlayback = PetPeekPlayback.start
    private(set) var isPeeking = false
    /// 现在显示的探头帧；没在探头时为 nil
    private(set) var shownPeekFrame: PetPeekFrame?
    /// 鼠标是否在形象不透明的像素上（透明区域不算，避免靠近屏幕边就误触发探出来）
    var isPointerOverPet = false
    /// 摸头 / 打盹 / 待机小动作的逐帧片段（盖在待机动画上，让位给拖拽和探头）
    var actionSprites: [String: PetPoseSprites] = [:]
    var actionImage: NSImage?
    /// Agent 干活小场景当前那一帧（见 DesktopPetView+Work）
    var workImage: NSImage?
    lazy var workPlayer = makeWorkPlayer()
    /// 像素手型光标（见 DesktopPetView+Cursor）
    var cursorSet = PetCursorSet(directory: nil)
    var currentCursorKind: PetCursorKind?
    /// 「后台改光标」开关：只在鼠标在豚鼠身上时打开（见 BackgroundCursorGate）
    let cursorGate: BackgroundCursorGate
    /// 鼠标真正在屏幕上的位置（测试里换掉）；用来识别 AppKit 补发的过期鼠标事件
    var pointerLocation: () -> CGPoint = { NSEvent.mouseLocation }
    var isPressingPet = false
    lazy var behavior = makeBehaviorCoordinator()

    var onPetDragStarted: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?

    /// 一次拖拽结束（松手）时回调，用于保存窗口位置
    var onPetDragEnded: (() -> Void)?
    var isDraggingPet: Bool { dragController.isDragging }
    var completedVariantLoops = 0
    var variantRotationTicksRemaining = 0
    var persistentStatusText = DesktopPetCopy.statusText(for: .idle)
    var activeReminderTooltip: String?
    var transientBubbleDismissTimer: Timer?
    var animationTimer: DispatchSourceTimer?
    var themeObserver: NSObjectProtocol?
    var copyObserver: NSObjectProtocol?
    var onOverlayLayoutModeChanged: ((OverlayLayoutMode) -> Void)?

    // 窗口移动由 mouseDragged 自己处理，不让系统接管
    override var mouseDownCanMoveWindow: Bool {
        false
    }

    // MARK: - Init

    init(
        frame frameRect: NSRect,
        assetLocator: PetAssetLocator = PetAssetLocator(),
        petID: String = ProcessInfo.processInfo.environment["ICU_PET_ID"] ?? "capybara",
        variantIndexProvider: @escaping (Int) -> Int = { upperBound in
            guard upperBound > 0 else {
                return 0
            }
            return Int.random(in: 0..<upperBound)
        },
        cursorGate: BackgroundCursorGate = .shared
    ) {
        self.assetLocator = assetLocator
        self.petID = petID
        self.variantIndexProvider = variantIndexProvider
        self.cursorGate = cursorGate
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        self.assetLocator = PetAssetLocator()
        self.petID = ProcessInfo.processInfo.environment["ICU_PET_ID"] ?? "capybara"
        self.variantIndexProvider = { upperBound in
            guard upperBound > 0 else {
                return 0
            }
            return Int.random(in: 0..<upperBound)
        }
        self.cursorGate = .shared
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        setupImageView()
        configureDragEffects()
        // 打盹要一直留意用户在不在，不能等到第一次鼠标经过才开始
        _ = behavior
        loadAnimation(for: .idle)
        setupTransientBubble()
        setupReminderCard()
        setupStatusLabel()
        applyTheme()
        subscribeToThemeChanges()
        subscribeToCopyChanges()
    }

    func setupImageView() {
        imageView = NSImageView(frame: bounds)
        imageView.image = currentImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width]
        imageView.wantsLayer = true
        addSubview(imageView)
    }

    // 引擎在 viewDidMoveToWindow 时才 attach，确保 layer 已存在

    func setupStatusLabel() {
        statusLabel = NSTextField(labelWithString: persistentStatusText)
        let cell = StatusChipCell(textCell: persistentStatusText)
        cell.isEditable = false
        cell.isSelectable = false
        cell.isBordered = false
        cell.lineBreakMode = .byTruncatingTail
        cell.alignment = .center
        statusLabel.cell = cell
        statusLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.statusLabel")
        statusLabel.autoresizingMask = [.maxYMargin]
        addOverlaySubview(statusLabel)
        layoutStatusChip()
    }

    func setupTransientBubble() {
        transientBubbleContainer = NSView(frame: .zero)
        transientBubbleContainer.identifier = NSUserInterfaceItemIdentifier("desktopPet.transientBubbleContainer")
        transientBubbleContainer.wantsLayer = true
        transientBubbleContainer.isHidden = true

        transientBubbleLabel = NSTextField(labelWithString: "")
        transientBubbleLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.transientBubbleLabel")
        transientBubbleLabel.alignment = .center
        transientBubbleLabel.lineBreakMode = .byWordWrapping
        transientBubbleLabel.maximumNumberOfLines = 2
        transientBubbleLabel.drawsBackground = false
        transientBubbleContainer.addSubview(transientBubbleLabel)

        transientBubbleTail = NSView(frame: .zero)
        transientBubbleTail.identifier = NSUserInterfaceItemIdentifier("desktopPet.transientBubbleTail")
        transientBubbleTail.wantsLayer = true
        transientBubbleTail.isHidden = true

        addOverlaySubview(transientBubbleContainer)
        addOverlaySubview(transientBubbleTail)
    }

    func setupReminderCard() {
        reminderCardView = ReminderCardView(frame: .zero)
        reminderCardView.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard")
        reminderCardView.isHidden = true
        addOverlaySubview(reminderCardView)
    }

    /// 浮在桌宠上面的东西（状态标签、气泡、提醒卡片）：深度上永远在桌宠前面
    func addOverlaySubview(_ overlay: NSView) {
        overlay.wantsLayer = true
        overlay.layer?.zPosition = LayoutMetrics.overlayZPosition
        addSubview(overlay)
    }

    func setStatusText(_ text: String, showBubble: Bool = false) {
        guard text != persistentStatusText || text != statusLabel.stringValue || showBubble else { return }
        persistentStatusText = text
        statusLabel.stringValue = text
        layoutStatusChip()
        updateToolTipForVisibleContent()
        if showBubble {
            showTransientMessage(text)
        }
    }

    func setWorkState(_ state: ShellWorkState) {
        currentWorkState = state
        loadAnimation(for: state)
    }

    func setPetID(_ petID: String) {
        self.petID = petID
        normalizedBodyBounds = nil
        reloadPoseSprites()
        // 新形象没有探头图：退回正常形象
        if isPeeking && peekFrames == nil {
            setEdgePeek(false)
        }
        setWorkState(currentWorkState)
    }

    /// 换装：换一整套帧；正在贴边探头就接着探头，只是换成新衣服的那一帧
    func setOutfit(_ outfit: String?) {
        guard outfit != outfitID else { return }
        outfitID = outfit
        normalizedBodyBounds = nil
        reloadPoseSprites()
        if isPeeking {
            if peekFrames == nil {
                setEdgePeek(false)
            } else {
                showPeekFrame(peekPlayback.frame)
            }
        }
        setWorkState(currentWorkState)
    }

    func showTransientMessage(_ text: String, duration: TimeInterval = 3) {
        activeReminderTooltip = nil
        reminderCardView.isHidden = true
        transientBubbleDismissTimer?.invalidate()
        transientBubbleLabel.stringValue = text
        layoutTransientBubble()
        transientBubbleContainer.isHidden = false
        transientBubbleTail.isHidden = false
        notifyOverlayLayoutModeChanged()
        updateToolTipForVisibleContent()

        let timer = Timer(
            timeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            self?.hideTransientBubble()
        }
        transientBubbleDismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func showReminderCard(_ payload: ReminderPresentationPayload) {
        showReminderCard(payload, onAction: nil)
    }

    func showReminderCard(
        _ payload: ReminderPresentationPayload,
        cups: CupProgress? = nil,
        onAction: ((HealthReminderOutcome) -> Void)? = nil
    ) {
        transientBubbleDismissTimer?.invalidate()
        hideTransientBubble(notifyLayoutChange: false)
        reminderCardView.configure(with: payload, cups: cups, onAction: onAction)
        activeReminderTooltip = payload.text
        layoutReminderCard()
        reminderCardView.isHidden = false
        notifyOverlayLayoutModeChanged()
        updateToolTipForVisibleContent()
    }

    func dismissReminderCard() {
        activeReminderTooltip = nil
        reminderCardView.isHidden = true
        notifyOverlayLayoutModeChanged()
        updateToolTipForVisibleContent()
    }

    // MARK: - 摸头与打盹

    /// 能不能转头看鼠标：探头、被拎着、正在打盹 / 被摸头时都不转
    var canTurnTowardCursor: Bool {
        !isPeeking && !isDraggingPet && behavior.activeClip == nil && workPlayer.activity == nil
    }

    /// 没有拖拽 / 探头时该显示的画面：Agent 干活小场景 > 摸头打盹片段 > 待机动画帧
    var restingImage: NSImage? {
        workImage ?? actionImage ?? currentImage
    }

    func makeBehaviorCoordinator() -> PetBehaviorCoordinator {
        let coordinator = PetBehaviorCoordinator(sprites: { [weak self] clip in
            self?.actionSprites[clip.directory]
        })
        coordinator.isAvailable = { [weak self] in
            guard let self else { return false }
            return !self.isPeeking && !self.dragController.isDragging && self.currentOverlayLayoutMode == .compact
                && self.workPlayer.activity == nil
        }
        coordinator.onImageChanged = { [weak self] image in
            self?.applyActionImage(image)
        }
        return coordinator
    }

    func applyActionImage(_ image: NSImage?) {
        actionImage = image
        guard !isShowingDragPose && !isPeeking else { return }
        present(restingImage)
    }

    /// 头 = 身体上半截（侧面坐姿时头和柚子都在这里，朝左朝右都一样）
    func isOverHead(_ point: NSPoint) -> Bool {
        guard let body = petBodyRect, body.contains(point) else { return false }
        return point.y >= body.minY + body.height * 0.45
    }

    // MARK: - 朝向与身体轮廓（贴边用）

    func setFacingRight(_ facingRight: Bool) {
        guard facingRight != isFacingRight else { return }
        isFacingRight = facingRight
        present(presentedSource)
        layoutStatusChip()
    }

    var hasPeekPose: Bool { peekFrames != nil }

    /// 切换贴边探头形象（藏边时由贴边控制器调用）
    func setEdgePeek(_ active: Bool) {
        guard active != isPeeking else { return }
        peekTimer?.invalidate()
        peekTimer = nil
        guard active, peekFrames != nil else {
            isPeeking = false
            shownPeekFrame = nil
            statusLabel.isHidden = false
            present(restingImage)
            return
        }

        isPeeking = true
        // 只探出半个脑袋时，下面的状态标签会被屏幕边截断，先藏起来
        statusLabel.isHidden = true
        peekPlayback = .start
        showPeekFrame(peekPlayback.frame)
        let timer = Timer(timeInterval: 1 / PetPeekFrames.framesPerSecond, repeats: true) { [weak self] _ in
            guard let self, self.isPeeking else { return }
            self.peekPlayback = self.peekPlayback.advanced(roll: Double.random(in: 0..<1))
            self.showPeekFrame(self.peekPlayback.frame)
        }
        RunLoop.main.add(timer, forMode: .common)
        peekTimer = timer
    }

    /// 探着头被碰到：停下待机循环，定在吓一跳那一帧，等贴边控制器把它缩回去
    func flinchPeek() {
        guard isPeeking else { return }
        peekTimer?.invalidate()
        peekTimer = nil
        showPeekFrame(.flinch)
    }

    private func showPeekFrame(_ frame: PetPeekFrame) {
        shownPeekFrame = frame
        present(peekFrames?.image(for: frame))
    }

    /// 身体在视图（= 窗口）里的矩形；还没加载出图时为 nil
    var petBodyRect: CGRect? {
        let normalizedBounds = isPeeking ? peekFrames?.normalizedBounds : normalizedBodyBounds
        guard let normalized = normalizedBounds, let image = currentImage else { return nil }
        return EdgeDockLayout.bodyRect(
            normalizedBounds: normalized,
            facingRight: isFacingRight,
            in: aspectFitRect(for: image.size, in: petCanvasRect)
        )
    }

    /// 拖拽时必须留在屏幕内的部分：身体，加上正在显示的气泡 / 提醒卡片
    var dragKeepVisibleRect: CGRect {
        let body = petBodyRect ?? petCanvasRect
        guard currentOverlayLayoutMode != .compact else { return body }
        return body.union(CGRect(x: body.minX, y: body.minY, width: body.width, height: bounds.height - body.minY))
    }

    // MARK: - Drag Effects

    func configureDragEffects() {
        reloadPoseSprites()
        animationEngine.dragOutputProvider = { [weak self] time in
            self?.dragController.output(at: time) ?? .rest
        }
        animationEngine.onDragPoseChanged = { [weak self] pose in
            self?.applyDragPose(pose)
        }
        animationEngine.liftedLayer = { [weak self] in
            guard let lift = self?.liftWindow, lift.isVisible else { return nil }
            return lift.spriteLayer
        }
    }

    func reloadPoseSprites() {
        poseSprites = assetLocator.resolvePoseSpriteDirectory(for: petID, outfit: outfitID).map {
            PetPoseSprites(directory: $0, canvasPointSize: Self.compactContentSize)
        }
        let actionDirectories = Set(PetActionClip.allCases.map(\.directory))
        cursorSet = PetCursorSet(directory: assetLocator.resolvePoseSpriteDirectory(for: petID, subdirectory: "cursor", outfit: outfitID))
        workPlayer.reload(scenes: PetWorkScenes(
            directory: assetLocator.resolvePoseSpriteDirectory(for: petID, subdirectory: "work", outfit: outfitID),
            canvasPointSize: Self.compactContentSize
        ))
        actionSprites = Dictionary(uniqueKeysWithValues: actionDirectories.compactMap { name in
            assetLocator.resolvePoseSpriteDirectory(for: petID, subdirectory: name, outfit: outfitID).map {
                (name, PetPoseSprites(directory: $0, canvasPointSize: Self.compactContentSize))
            }
        })
        peekFrames = PetPeekFrames(sprites: assetLocator.resolvePoseSpriteDirectory(for: petID, subdirectory: "edge", outfit: outfitID).map {
            PetPoseSprites(directory: $0, canvasPointSize: Self.compactContentSize)
        })
    }

    func applyDragPose(_ pose: DragPose) {
        if let image = poseSprites?.image(for: isFacingRight ? pose.mirrored : pose) {
            isShowingDragPose = true
            present(image)
            if pose.isLifted { showLift() } else { hideLift() }
            return
        }
        hideLift()
        // 姿势结束，或该宠物没有对应姿势帧：回到当前动画帧
        guard isShowingDragPose else { return }
        isShowingDragPose = false
        present(restingImage)
    }

    /// 拎起来：换到四周留足地方的拎起窗口里画，原窗口里的这只先让开
    private func showLift() {
        guard let window, imageView != nil else { return }
        let canvas = window.convertToScreen(convert(imageView.frame, to: nil))
        let lift = liftWindow ?? PetLiftWindow()
        liftWindow = lift
        lift.show(image: presentedImage, canvas: canvas, over: window)
        imageView.alphaValue = 0
    }

    func hideLift() {
        liftWindow?.hide()
        imageView?.alphaValue = 1
    }

    // MARK: - 透明区域点击穿透

    /// 透明像素（alpha ≈ 0）不响应鼠标事件，点击可穿透到桌面
    override func hitTest(_ point: NSPoint) -> NSView? {
        if !reminderCardView.isHidden {
            let reminderPoint = convert(point, to: reminderCardView)
            if reminderCardView.bounds.contains(reminderPoint) {
                return reminderCardView.interactiveHitView(at: reminderPoint) ?? reminderCardView
            }
        }

        let fallbackHitView = super.hitTest(point)
        if
            fallbackHitView === statusLabel
                || fallbackHitView === transientBubbleContainer
                || fallbackHitView === transientBubbleLabel
                || fallbackHitView === transientBubbleTail
        {
            return self
        }

        guard let image = presentedImage ?? currentImage else { return super.hitTest(point) }
        guard let imagePoint = imagePixelPoint(for: point, image: image) else {
            return nil
        }

        // 采样该像素的 alpha 值
        if let alpha = image.alphaValue(at: imagePoint), alpha < 0.1 {
            return nil  // 透明区域穿透
        }

        if fallbackHitView === imageView || fallbackHitView === self {
            return self
        }

        return fallbackHitView
    }

    func imagePixelPoint(for point: NSPoint, image: NSImage) -> NSPoint? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let drawRect = aspectFitRect(for: image.size, in: petCanvasRect)
        guard drawRect.width > 0, drawRect.height > 0, drawRect.contains(point) else {
            return nil
        }

        let normalizedX = (point.x - drawRect.minX) / drawRect.width
        let normalizedY = (point.y - drawRect.minY) / drawRect.height
        return NSPoint(
            x: normalizedX * CGFloat(cgImage.width),
            y: normalizedY * CGFloat(cgImage.height)
        )
    }

    func aspectFitRect(for imageSize: NSSize, in bounds: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let scale = min(widthScale, heightScale)
        let drawSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - (drawSize.width / 2),
            y: bounds.midY - (drawSize.height / 2),
            width: drawSize.width,
            height: drawSize.height
        )
    }

    // MARK: - 鼠标事件 —— 路由给 AnimationEngine

    override func mouseEntered(with event: NSEvent) {
        let localPos = convert(event.locationInWindow, from: nil)
        updatePointerOverPet(at: localPos)
        updateCursor(at: localPos)
    }

    override func mouseMoved(with event: NSEvent) {
        let localPos = convert(event.locationInWindow, from: nil)
        behavior.pointerMoved(x: localPos.x, overHead: isOverHead(localPos))
        updatePointerOverPet(at: localPos)
        updateCursor(at: localPos)
    }

    override func mouseExited(with event: NSEvent) {
        behavior.pointerExited()
        updatePointerOverPet(at: nil)
        updateCursor(at: nil)
    }

    func updatePointerOverPet(at point: NSPoint?) {
        let isOver = point.map(isOpaquePetPixel(at:)) ?? false
        guard isOver != isPointerOverPet else { return }
        isPointerOverPet = isOver
        if isOver {
            onPointerEntered?()
        } else {
            onPointerExited?()
        }
    }

    func isOpaquePetPixel(at point: NSPoint) -> Bool {
        guard
            let image = presentedImage ?? currentImage,
            let imagePoint = imagePixelPoint(for: point, image: image),
            let alpha = image.alphaValue(at: imagePoint)
        else {
            return false
        }
        return alpha >= 0.1
    }

    override func mouseDown(with event: NSEvent) {
        isPressingPet = true
        updateCursor(at: convert(event.locationInWindow, from: nil))
        animationEngine.handleMouseDown()
        if event.clickCount == 2 {
            animationEngine.handleDoubleClick()
        }
        dragController.mouseDown(
            mouseLocation: NSEvent.mouseLocation,
            windowOrigin: window?.frame.origin ?? .zero
        )
    }

    override func mouseUp(with event: NSEvent) {
        isPressingPet = false
        if dragController.mouseUp() {
            onPetDragEnded?()
        }
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }

    // 自己移动窗口（不用 performDrag），这样每次移动都能拿到速度驱动拖拽效果
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let wasDragging = dragController.isDragging
        guard let origin = dragController.mouseDragged(
            mouseLocation: mouseLocation,
            keepVisible: dragKeepVisibleRect,
            visibleFrame: PetDragController.visibleFrame(containing: mouseLocation)
        ) else {
            return
        }
        if !wasDragging {
            onPetDragStarted?()
        }
        window.setFrameOrigin(origin)
    }

    // MARK: - 拖拽传递给 window

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        layoutPetChrome()
        layoutTransientBubble()
        layoutReminderCard()
        animationEngine.layoutShadow(petCanvasBounds: petCanvasRect)
    }

    /// 窗口为提醒卡变高时立刻把卡片挪到桌宠上方，不等下一次布局（否则会先盖住桌宠闪一下）
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if reminderCardView != nil, !reminderCardView.isHidden {
            layoutReminderCard()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            hideLift()
            cancelAnimationTimer()
            animationEngine.stop()
        } else {
            // 延迟 attach，确保 layer 已创建
            imageView.wantsLayer = true
            if let targetLayer = imageView.layer {
                animationEngine.attachTo(layer: targetLayer)
            }
            if animationEngine.groundShadowLayer.superlayer == nil {
                layer?.insertSublayer(animationEngine.groundShadowLayer, below: imageView.layer)
            }
            scheduleAnimationIfNeeded()
            animationEngine.start()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            // 桌宠常驻在别的 App 之上，不是 key window 时也要能感知鼠标（藏边后探出来）
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    var activeActionClipForTesting: PetActionClip? { behavior.activeClip }

    func advanceAnimationFrameForTesting() {
        advanceAnimationFrame()
    }

    func advanceAnimationTickForTesting() {
        advanceAnimationTick()
    }

    func triggerVariantRotationForTesting() {
        attemptVariantRotation(force: true)
    }

    var currentFrameIndexForTesting: Int {
        animationPlayer.currentFrameIndex
    }

    var currentAnimationStateIDForTesting: String {
        currentAnimationStateID
    }

    var currentVariantIDForTesting: String {
        currentAnimationVariant?.variantID ?? ""
    }

    deinit {
        cancelAnimationTimer()
        peekTimer?.invalidate()
        transientBubbleDismissTimer?.invalidate()
        animationEngine.stop()
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let copyObserver {
            NotificationCenter.default.removeObserver(copyObserver)
        }
    }

}
