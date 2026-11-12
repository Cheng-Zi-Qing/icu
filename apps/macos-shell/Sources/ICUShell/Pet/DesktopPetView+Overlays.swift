import AppKit

/// 桌宠周围的浮层布局（状态标签、气泡）与主题 / 文案刷新
extension DesktopPetView {
    /// 水豚画在哪：脚下留出状态字那一条，往上是形象本身
    var petCanvasRect: NSRect {
        let band = min(LayoutMetrics.statusChipBand, bounds.height)
        return NSRect(
            x: 0,
            y: band,
            width: bounds.width,
            height: max(0, min(LayoutMetrics.petCanvasHeight, bounds.height - band))
        )
    }

    /// 形象 + 头顶留白的上沿；气泡和在等你的卡片从这里往上排
    var petStageTop: CGFloat {
        min(LayoutMetrics.petStageHeight, bounds.height)
    }

    var usesExpandedCardLayout: Bool {
        bounds.height >= Self.cardExpandedContentSize.height - 1
    }

    var usesExpandedTransientBubbleLayout: Bool {
        bounds.height >= Self.transientBubbleExpandedContentSize.height - 1
            && bounds.height < Self.cardExpandedContentSize.height - 1
    }

    var currentOverlayLayoutMode: OverlayLayoutMode {
        if waitCardView?.isHidden == false {
            return .card
        }
        if !transientBubbleContainer.isHidden {
            return .transientBubble
        }
        return .compact
    }

    func notifyOverlayLayoutModeChanged() {
        onOverlayLayoutModeChanged?(currentOverlayLayoutMode)
    }

    func layoutPetChrome() {
        guard imageView != nil, statusLabel != nil else {
            return
        }
        imageView.frame = petCanvasRect
        updateImageScaling()
        layoutStatusChip()
    }

    /// 窗口里落在屏幕可见区域内的那一块。贴边时窗口透明的那一边被推到屏幕外（贴底时下沿压在 Dock 后面），
    /// 浮层只能摆在这一块里，不然会被屏幕边截掉。露出来的太窄（藏边探头时）就按整个窗口算：浮层一出现就会先滑出来
    var onScreenBounds: NSRect {
        guard let window, let screen = window.screen ?? NSScreen.main else { return bounds }
        let visible = convert(window.convertFromScreen(screen.visibleFrame), from: nil)
        let clipped = bounds.intersection(visible)
        return clipped.width >= LayoutMetrics.minimumOnScreenOverlayWidth ? clipped : bounds
    }

    /// 宽 `width` 的浮层尽量对准身体中线，但整块留在 `area` 里（左右各留 `inset`）
    private func overlayX(width: CGFloat, in area: NSRect, inset: CGFloat) -> CGFloat {
        let center = (petBodyRect ?? petCanvasRect).midX
        let lower = area.minX + inset
        let upper = area.maxX - inset - width
        guard upper >= lower else { return lower.rounded() }
        return min(max(center - width / 2, lower), upper).rounded()
    }

    /// 窗口挪了（贴边、藏边、拖动）：浮层按新的可见区域重新摆
    func layoutOverlaysForWindowPosition() {
        layoutStatusChip()
        if transientBubbleContainer?.isHidden == false { layoutTransientBubble() }
        if waitCardView?.isHidden == false { layoutWaitCard() }
    }

    /// 状态小胶囊：贴着文字的宽度，对准身体，摆在脚下那一条里；那一条被压到屏幕外（贴着屏幕底边）就往上挪进看得见的地方
    func layoutStatusChip() {
        guard statusLabel != nil else { return }
        if let themeFont = statusChipThemeFont {
            statusLabel.font = StatusChipCell.displayFont(for: statusLabel.stringValue, themeFont: themeFont)
        }
        let area = petCanvasRect.intersection(onScreenBounds)
        let margin = LayoutMetrics.statusChipMargin
        let maxWidth = max(0, area.width - margin * 2)
        let size = (statusLabel.cell as? StatusChipCell)?.fittingChipSize(maxWidth: maxWidth)
            ?? NSSize(width: maxWidth, height: 18)
        let x = overlayX(width: size.width, in: area, inset: margin)
        let inBand = max(1, (LayoutMetrics.statusChipBand - size.height) / 2)
        let y = max(inBand, onScreenBounds.minY + inBand)
        statusLabel.frame = NSRect(x: x, y: y.rounded(), width: size.width, height: size.height)
        statusLabel.wantsLayer = true
        statusLabel.layer?.cornerRadius = size.height / 2
    }

