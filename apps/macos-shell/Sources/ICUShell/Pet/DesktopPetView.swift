import AppKit

/// 桌宠主视图 —— Spike 1.0
///
/// 职责：
/// - 加载并展示桌宠图片（PNG，保留透明通道）
/// - 透明区域不响应点击（点击穿透到桌面）
/// - 拖拽事件传递给父 window
class DesktopPetView: NSView {

    private var imageView: NSImageView!
    private var statusLabel: NSTextField!
    private var transientBubbleContainer: NSView!
    private var transientBubbleLabel: NSTextField!
    private var transientBubbleTail: NSView!
    private var currentImage: NSImage?
    private let assetLocator: PetAssetLocator
    private let animationPlayer = PetAnimationPlayer()
    private let variantIndexProvider: (Int) -> Int
    private var petID: String
    private var currentWorkState: ShellWorkState = .idle
    private var currentAnimationStateID = "idle"
    private var currentAnimationVariant: PetAnimationDescriptor?
    private var currentAnimationFamily: [PetAnimationDescriptor] = []
    private var currentMotionProfile = PetMotionEnhancer.profile(for: "idle")
    private var completedVariantLoops = 0
    private var variantRotationTicksRemaining = 0
    private var persistentStatusText = DesktopPetCopy.statusText(for: .idle)
    private var transientBubbleDismissTimer: Timer?
    private var animationTimer: DispatchSourceTimer?
    private var themeObserver: NSObjectProtocol?
    private var copyObserver: NSObjectProtocol?

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
        setupStatusLabel()
        applyTheme()
        subscribeToThemeChanges()
        subscribeToCopyChanges()
    }

    private func setupImageView() {
        imageView = NSImageView(frame: bounds)
        imageView.image = currentImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        addSubview(imageView)
    }

    private func setupStatusLabel() {
        statusLabel = NSTextField(labelWithString: persistentStatusText)
        statusLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.statusLabel")
        statusLabel.frame = NSRect(x: 8, y: 8, width: bounds.width - 16, height: 18)
        statusLabel.autoresizingMask = [.width, .minYMargin]
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

    func setStatusText(_ text: String, showBubble: Bool = false) {
        persistentStatusText = text
        statusLabel.stringValue = text
        toolTip = text
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
        setWorkState(currentWorkState)
    }

    func showTransientMessage(_ text: String, duration: TimeInterval = 3) {
        transientBubbleDismissTimer?.invalidate()
        transientBubbleLabel.stringValue = text
        layoutTransientBubble()
        transientBubbleContainer.isHidden = false
        transientBubbleTail.isHidden = false
        toolTip = text

        let timer = Timer(
            timeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            self?.hideTransientBubble()
        }
        transientBubbleDismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Image Loading

    /// 按优先级尝试加载桌宠图片
    /// 1. `~/Library/Application Support/ICU/assets/pets/<pet_id>/...`
    /// 2. repo 内 `assets/pets/<pet_id>/...`
    /// 3. 内置占位图
    private func loadAnimation(for state: ShellWorkState) {
        cancelAnimationTimer()

        let preferredStateID = preferredAction(for: state) ?? "idle"
        currentMotionProfile = PetMotionEnhancer.profile(for: preferredStateID)

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
        variantRotationTicksRemaining = currentMotionProfile.variantRotationCooldownTicks
        animationPlayer.clear()
        print("[DesktopPetView] Asset not found, using placeholder")
        updateDisplayedImage(makePlaceholderImage())
        applyMotionProfile()
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
        guard !animationFamily.isEmpty else {
            return
        }

        currentAnimationFamily = animationFamily
        currentAnimationStateID = animationFamily[0].stateID
        currentMotionProfile = PetMotionEnhancer.profile(for: currentAnimationStateID)

        let animation = animationFamily.first(where: { $0.variantID == selectedVariantID }) ?? animationFamily[0]
        currentAnimationVariant = animation
        completedVariantLoops = animation.frameURLs.count <= 1 ? 1 : 0
        variantRotationTicksRemaining = currentMotionProfile.variantRotationCooldownTicks

        guard let initialFrameURL = animationPlayer.load(animation) else {
            updateDisplayedImage(makePlaceholderImage())
            applyMotionProfile()
            return
        }

        updateDisplayedImage(from: initialFrameURL)
        applyMotionProfile()

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
        guard currentAnimationFamily.count > 1 else {
            return
        }
        guard force || variantRotationTicksRemaining == 0 else {
            return
        }
        guard completedVariantLoops > 0 else {
            return
        }

        let alternateAnimations = currentAnimationFamily.filter {
            $0.variantID != currentAnimationVariant?.variantID
        }
        guard !alternateAnimations.isEmpty else {
            variantRotationTicksRemaining = currentMotionProfile.variantRotationCooldownTicks
            return
        }

        let index = max(0, min(variantIndexProvider(alternateAnimations.count), alternateAnimations.count - 1))
        applyAnimationFamily(
            currentAnimationFamily,
            selectedVariantID: alternateAnimations[index].variantID
        )
    }

    private func applyMotionProfile() {
        PetMotionEnhancer.apply(currentMotionProfile, to: imageView)
    }

    private func layoutTransientBubble() {
        guard transientBubbleContainer != nil, transientBubbleLabel != nil else {
            return
        }

        let maxBubbleWidth = max(72, bounds.width - 20)
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
        let bubbleHeight = max(28, min(56, ceil(textRect.height) + (verticalPadding * 2)))
        let bubbleX = max(6, min(bounds.midX - (bubbleWidth / 2), bounds.width - bubbleWidth - 6))
        let bubbleY = max(bounds.height - bubbleHeight - 12, 28)

        transientBubbleContainer.frame = NSRect(
            x: bubbleX,
            y: bubbleY,
            width: bubbleWidth,
            height: bubbleHeight
        )
        transientBubbleLabel.frame = transientBubbleContainer.bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
        transientBubbleTail.frame = NSRect(
            x: transientBubbleContainer.frame.midX - 4,
            y: transientBubbleContainer.frame.minY - 6,
            width: 8,
            height: 8
        )
    }

    private func hideTransientBubble() {
        transientBubbleContainer.isHidden = true
        transientBubbleTail.isHidden = true
        toolTip = persistentStatusText
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

    /// 内置占位图：64×64 蓝色半透明圆形
    private func makePlaceholderImage() -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.withAlphaComponent(0.8).setFill()
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        path.fill()
        // 绘制 "?" 文字提示
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.boldSystemFont(ofSize: 24)
        ]
        "?".draw(at: NSPoint(x: 22, y: 18), withAttributes: attrs)
        image.unlockFocus()
        return image
    }

    // MARK: - 透明区域点击穿透

    /// 透明像素（alpha ≈ 0）不响应鼠标事件，点击可穿透到桌面
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let image = currentImage else { return super.hitTest(point) }
        guard let imagePoint = imagePixelPoint(for: point, image: image) else {
            return nil
        }

        // 采样该像素的 alpha 值
        if let alpha = image.alphaValue(at: imagePoint), alpha < 0.1 {
            return nil  // 透明区域穿透
        }

        return super.hitTest(point)
    }

    private func imagePixelPoint(for point: NSPoint, image: NSImage) -> NSPoint? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let drawRect = aspectFitRect(for: image.size, in: bounds)
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

    // MARK: - 拖拽传递给 window

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            cancelAnimationTimer()
        } else {
            scheduleAnimationIfNeeded()
        }
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
            toolTip = nextPersistentStatus
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
