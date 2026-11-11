import AppKit

/// 桌宠周围的浮层布局（状态标签、气泡）与主题 / 文案刷新
extension DesktopPetView {
    var petCanvasRect: NSRect {
        NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: min(LayoutMetrics.petCanvasHeight, bounds.height)
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
        layoutStatusChip()
    }

    /// 状态小胶囊：贴着文字的宽度，居中在身体下方，不超出窗口
    func layoutStatusChip() {
        guard statusLabel != nil else { return }
        if let themeFont = statusChipThemeFont {
            statusLabel.font = StatusChipCell.displayFont(for: statusLabel.stringValue, themeFont: themeFont)
        }
        let petRect = petCanvasRect
        let margin = LayoutMetrics.statusChipMargin
        let maxWidth = max(0, petRect.width - margin * 2)
        let size = (statusLabel.cell as? StatusChipCell)?.fittingChipSize(maxWidth: maxWidth)
            ?? NSSize(width: maxWidth, height: 18)
        let centerX = (petBodyRect ?? petRect).midX
        let x = min(max(centerX - size.width / 2, petRect.minX + margin), petRect.maxX - margin - size.width)
        statusLabel.frame = NSRect(x: x.rounded(), y: margin, width: size.width, height: size.height)
        statusLabel.wantsLayer = true
        statusLabel.layer?.cornerRadius = size.height / 2
    }

    func layoutTransientBubble() {
        guard transientBubbleContainer != nil, transientBubbleLabel != nil else {
            return
        }

        let petRect = petCanvasRect
        let maxBubbleWidth = max(72, petRect.width - 20)
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 7
        let textSize = transientBubbleTextSize(maxWidth: maxBubbleWidth - (horizontalPadding * 2))
        let bubbleWidth = min(maxBubbleWidth, textSize.width + (horizontalPadding * 2))
        let bubbleHeight = max(28, min(LayoutMetrics.transientBubbleMaxHeight, textSize.height + (verticalPadding * 2)))
        let bubbleX = max(6, min(petRect.midX - (bubbleWidth / 2), petRect.width - bubbleWidth - 6))
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
        transientBubbleTail.frame = NSRect(
            x: transientBubbleContainer.frame.midX - 4,
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
