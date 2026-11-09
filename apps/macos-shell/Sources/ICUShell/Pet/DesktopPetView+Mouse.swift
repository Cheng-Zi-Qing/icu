import AppKit

/// 鼠标：透明区域点击穿透、像素命中、移入移出、按下拖动。
extension DesktopPetView {
    // MARK: - 透明区域点击穿透

    /// 透明像素（alpha ≈ 0）不响应鼠标事件，点击可穿透到桌面
    override func hitTest(_ point: NSPoint) -> NSView? {
        if !reminderCardView.isHidden {
            let reminderPoint = convert(point, to: reminderCardView)
            if reminderCardView.bounds.contains(reminderPoint) {
                return reminderCardView.interactiveHitView(at: reminderPoint) ?? reminderCardView
            }
        }
        if !waitCardView.isHidden {
            let cardPoint = convert(point, to: waitCardView)
            if waitCardView.bounds.contains(cardPoint) {
                return waitCardView.interactiveHitView(at: cardPoint) ?? waitCardView
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
}
