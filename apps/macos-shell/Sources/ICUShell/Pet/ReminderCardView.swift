import AppKit

// MARK: - 圆形倒计时进度环

private final class CountdownRingView: NSView {
    var progress: CGFloat = 1.0 { didSet { needsDisplay = true } }
    var ringColor: NSColor = NSColor.systemGreen

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.midX, cy = bounds.midY
        let r = min(bounds.width, bounds.height) / 2 - 2

        // 轨道
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(3)
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                   startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // 进度弧（从12点钟开始顺时针）
        ctx.setStrokeColor(ringColor.cgColor)
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        let start = CGFloat.pi / 2
        let end = start - .pi * 2 * progress
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                   startAngle: start, endAngle: end, clockwise: true)
        ctx.strokePath()
    }
}

// MARK: - ReminderCardView

final class ReminderCardView: NSView {
    private let messageLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")          // 推荐时间提示
    private let countdownLabel = NSTextField(labelWithString: "")     // 倒计时数字
    private let ringView = CountdownRingView(frame: .zero)            // 进度环
    private let completeButton = NSButton(title: "", target: nil, action: nil)
    private let snoozeButton = NSButton(title: "", target: nil, action: nil)
    private let skipButton = NSButton(title: "", target: nil, action: nil)

    private var countdownTimer: Timer?
    private var countdownTotal: TimeInterval = 0
    private var countdownRemaining: TimeInterval = 0
    private var currentType: HealthReminderType = .eyeCare

    var onAction: ((HealthReminderOutcome) -> Void)? {
        didSet { updateActionAvailability() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func configure(
        with payload: ReminderPresentationPayload,
        onAction: ((HealthReminderOutcome) -> Void)? = nil
    ) {
        messageLabel.stringValue = payload.text
        completeButton.title = DesktopPetCopy.reminderCompleteActionTitle()
        snoozeButton.title = DesktopPetCopy.reminderSnoozeActionTitle()
        skipButton.title = DesktopPetCopy.reminderSkipActionTitle()
        self.onAction = onAction
        currentType = payload.type

        switch payload.type {
        case .eyeCare:
            hintLabel.stringValue = "👀 看向 6 米外，保持 20 秒"
            ringView.ringColor = NSColor.systemCyan
            startCountdown(seconds: 20)
        case .hydration:
            hintLabel.stringValue = "💧 小口慢饮，别一次灌"
            ringView.ringColor = NSColor.systemBlue
            stopCountdown()
            ringView.isHidden = true
            countdownLabel.isHidden = true
        }
    }

    func applyTheme(_ theme: ThemeDefinition) {
        wantsLayer = true
        layer?.backgroundColor = ThemedComponents.color(
            theme.tokens.colors.overlayHex,
            fallback: .windowBackgroundColor
        ).withAlphaComponent(0.98).cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor

        messageLabel.textColor = ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        messageLabel.font = ThemedComponents.statusFont(theme)
        hintLabel.textColor = ThemedComponents.color(theme.tokens.colors.textSecondaryHex, fallback: .secondaryLabelColor)
        hintLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        countdownLabel.textColor = ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)

        let buttonTextColor = ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        let buttonFillColor = ThemedComponents.color(theme.tokens.colors.inputBackgroundHex, fallback: .controlBackgroundColor)
        let buttonBorderColor = ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor)
        for button in [completeButton, snoozeButton, skipButton] {
            button.contentTintColor = buttonTextColor
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = buttonFillColor.withAlphaComponent(0.5).cgColor
            button.layer?.borderWidth = 1
            button.layer?.borderColor = buttonBorderColor.cgColor
            button.layer?.cornerRadius = 6
            button.alphaValue = button.isEnabled ? 1 : 0.65
        }
    }

    private func setup() {
        wantsLayer = true

        // 主文案
        messageLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.message")
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // 推荐时间提示
        hintLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.hint")
        hintLabel.alignment = .center
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 1
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        // 倒计时数字
        countdownLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.countdown")
        countdownLabel.alignment = .center
        countdownLabel.isHidden = true
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        // 进度环
        ringView.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.ring")
        ringView.isHidden = true
        ringView.translatesAutoresizingMaskIntoConstraints = false

        // 按钮
        completeButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.complete")
        completeButton.target = self
        completeButton.action = #selector(handleCompleteAction)
        completeButton.translatesAutoresizingMaskIntoConstraints = false

        snoozeButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.snooze")
        snoozeButton.target = self
        snoozeButton.action = #selector(handleSnoozeAction)
        snoozeButton.translatesAutoresizingMaskIntoConstraints = false

        skipButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.skip")
        skipButton.target = self
        skipButton.action = #selector(handleSkipAction)
        skipButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(messageLabel)
        addSubview(hintLabel)
        addSubview(ringView)
        addSubview(countdownLabel)
        addSubview(completeButton)
        addSubview(snoozeButton)
        addSubview(skipButton)

        NSLayoutConstraint.activate([
            // 主文案
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // 推荐时间提示
            hintLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            // 进度环 (居中，36×36)
            ringView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 6),
            ringView.centerXAnchor.constraint(equalTo: centerXAnchor),
            ringView.widthAnchor.constraint(equalToConstant: 36),
            ringView.heightAnchor.constraint(equalToConstant: 36),

            // 倒计时数字 (叠在进度环中心)
            countdownLabel.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: ringView.centerYAnchor),

            // 按钮
            completeButton.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: 6),
            completeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            completeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            snoozeButton.topAnchor.constraint(equalTo: completeButton.bottomAnchor, constant: 4),
            snoozeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            snoozeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            skipButton.topAnchor.constraint(equalTo: snoozeButton.bottomAnchor, constant: 4),
            skipButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            skipButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        updateActionAvailability()
    }

    // MARK: - 倒计时

    private func startCountdown(seconds: TimeInterval) {
        stopCountdown()
        countdownTotal = seconds
        countdownRemaining = seconds
        ringView.isHidden = false
        countdownLabel.isHidden = false
        updateCountdownDisplay()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.countdownRemaining -= 1
            self.updateCountdownDisplay()
            if self.countdownRemaining <= 0 {
                self.stopCountdown()
                self.onAction?(.completed)
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdownDisplay() {
        let secs = max(0, Int(countdownRemaining))
        countdownLabel.stringValue = "\(secs)"
        ringView.progress = countdownTotal > 0 ? CGFloat(countdownRemaining / countdownTotal) : 0
    }

    // MARK: - 其余

    private func updateActionAvailability() {
        let isEnabled = onAction != nil
        for button in [completeButton, snoozeButton, skipButton] {
            button.isEnabled = isEnabled
            button.alphaValue = isEnabled ? 1 : 0.65
        }
    }

    func interactiveHitView(at point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.001 else { return nil }
        for button in [completeButton, snoozeButton, skipButton] {
            let buttonPoint = convert(point, to: button)
            if button.bounds.contains(buttonPoint) { return button }
        }
        return bounds.contains(point) ? self : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? { interactiveHitView(at: point) }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}

    @objc private func handleCompleteAction() { stopCountdown(); onAction?(.completed) }
    @objc private func handleSnoozeAction()   { stopCountdown(); onAction?(.snoozed) }
    @objc private func handleSkipAction()     { stopCountdown(); onAction?(.skipped) }

    deinit { stopCountdown() }
}
