import AppKit

/// 桌宠上屏的是哪一张：画面优先级、朝向、贴边探头、拖拽姿势和拎起来的影子窗口。
/// 画面优先级：拖拽 > 贴边探头 > 干活小场景（+Work）> 摸头打盹片段 > 待机动画（+Animation）。
extension DesktopPetView {
    // MARK: - 摸头与打盹

    /// 能不能转头看鼠标：探头、被拎着、正在打盹 / 被摸头时都不转
    var canTurnTowardCursor: Bool {
        !isPeeking && !isDraggingPet && behavior.activeClip == nil && workPlayer.scene?.facesSideways != false
    }

    /// 没有拖拽 / 探头时该显示的画面：转身那一下的正面 > Agent 干活小场景 > 摸头打盹片段 > 待机动画帧
    var restingImage: NSImage? {
        turnImage ?? workImage ?? actionImage ?? currentImage
    }

    func makeBehaviorCoordinator() -> PetBehaviorCoordinator {
        let coordinator = PetBehaviorCoordinator(sprites: { [weak self] clip in
            self?.actionSprites[clip.directory]
        })
        coordinator.isAvailable = { [weak self] in
            guard let self else { return false }
            return !self.isPeeking && !self.dragController.isDragging && self.currentOverlayLayoutMode == .compact
                && self.workPlayer.scene == nil
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

    /// 直接转到这边（贴边、追球、放下时用）；正在转身的那一下作废
    func setFacingRight(_ facingRight: Bool) {
        let wasTurning = cancelTurn()
        guard facingRight != isFacingRight else {
            if wasTurning { presentAfterTurn() }
            return
        }
        isFacingRight = facingRight
        if wasTurning { presentAfterTurn() } else { present(presentedSource) }
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

    func showPeekFrame(_ frame: PetPeekFrame) {
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
        turnSprites = assetLocator.resolvePoseSpriteDirectory(for: petID, subdirectory: "turn", outfit: outfitID).map {
            PetPoseSprites(directory: $0, canvasPointSize: Self.compactContentSize)
        }
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
}
