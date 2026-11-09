import AppKit

/// 桌宠头顶的像素提醒卡：图标 + 随机俏皮话，一行说明（第几杯 / 还剩几秒）右边是「我就不」，
/// 底下「我喝了」「等会儿」两个按钮。护眼提醒多一条 10 格的像素进度条，倒计时走完自动算完成
final class ReminderCardView: NSView {
    private enum Metrics {
        static let tailHeight: CGFloat = 6
        static let padding: CGFloat = 6
        static let textInset: CGFloat = 8
        static let headerHeight: CGFloat = 18
        static let detailTop: CGFloat = 26
        static let detailHeight: CGFloat = 18
        static let barTop: CGFloat = 48
        static let barHeight: CGFloat = 10
        static let buttonHeight: CGFloat = 22
        static let buttonGap: CGFloat = 4
        static let skipWidth: CGFloat = 44
        static let segmentGap: CGFloat = 2
    }

    /// 最高的那种卡（护眼，带进度条）有多高；窗口按它留位置
    static let maximumHeight = height(showsCountdown: true)

    static func height(showsCountdown: Bool) -> CGFloat {
        buttonsTop(showsCountdown: showsCountdown) + Metrics.buttonHeight + Metrics.padding + Metrics.tailHeight
    }

    private static func buttonsTop(showsCountdown: Bool) -> CGFloat {
        showsCountdown
            ? Metrics.barTop + Metrics.barHeight + Metrics.buttonGap
            : Metrics.detailTop + Metrics.detailHeight + Metrics.buttonGap
    }

    private let completeButton = PixelButton(identifier: "desktopPet.reminderCard.complete")
    private let snoozeButton = PixelButton(identifier: "desktopPet.reminderCard.snooze")
    private let skipButton = PixelButton(identifier: "desktopPet.reminderCard.skip")

    private(set) var content: ReminderCardContent?
    private var remaining: TimeInterval = 0
    private var countdownTimer: Timer?

