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
        case card
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
        /// 头顶卡片（在等你）的高度；健康提醒不在这里，在屏幕中央（见 ReminderStagePresenter）
        static let cardHeight: CGFloat = AgentWaitCardView.height
        static let cardGap: CGFloat = 8
        static let cardTopInset: CGFloat = 8
        static let statusChipMargin: CGFloat = 8
        /// Core Animation 按深度给同级图层排序：桌宠图层一旦带上 3D 变换（比如以前的悬停偏头，
        /// 前倾半边能凸出约 15pt）就会盖住状态标签。浮层固定放在更靠前的深度
        static let overlayZPosition: CGFloat = 100
    }

    static let compactContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petStageHeight
    )
    static let cardExpandedContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petStageHeight
            + LayoutMetrics.cardGap
            + LayoutMetrics.cardHeight
            + LayoutMetrics.cardTopInset
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
    var waitCardView: AgentWaitCardView!
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
    var isFacingRight = false
    /// 拎在半空时用的大画框（第一次拎起时才创建）
    var liftWindow: PetLiftWindow?
    /// 当前上屏图的原图（未镜像）与实际上屏的图
    var presentedSource: NSImage?
    var presentedImage: NSImage?
    /// 身体不透明区域（归一化、未镜像），每个形象算一次
    var normalizedBodyBounds: CGRect?
    /// 贴边探头
    var peekFrames: PetPeekFrames?
    var peekTimer: Timer?
    var peekPlayback = PetPeekPlayback.start
    var isPeeking = false
    /// 现在显示的探头帧；没在探头时为 nil
    var shownPeekFrame: PetPeekFrame?
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
    /// 按下鼠标的位置：松手时没拖动就算戳了这儿一下（见 DesktopPetView+Poke）
    var pokePressPoint: NSPoint?
    /// 被戳出了反应（哪段、是不是从右边戳的）；生气要扭过身去，朝向归窗口控制器管（贴边时不转）
    var onPokeReaction: ((PetActionClip, _ pokedFromRight: Bool) -> Void)?
    lazy var behavior = makeBehaviorCoordinator()

    var onPetDragStarted: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?

    /// 一次拖拽结束（松手）时回调，用于保存窗口位置
    var onPetDragEnded: (() -> Void)?
    /// 只放一遍的场景（干完了、出错了）放完了
    var onSceneFinished: ((PetScene) -> Void)?
    var isDraggingPet: Bool { dragController.isDragging }
    var completedVariantLoops = 0
    var variantRotationTicksRemaining = 0
    var persistentStatusText = DesktopPetCopy.statusText(for: .idle)
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
        setupWaitCard()
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
        transientBubbleContainer.clipsToBounds = true
        transientBubbleContainer.isHidden = true

        transientBubbleLabel = NSTextField(labelWithString: "")
        transientBubbleLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.transientBubbleLabel")
        transientBubbleLabel.alignment = .center
        transientBubbleLabel.lineBreakMode = .byWordWrapping
        // 行数由气泡最大高度管；真放不下，最后一行收成「…」，字不出气泡
        transientBubbleLabel.maximumNumberOfLines = 0
        transientBubbleLabel.cell?.truncatesLastVisibleLine = true
        transientBubbleLabel.clipsToBounds = true
        transientBubbleLabel.drawsBackground = false
        transientBubbleContainer.addSubview(transientBubbleLabel)

        transientBubbleTail = NSView(frame: .zero)
        transientBubbleTail.identifier = NSUserInterfaceItemIdentifier("desktopPet.transientBubbleTail")
        transientBubbleTail.wantsLayer = true
        transientBubbleTail.isHidden = true

        addOverlaySubview(transientBubbleContainer)
        addOverlaySubview(transientBubbleTail)
    }

    /// 浮在桌宠上面的东西（状态标签、气泡、在等你的卡片）：深度上永远在桌宠前面
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

    // MARK: - 拖拽传递给 window

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        layoutPetChrome()
        layoutTransientBubble()
        layoutWaitCard()
        animationEngine.layoutShadow(petCanvasBounds: petCanvasRect)
    }

    /// 窗口为头顶的卡片变高时立刻把卡片挪到桌宠上方，不等下一次布局（否则会先盖住桌宠闪一下）
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if waitCardView != nil, !waitCardView.isHidden {
            layoutWaitCard()
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

    /// 气泡里正显示的那句话；没显示气泡时为 nil
    var visibleTransientMessageForTesting: String? {
        transientBubbleContainer.isHidden ? nil : transientBubbleLabel.stringValue
    }

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
