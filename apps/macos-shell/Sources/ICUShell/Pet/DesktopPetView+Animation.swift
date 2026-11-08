import AppKit

/// 待机动画：按工作状态加载动画家族、逐帧推进、变体轮换
extension DesktopPetView {
    // MARK: - Image Loading

    /// 按优先级尝试加载桌宠图片
    /// 1. `~/Library/Application Support/ICU/assets/pets/<pet_id>/...`
    /// 2. repo 内 `assets/pets/<pet_id>/...`
    /// 3. 内置占位图
    func loadAnimation(for state: ShellWorkState) {
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
        updateDisplayedImage(PetPlaceholderImage.make())
    }

    func updateDisplayedImage(from assetURL: URL) {
        if let image = NSImage(contentsOf: assetURL) {
            print("[DesktopPetView] Loaded image from: \(assetURL.path)")
            updateDisplayedImage(PixelArtScaler.upscaledForDisplay(image, canvasPointSize: Self.compactContentSize))
            return
        }

        print("[DesktopPetView] Failed to decode image at: \(assetURL.path), using placeholder")
        updateDisplayedImage(PetPlaceholderImage.make())
    }

    func updateDisplayedImage(_ image: NSImage) {
        currentImage = image
        if normalizedBodyBounds == nil {
            normalizedBodyBounds = PixelArtScaler.opaqueBounds(of: image)
        }
        // 拖拽姿势 / 贴边探头 / 摸头打盹片段显示期间，动画帧照常推进，但先不上屏
        if !isShowingDragPose && !isPeeking && actionImage == nil {
            present(image)
        }
    }

    func present(_ image: NSImage?) {
        presentedSource = image
        let shown = isFacingRight ? image.map(PixelArtScaler.mirroredHorizontally) : image
        presentedImage = shown
        imageView?.image = shown
    }

    func scheduleAnimationIfNeeded() {
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

    func cancelAnimationTimer() {
        animationTimer?.cancel()
        animationTimer = nil
    }

    func advanceAnimationFrame() {
        let previousFrameIndex = animationPlayer.currentFrameIndex
        guard let nextFrameURL = animationPlayer.advanceFrame() else {
            return
        }
        updateDisplayedImage(from: nextFrameURL)
        recordLoopProgress(previousFrameIndex: previousFrameIndex, newFrameIndex: animationPlayer.currentFrameIndex)
        tickVariantRotationCooldown()
    }

    func advanceAnimationTick() {
        if animationPlayer.shouldAnimate {
            advanceAnimationFrame()
            return
        }

        tickVariantRotationCooldown()
    }

    func applyAnimationFamily(
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
            updateDisplayedImage(PetPlaceholderImage.make())
            return
        }

        updateDisplayedImage(from: initialFrameURL)

        if window != nil {
            scheduleAnimationIfNeeded()
        }
    }

    func recordLoopProgress(previousFrameIndex: Int, newFrameIndex: Int) {
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

    func tickVariantRotationCooldown() {
        guard currentAnimationFamily.count > 1 else {
            return
        }

        variantRotationTicksRemaining = max(variantRotationTicksRemaining - 1, 0)
        guard variantRotationTicksRemaining == 0 else {
            return
        }

        attemptVariantRotation(force: false)
    }

    func attemptVariantRotation(force: Bool) {
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

    func preferredAction(for state: ShellWorkState) -> String? {
        switch state {
        case .idle:
            return "idle"
        case .working, .focus:
            return "working"
        case .breakState:
            return "alert"
        }
    }

    var shouldScheduleAnimationTimer: Bool {
        animationPlayer.shouldAnimate || currentAnimationFamily.count > 1
    }
}