    func layoutTransientBubble() {
        guard transientBubbleContainer != nil, transientBubbleLabel != nil else {
            return
        }

        let petRect = petCanvasRect
        let area = petRect.intersection(onScreenBounds)
        let maxBubbleWidth = max(72, area.width - 20)
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 7
        let textSize = transientBubbleTextSize(maxWidth: maxBubbleWidth - (horizontalPadding * 2))
        let bubbleWidth = min(maxBubbleWidth, textSize.width + (horizontalPadding * 2))
        let bubbleHeight = max(28, min(LayoutMetrics.transientBubbleMaxHeight, textSize.height + (verticalPadding * 2)))
        let bubbleX = overlayX(width: bubbleWidth, in: area, inset: 6)
        let bubbleY: CGFloat
        if usesExpandedTransientBubbleLayout {
            bubbleY = petStageTop + LayoutMetrics.transientBubbleGap + LayoutMetrics.transientBubbleTailSize
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
            tailY = petStageTop + LayoutMetrics.transientBubbleGap
        } else {
            tailY = transientBubbleContainer.frame.minY - 6
        }
        // 小尾巴指着身体；气泡被屏幕边推开时，尾巴别伸到气泡外面去
        let bubbleFrame = transientBubbleContainer.frame
        let bodyMidX = (petBodyRect ?? petRect).midX
        let tailMidX = min(max(bodyMidX, bubbleFrame.minX + 10), bubbleFrame.maxX - 10)
        transientBubbleTail.frame = NSRect(
            x: (tailMidX - 4).rounded(),
            y: tailY,
            width: 8,
            height: 8
        )
    }

    /// 气泡里这句话要占多大：用标签自己的 cell 量（它画字时左右各留一点边，拿字形宽度直接量会少算，
    /// 英文按词换行时就多出一行、被气泡截掉）。短句收窄到字那么宽；收窄后换行变了（多出一行）就用满宽
    private func transientBubbleTextSize(maxWidth: CGFloat) -> NSSize {
        guard let cell = transientBubbleLabel.cell else { return NSSize(width: maxWidth, height: 14) }
        let unbounded = CGFloat.greatestFiniteMagnitude
        let widest = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: maxWidth, height: unbounded))
        let narrow = min(maxWidth, ceil(widest.width))
        let narrowHeight = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: narrow, height: unbounded)).height
        guard narrowHeight > widest.height else { return NSSize(width: narrow, height: ceil(narrowHeight)) }
        return NSSize(width: maxWidth, height: ceil(widest.height))
    }

    func hideTransientBubble(notifyLayoutChange: Bool = true) {
        transientBubbleContainer.isHidden = true
        transientBubbleTail.isHidden = true
        if notifyLayoutChange {
            notifyOverlayLayoutModeChanged()
        }
        updateToolTipForVisibleContent()
    }

    func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
        }
    }

    func subscribeToCopyChanges() {
        copyObserver = NotificationCenter.default.addObserver(
            forName: .icuCopyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadPersistentStatusText()
        }
    }

    func reloadPersistentStatusText() {
        let previousPersistentStatus = persistentStatusText
        let nextPersistentStatus = DesktopPetCopy.statusText(for: currentWorkState)
        persistentStatusText = nextPersistentStatus

        if statusLabel.stringValue == previousPersistentStatus {
            statusLabel.stringValue = nextPersistentStatus
            layoutStatusChip()
            updateToolTipForVisibleContent()
        }
    }

    func applyTheme() {
        guard statusLabel != nil else {
            return
        }

        let theme = ThemeManager.shared.currentTheme
        ThemedComponents.styleStatusChip(statusLabel, theme: theme)
        statusChipThemeFont = statusLabel.font
        // 底色交给圆角 layer 画，整颗胶囊都是底色（文字框自己画只会填文字那一小块）
        statusLabel.wantsLayer = true
        statusLabel.layer?.backgroundColor = statusLabel.backgroundColor?.cgColor
        statusLabel.drawsBackground = false
        layoutStatusChip()
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
        updateToolTipForVisibleContent()
    }

    func updateToolTipForVisibleContent() {
        let next: String?
        if !transientBubbleContainer.isHidden {
            next = transientBubbleLabel.stringValue
        } else {
            next = persistentStatusText
        }
        // 每次赋值 AppKit 都会重建提示区域、重新算光标，没变就不动
        if toolTip != next {
            toolTip = next
        }
    }
}
