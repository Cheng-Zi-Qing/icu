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

    private enum LayoutMetrics {
        static let petCanvasWidth: CGFloat = 128
        static let petCanvasHeight: CGFloat = 128
        static let transientBubbleMaxHeight: CGFloat = 56
        static let transientBubbleTailSize: CGFloat = 8
        static let transientBubbleGap: CGFloat = 6
        static let transientBubbleTopInset: CGFloat = 8
        static let reminderCardHeight: CGFloat = 108
        static let reminderGap: CGFloat = 8
        static let reminderTopInset: CGFloat = 8
    }

    static let compactContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petCanvasHeight
    )
    static let reminderExpandedContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petCanvasHeight
            + LayoutMetrics.reminderGap
            + LayoutMetrics.reminderCardHeight
            + LayoutMetrics.reminderTopInset
    )
    static let transientBubbleExpandedContentSize = NSSize(
        width: LayoutMetrics.petCanvasWidth,
        height: LayoutMetrics.petCanvasHeight
            + LayoutMetrics.transientBubbleGap
            + LayoutMetrics.transientBubbleTailSize
            + LayoutMetrics.transientBubbleMaxHeight
            + LayoutMetrics.transientBubbleTopInset
    )

    private var imageView: NSImageView!
    private var statusLabel: NSTextField!
    private var transientBubbleContainer: NSView!
    private var transientBubbleLabel: NSTextField!
    private var transientBubbleTail: NSView!
    private var reminderCardView: ReminderCardView!
    private var currentImage: NSImage?
    private let assetLocator: PetAssetLocator
    private let animationPlayer = PetAnimationPlayer()
    private let variantIndexProvider: (Int) -> Int
    private var petID: String
    private var currentWorkState: ShellWorkState = .idle
    private var currentAnimationStateID = "idle"
    private var currentAnimationVariant: PetAnimationDescriptor?
    private var currentAnimationFamily: [PetAnimationDescriptor] = []
    private let animationEngine = PetAnimationEngine()
    private var completedVariantLoops = 0
    private var variantRotationTicksRemaining = 0
    private var persistentStatusText = DesktopPetCopy.statusText(for: .idle)
    private var activeReminderTooltip: String?
    private var transientBubbleDismissTimer: Timer?
    private var animationTimer: DispatchSourceTimer?
    private var themeObserver: NSObjectProtocol?
    private var copyObserver: NSObjectProtocol?
    var onOverlayLayoutModeChanged: ((OverlayLayoutMode) -> Void)?

    override var mouseDownCanMoveWindow: Bool {
        true
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
        }
    ) {
        self.assetLocator = assetLocator
        self.petID = petID
        self.variantIndexProvider = variantIndexProvider
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
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        setupImageView()
        loadAnimation(for: .idle)
        setupTransientBubble()
        setupReminderCard()
        setupStatusLabel()
        applyTheme()
        subscribeToThemeChanges()
        subscribeToCopyChanges()
    }

    private func setupImageView() {
        imageView = NSImageView(frame: bounds)
        imageView.image = currentImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width]
        imageView.wantsLayer = true
        addSubview(imageView)
    }

    // 引擎在 viewDidMoveToWindow 时才 attach，确保 layer 已存在

    private func setupStatusLabel() {
        statusLabel = NSTextField(labelWithString: persistentStatusText)
        statusLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.statusLabel")
        statusLabel.frame = NSRect(x: 8, y: 8, width: bounds.width - 16, height: 18)
        statusLabel.autoresizingMask = [.width, .maxYMargin]
        addSubview(statusLabel)
    }

    private func setupTransientBubble() {
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

        addSubview(transientBubbleContainer)
        addSubview(transientBubbleTail)
    }

    private func setupReminderCard() {
        reminderCardView = ReminderCardView(frame: .zero)
        reminderCardView.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard")
        reminderCardView.isHidden = true
        addSubview(reminderCardView)
    }

    func setStatusText(_ text: String, showBubble: Bool = false) {
        persistentStatusText = text
        statusLabel.stringValue = text
        updateToolTipForVisibleContent()
        if showBubble {
            showTransientMessage(text)
        }
    }

    func setWorkState(_ state: ShellWorkState) {
        currentWorkState = state
        animationEngine.setWorkState(state)
        loadAnimation(for: state)
    }

    func setPetID(_ petID: String) {
        self.petID = petID
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
        onAction: ((HealthReminderOutcome) -> Void)? = nil
    ) {
        transientBubbleDismissTimer?.invalidate()
        hideTransientBubble(notifyLayoutChange: false)
        reminderCardView.configure(with: payload, onAction: onAction)
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

    // MARK: - Image Loading

    /// 按优先级尝试加载桌宠图片
    /// 1. `~/Library/Application Support/ICU/assets/pets/<pet_id>/...`
    /// 2. repo 内 `assets/pets/<pet_id>/...`
    /// 3. 内置占位图
    private func loadAnimation(for state: ShellWorkState) {
        cancelAnimationTimer()

        let preferredStateID = preferredAction(for: state) ?? "idle"

        if let animationFamily = assetLocator.resolveAnimationFamily(
            for: petID,
            preferredAction: preferredStateID
        ) {
            applyAnimationFamily(animationFamily)
            return
        }

        currentAnimationStateID = preferredStateID
        currentAnimationVariant = nil
        currentAnimationFamily = []
        completedVariantLoops = 0
        variantRotationTicksRemaining = 0
        animationPlayer.clear()
        print("[DesktopPetView] Asset not found, using placeholder")
        updateDisplayedImage(makePlaceholderImage())
    }

    private func updateDisplayedImage(from assetURL: URL) {
        if let image = NSImage(contentsOf: assetURL) {
            print("[DesktopPetView] Loaded image from: \(assetURL.path)")
            updateDisplayedImage(image)
            return
        }

        print("[DesktopPetView] Failed to decode image at: \(assetURL.path), using placeholder")
        updateDisplayedImage(makePlaceholderImage())
    }

    private func updateDisplayedImage(_ image: NSImage) {
        currentImage = image
        imageView?.image = image
    }

    private func scheduleAnimationIfNeeded() {
        guard
            shouldScheduleAnimationTimer,
            let frameInterval = animationPlayer.frameInterval
        else {
            return
        }

        cancelAnimationTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + frameInterval, repeating: frameInterval)
        timer.setEventHandler { [weak self] in
            self?.advanceAnimationTick()
        }
        timer.resume()
        animationTimer = timer
    }

    private func cancelAnimationTimer() {
        animationTimer?.cancel()
        animationTimer = nil
    }

    private func advanceAnimationFrame() {
        let previousFrameIndex = animationPlayer.currentFrameIndex
        guard let nextFrameURL = animationPlayer.advanceFrame() else {
            return
        }
        updateDisplayedImage(from: nextFrameURL)
        recordLoopProgress(previousFrameIndex: previousFrameIndex, newFrameIndex: animationPlayer.currentFrameIndex)
        tickVariantRotationCooldown()
    }

    private func advanceAnimationTick() {
        if animationPlayer.shouldAnimate {
            advanceAnimationFrame()
            return
        }

        tickVariantRotationCooldown()
    }

    private func applyAnimationFamily(
        _ animationFamily: [PetAnimationDescriptor],
        selectedVariantID: String? = nil
    ) {
        guard !animationFamily.isEmpty else { return }

        currentAnimationFamily = animationFamily
        currentAnimationStateID = animationFamily[0].stateID

        let animation = animationFamily.first(where: { $0.variantID == selectedVariantID }) ?? animationFamily[0]
        currentAnimationVariant = animation
        completedVariantLoops = animation.frameURLs.count <= 1 ? 1 : 0
        variantRotationTicksRemaining = 0

        guard let initialFrameURL = animationPlayer.load(animation) else {
            updateDisplayedImage(makePlaceholderImage())
            return
        }

        updateDisplayedImage(from: initialFrameURL)

        if window != nil {
            scheduleAnimationIfNeeded()
        }
    }

    private func recordLoopProgress(previousFrameIndex: Int, newFrameIndex: Int) {
        guard let currentAnimationVariant else {
            return
        }

        if currentAnimationVariant.frameURLs.count <= 1 {
            completedVariantLoops = max(completedVariantLoops, 1)
            return
        }

        let lastFrameIndex = currentAnimationVariant.frameURLs.count - 1

        if currentAnimationVariant.loopMode == .loop
            && previousFrameIndex == lastFrameIndex
            && newFrameIndex == 0 {
            completedVariantLoops += 1
        } else if currentAnimationVariant.loopMode == .once
            && previousFrameIndex < lastFrameIndex
            && newFrameIndex == lastFrameIndex {
            completedVariantLoops = max(completedVariantLoops, 1)
        }
    }

    private func tickVariantRotationCooldown() {
        guard currentAnimationFamily.count > 1 else {
            return
        }

        variantRotationTicksRemaining = max(variantRotationTicksRemaining - 1, 0)
        guard variantRotationTicksRemaining == 0 else {
            return
        }

        attemptVariantRotation(force: false)
    }

    private func attemptVariantRotation(force: Bool) {
        guard currentAnimationFamily.count > 1 else { return }
        guard force || variantRotationTicksRemaining == 0 else { return }
        guard completedVariantLoops > 0 else { return }

        let alternateAnimations = currentAnimationFamily.filter {
            $0.variantID != currentAnimationVariant?.variantID
        }
        guard !alternateAnimations.isEmpty else {
            variantRotationTicksRemaining = 5
            return
        }

        let index = max(0, min(variantIndexProvider(alternateAnimations.count), alternateAnimations.count - 1))
        applyAnimationFamily(
            currentAnimationFamily,
            selectedVariantID: alternateAnimations[index].variantID
        )
    }

    private var petCanvasRect: NSRect {
        NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: min(LayoutMetrics.petCanvasHeight, bounds.height)
        )
    }

    private var usesExpandedReminderLayout: Bool {
        bounds.height >= Self.reminderExpandedContentSize.height - 1
    }

    private var usesExpandedTransientBubbleLayout: Bool {
        bounds.height >= Self.transientBubbleExpandedContentSize.height - 1
            && bounds.height < Self.reminderExpandedContentSize.height - 1
    }

    private var currentOverlayLayoutMode: OverlayLayoutMode {
        if !reminderCardView.isHidden {
            return .reminderCard
        }
        if !transientBubbleContainer.isHidden {
            return .transientBubble
        }
        return .compact
    }

    private func notifyOverlayLayoutModeChanged() {
        onOverlayLayoutModeChanged?(currentOverlayLayoutMode)
    }

    private func layoutPetChrome() {
        guard imageView != nil, statusLabel != nil else {
            return
        }
        let petRect = petCanvasRect
        imageView.frame = petRect
        statusLabel.frame = NSRect(x: 8, y: 8, width: petRect.width - 16, height: 18)
    }

    private func layoutTransientBubble() {
        guard transientBubbleContainer != nil, transientBubbleLabel != nil else {
            return
        }

        let petRect = petCanvasRect
        let maxBubbleWidth = max(72, petRect.width - 20)
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 7
        let maxTextSize = NSSize(width: maxBubbleWidth - (horizontalPadding * 2), height: 52)
        let font = transientBubbleLabel.font ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let textRect = NSString(string: transientBubbleLabel.stringValue).boundingRect(
            with: maxTextSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let bubbleWidth = min(maxBubbleWidth, ceil(textRect.width) + (horizontalPadding * 2))
        let bubbleHeight = max(28, min(LayoutMetrics.transientBubbleMaxHeight, ceil(textRect.height) + (verticalPadding * 2)))
        let bubbleX = max(6, min(petRect.midX - (bubbleWidth / 2), petRect.width - bubbleWidth - 6))
        let bubbleY: CGFloat
        if usesExpandedTransientBubbleLayout {
            bubbleY = petRect.maxY + LayoutMetrics.transientBubbleGap + LayoutMetrics.transientBubbleTailSize
        } else {
            bubbleY = max(petRect.maxY - bubbleHeight - 12, 28)
        }

        transientBubbleContainer.frame = NSRect(
            x: bubbleX,
            y: bubbleY,
            width: bubbleWidth,
            height: bubbleHeight
        )
        transientBubbleLabel.frame = transientBubbleContainer.bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
        let tailY: CGFloat
        if usesExpandedTransientBubbleLayout {
            tailY = petRect.maxY + LayoutMetrics.transientBubbleGap
        } else {
            tailY = transientBubbleContainer.frame.minY - 6
        }
        transientBubbleTail.frame = NSRect(
            x: transientBubbleContainer.frame.midX - 4,
            y: tailY,
            width: 8,
            height: 8
        )
    }

    private func hideTransientBubble(notifyLayoutChange: Bool = true) {
        transientBubbleContainer.isHidden = true
        transientBubbleTail.isHidden = true
        if notifyLayoutChange {
            notifyOverlayLayoutModeChanged()
        }
        updateToolTipForVisibleContent()
    }

    private func layoutReminderCard() {
        let width = min(max(120, bounds.width - 12), 220)
        let height = LayoutMetrics.reminderCardHeight
        let y: CGFloat
        if usesExpandedReminderLayout {
            y = petCanvasRect.maxY + LayoutMetrics.reminderGap
        } else {
            y = max(26, bounds.height - height - 8)
        }
        reminderCardView.frame = NSRect(
            x: (bounds.width - width) / 2,
            y: y,
            width: width,
            height: height
        )
    }

    private func preferredAction(for state: ShellWorkState) -> String? {
        switch state {
        case .idle:
            return "idle"
        case .working, .focus:
            return "working"
        case .breakState:
            return "alert"
        }
    }

    /// 内置占位图：程序化绘制水豚
    private func makePlaceholderImage() -> NSImage {
        let size = NSSize(width: 128, height: 128)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let cx = rect.midX, cy = rect.midY - 4
            let bRX: CGFloat = 44, bRY: CGFloat = 32, hR: CGFloat = 32
            let cs = CGColorSpaceCreateDeviceRGB()

            // 身体
            ctx.setFillColor(NSColor(calibratedRed:0.58,green:0.48,blue:0.36,alpha:1).cgColor)
            ctx.fillEllipse(in: CGRect(x:cx-bRX,y:cy-bRY,width:bRX*2,height:bRY*2))
            // 身体渐变高光
            if let g = CGGradient(colorsSpace:cs,
                colors:[NSColor(calibratedRed:0.78,green:0.68,blue:0.52,alpha:0.55).cgColor,
                        NSColor.clear.cgColor] as CFArray, locations:[0,1]) {
                ctx.saveGState()
                ctx.addEllipse(in:CGRect(x:cx-bRX,y:cy-bRY,width:bRX*2,height:bRY*2)); ctx.clip()
                ctx.drawLinearGradient(g,start:CGPoint(x:cx,y:cy+bRY),end:CGPoint(x:cx,y:cy-bRY),options:[])
                ctx.restoreGState()
            }
            // 腹部
            ctx.setFillColor(NSColor(calibratedRed:0.82,green:0.74,blue:0.60,alpha:0.55).cgColor)
            ctx.fillEllipse(in:CGRect(x:cx-20,y:cy-24,width:40,height:34))

            // 腿
            ctx.setFillColor(NSColor(calibratedRed:0.50,green:0.40,blue:0.28,alpha:1).cgColor)
            for (lx,ly) in [(cx-26,cy-bRY+3),(cx-10,cy-bRY+1),(cx+10,cy-bRY+1),(cx+26,cy-bRY+3)] as [(CGFloat,CGFloat)] {
                ctx.fillEllipse(in:CGRect(x:lx-7,y:ly-13,width:14,height:14))
            }

            // 头
            let hCY = cy + bRY*0.5 + hR*0.55
            ctx.setFillColor(NSColor(calibratedRed:0.60,green:0.50,blue:0.38,alpha:1).cgColor)
            ctx.fillEllipse(in:CGRect(x:cx-hR,y:hCY-hR*0.85,width:hR*2,height:hR*1.7))

            // 耳朵
            for (ex,ey) in [(cx-hR*0.62,hCY+hR*0.68),(cx+hR*0.62,hCY+hR*0.68)] as [(CGFloat,CGFloat)] {
                ctx.setFillColor(NSColor(calibratedRed:0.52,green:0.42,blue:0.30,alpha:1).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-10,y:ey-7,width:20,height:16))
                ctx.setFillColor(NSColor(calibratedRed:0.88,green:0.64,blue:0.60,alpha:0.7).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-5,y:ey-3,width:10,height:8))
            }

            // 眼白→瞳孔→高光
            for ex in [cx-hR*0.36, cx+hR*0.36] as [CGFloat] {
                let ey = hCY+hR*0.10
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-8,y:ey-7,width:16,height:15))
                ctx.setFillColor(NSColor(calibratedRed:0.10,green:0.07,blue:0.04,alpha:1).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-5,y:ey-5,width:10,height:11))
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fillEllipse(in:CGRect(x:ex+1,y:ey+1,width:4,height:4))
            }

            // 鼻子
            ctx.setFillColor(NSColor(calibratedRed:0.35,green:0.25,blue:0.16,alpha:1).cgColor)
            ctx.fillEllipse(in:CGRect(x:cx-9,y:hCY-hR*0.28,width:18,height:11))
            ctx.setFillColor(NSColor(calibratedRed:0.20,green:0.12,blue:0.07,alpha:0.8).cgColor)
            for nx in [cx-3.5,cx+3.5] as [CGFloat] {
                ctx.fillEllipse(in:CGRect(x:nx-2,y:hCY-hR*0.26,width:4,height:3.5))
            }

            // 嘴
            ctx.setStrokeColor(NSColor(calibratedRed:0.28,green:0.18,blue:0.10,alpha:0.7).cgColor)
            ctx.setLineWidth(1.5); ctx.setLineCap(.round)
            ctx.move(to:CGPoint(x:cx-5,y:hCY-hR*0.42))
            ctx.addCurve(to:CGPoint(x:cx+5,y:hCY-hR*0.42),
                         control1:CGPoint(x:cx-2,y:hCY-hR*0.52),
                         control2:CGPoint(x:cx+2,y:hCY-hR*0.52))
            ctx.strokePath()

            // 毛发纹理
            ctx.setStrokeColor(NSColor(calibratedRed:0.70,green:0.58,blue:0.42,alpha:0.32).cgColor)
            ctx.setLineWidth(1.0)
            for _ in 0..<22 {
                let a = CGFloat.random(in:0...(.pi*2))
                let r = CGFloat.random(in:bRX*0.4...bRX*0.8)
                let sx = cx+cos(a)*r, sy = cy+sin(a)*r*(bRY/bRX)
                ctx.move(to:CGPoint(x:sx,y:sy))
                ctx.addLine(to:CGPoint(x:sx+cos(a)*4,y:sy+sin(a)*4))
                ctx.strokePath()
            }

            // 腮红
            ctx.setFillColor(NSColor(calibratedRed:0.95,green:0.55,blue:0.55,alpha:0.25).cgColor)
            for bx in [cx-hR*0.66, cx+hR*0.66] as [CGFloat] {
                ctx.fillEllipse(in:CGRect(x:bx-10,y:hCY-hR*0.06,width:20,height:12))
            }
            return true
        }
        return image
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

        guard let image = currentImage else { return super.hitTest(point) }
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

    private func imagePixelPoint(for point: NSPoint, image: NSImage) -> NSPoint? {
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

    private func aspectFitRect(for imageSize: NSSize, in bounds: NSRect) -> NSRect {
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
        animationEngine.handleMouseEntered()
    }

    override func mouseMoved(with event: NSEvent) {
        let localPos = convert(event.locationInWindow, from: nil)
        animationEngine.handleMouseMoved(localPosition: localPos, petBounds: petCanvasRect)
    }

    override func mouseExited(with event: NSEvent) {
        animationEngine.handleMouseExited()
    }

    override func mouseDown(with event: NSEvent) {
        animationEngine.handleMouseDown()
        if event.clickCount == 2 {
            animationEngine.handleDoubleClick()
        }
        window?.performDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        animationEngine.handleMouseUp()
    }

    override func mouseDragged(with event: NSEvent) {
        animationEngine.handleDragBegan()
        window?.performDrag(with: event)
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
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
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
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
        transientBubbleDismissTimer?.invalidate()
        animationEngine.stop()
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
        if let copyObserver {
            NotificationCenter.default.removeObserver(copyObserver)
        }
    }

    private func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    private func subscribeToCopyChanges() {
        copyObserver = NotificationCenter.default.addObserver(
            forName: .icuCopyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadPersistentStatusText()
        }
    }

    private func reloadPersistentStatusText() {
        let previousPersistentStatus = persistentStatusText
        let nextPersistentStatus = DesktopPetCopy.statusText(for: currentWorkState)
        persistentStatusText = nextPersistentStatus

        if statusLabel.stringValue == previousPersistentStatus {
            statusLabel.stringValue = nextPersistentStatus
            updateToolTipForVisibleContent()
        }
    }

    private func applyTheme() {
        guard statusLabel != nil else {
            return
        }

        let theme = ThemeManager.shared.currentTheme
        ThemedComponents.styleStatusChip(statusLabel, theme: theme)
        transientBubbleLabel.font = ThemedComponents.statusFont(theme)
        transientBubbleLabel.textColor = ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        transientBubbleContainer.layer?.backgroundColor = ThemedComponents.color(
            theme.tokens.colors.overlayHex,
            fallback: .windowBackgroundColor
        ).withAlphaComponent(0.96).cgColor
        transientBubbleContainer.layer?.cornerRadius = 6
        transientBubbleContainer.layer?.borderWidth = 1
        transientBubbleContainer.layer?.borderColor = ThemedComponents.color(
            theme.tokens.colors.borderHex,
            fallback: .separatorColor
        ).cgColor
        transientBubbleContainer.layer?.masksToBounds = true
        transientBubbleTail.layer?.backgroundColor = transientBubbleContainer.layer?.backgroundColor
        transientBubbleTail.layer?.borderWidth = 1
        transientBubbleTail.layer?.borderColor = transientBubbleContainer.layer?.borderColor
        transientBubbleTail.layer?.cornerRadius = 1
        transientBubbleTail.layer?.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 4))
        layoutTransientBubble()
        reminderCardView.applyTheme(theme)
        layoutReminderCard()
        updateToolTipForVisibleContent()
    }

    private func updateToolTipForVisibleContent() {
        if !reminderCardView.isHidden, let activeReminderTooltip {
            toolTip = activeReminderTooltip
            return
        }

        if !transientBubbleContainer.isHidden {
            toolTip = transientBubbleLabel.stringValue
            return
        }

        toolTip = persistentStatusText
    }

    private var shouldScheduleAnimationTimer: Bool {
        animationPlayer.shouldAnimate || currentAnimationFamily.count > 1
    }
}

// MARK: - NSImage alpha 采样扩展

extension NSImage {
    /// 采样图片指定坐标的 alpha 值（0.0–1.0），坐标系为图片像素坐标（左下角原点）
    func alphaValue(at point: NSPoint) -> CGFloat? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let px = Int(point.x)
        let py = Int(point.y)

        guard px >= 0, px < width, py >= 0, py < height else { return nil }

        // 仅采样 1×1 像素
        guard let context = CGContext(
            data: nil,
            width: 1, height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 将目标像素平移到 context 原点
        context.translateBy(x: CGFloat(-px), y: CGFloat(-py))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let pixel = data.load(fromByteOffset: 3, as: UInt8.self)  // alpha channel
        return CGFloat(pixel) / 255.0
    }
}