    var onAction: ((HealthReminderOutcome) -> Void)? {
        didSet { updateActionAvailability() }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { countdownTimer?.invalidate() }

    // MARK: - 内容

    var preferredHeight: CGFloat {
        Self.height(showsCountdown: content?.showsCountdown ?? true)
    }

    var detailText: String { content?.detail(remaining: remaining) ?? "" }

    var remainingSegments: Int { content?.remainingSegments(remaining: remaining) ?? 0 }

    func configure(
        with payload: ReminderPresentationPayload,
        cups: CupProgress? = nil,
        onAction: ((HealthReminderOutcome) -> Void)? = nil,
        pick: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) {
        let content = ReminderCardContent(payload: payload, cups: cups, pick: pick)
        self.content = content
        completeButton.title = content.completeTitle
        snoozeButton.title = content.snoozeTitle
        skipButton.title = content.skipTitle
        self.onAction = onAction
        remaining = content.restSeconds
        content.showsCountdown ? startCountdown() : stopCountdown()
        refresh()
    }

    /// 倒计时往前走（计时器每秒调一次；测试里直接调）。走完只算一次完成
    func advanceCountdown(by seconds: TimeInterval) {
        guard remaining > 0, content?.showsCountdown == true else { return }
        remaining = max(0, remaining - seconds)
        refresh()
        if remaining <= 0 {
            stopCountdown()
            onAction?(.completed)
        }
    }

    // MARK: - 布局与绘制

    override func layout() {
        super.layout()
        let width = bounds.width
        let inner = width - Metrics.textInset * 2
        let buttonWidth = ((inner - Metrics.buttonGap) / 2 / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        let top = Self.buttonsTop(showsCountdown: content?.showsCountdown ?? true)
        completeButton.frame = NSRect(x: Metrics.textInset, y: top, width: buttonWidth, height: Metrics.buttonHeight)
        snoozeButton.frame = NSRect(
            x: width - Metrics.textInset - buttonWidth, y: top, width: buttonWidth, height: Metrics.buttonHeight
        )
        skipButton.frame = NSRect(
            x: width - Metrics.padding - Metrics.skipWidth, y: Metrics.detailTop,
            width: Metrics.skipWidth, height: Metrics.detailHeight
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let content else { return }
        let plate = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - Metrics.tailHeight)
        PixelPaint.plate(plate, PixelPalette.paper, corner: 2)
        drawTail(below: plate)

        let icon: PixelIcon = content.symbol == .drop ? .drop : .eye
        let iconSize = PixelPaint.iconSize(icon)
        let headerY = Metrics.padding
        PixelPaint.draw(icon, centeredIn: NSRect(x: Metrics.textInset, y: headerY, width: iconSize.width, height: Metrics.headerHeight))
        let titleX = Metrics.textInset + iconSize.width + 4
        PixelPaint.text(
            content.title,
            in: NSRect(x: titleX, y: headerY, width: bounds.width - Metrics.textInset - titleX, height: Metrics.headerHeight)
        )
        PixelPaint.text(
            detailText,
            in: NSRect(x: Metrics.textInset, y: Metrics.detailTop, width: skipButton.frame.minX - Metrics.textInset, height: Metrics.detailHeight),
            color: PixelPalette.shade
        )
        if content.showsCountdown {
            drawProgressBar()
        }
    }

    /// 底边正中往下的小尖角，指向桌宠
    private func drawTail(below plate: NSRect) {
        let unit = PixelPaint.unit
        for row in 0..<4 {
            let half = CGFloat(4 - row) * unit
            let y = plate.maxY - unit + CGFloat(row) * unit
            PixelPaint.fill(NSRect(x: bounds.midX - half, y: y, width: half * 2, height: unit), PixelPalette.outline)
            if half > unit {
                PixelPaint.fill(NSRect(x: bounds.midX - half + unit, y: y, width: half * 2 - unit * 2, height: unit), PixelPalette.paper)
            }
        }
    }

    private func drawProgressBar() {
        let bar = NSRect(x: Metrics.textInset, y: Metrics.barTop, width: bounds.width - Metrics.textInset * 2, height: Metrics.barHeight)
        PixelPaint.stepped(bar, corner: 1, PixelPalette.outline)
        let inner = bar.insetBy(dx: PixelPaint.unit, dy: PixelPaint.unit)
        let count = ReminderCardContent.progressSegments
        let gaps = Metrics.segmentGap * CGFloat(count - 1)
        let segment = (((inner.width - gaps) / CGFloat(count)) / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        let used = segment * CGFloat(count) + gaps
        let startX = inner.minX + ((inner.width - used) / 2 / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        let lit = remainingSegments
        for index in 0..<count {
            let x = startX + CGFloat(index) * (segment + Metrics.segmentGap)
            let color = index < lit ? PixelPalette.water : PixelPalette.paper3
            PixelPaint.fill(NSRect(x: x, y: inner.minY, width: segment, height: inner.height), color)
        }
    }

    // MARK: - 点击

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// 按钮优先；卡片其余部分吃掉点击，不让它掉到桌面上
    func interactiveHitView(at point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.001 else { return nil }
        for button in [completeButton, snoozeButton, skipButton] where !button.isHidden {
            if button.bounds.contains(convert(point, to: button)) { return button }
        }
        return bounds.contains(point) ? self : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        interactiveHitView(at: convert(point, from: superview))
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}

    // MARK: - 私有

    private func setup() {
        wantsLayer = true
        completeButton.fillColor = PixelPalette.yellow
        snoozeButton.fillColor = PixelPalette.paper2
        skipButton.isFlat = true
        skipButton.textAlignment = 0.5
        skipButton.textColor = PixelPalette.shade
        for (button, action) in [
            (completeButton, #selector(handleCompleteAction)),
            (snoozeButton, #selector(handleSnoozeAction)),
            (skipButton, #selector(handleSkipAction)),
        ] {
            button.target = self
            button.action = action
            addSubview(button)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        updateActionAvailability()
    }

    private func refresh() {
        setAccessibilityLabel(content.map { "\($0.title)，\(detailText)" })
        needsLayout = true
        needsDisplay = true
    }

    private func startCountdown() {
        stopCountdown()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.advanceCountdown(by: 1)
        }
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateActionAvailability() {
        let isEnabled = onAction != nil
        for button in [completeButton, snoozeButton, skipButton] {
            button.isEnabled = isEnabled
        }
    }

    @objc private func handleCompleteAction() { finish(.completed) }
    @objc private func handleSnoozeAction() { finish(.snoozed) }
    @objc private func handleSkipAction() { finish(.skipped) }

    private func finish(_ outcome: HealthReminderOutcome) {
        stopCountdown()
        onAction?(outcome)
    }
}
