import AppKit

/// 屏幕中央的像素提醒卡：左边是做着配套动作的水豚（喝水 / 望远处），右边是大标题、一行说明和三个按钮。
/// 喝水的主按钮是「我喝了」；护眼的主按钮是「开始休息」，点了以后由全屏休息接手倒计时
final class ReminderStageView: NSView {
    private enum Metrics {
        static let size = NSSize(width: 432, height: 204)
        static let shadow = 2
        static let padding: CGFloat = 16
        static let stage = NSRect(x: 16, y: 16, width: 152, height: 168)
        static let meadowHeight: CGFloat = 36
        static let petSide: CGFloat = 128
        static let petBottomInset: CGFloat = 12
        static let columnX: CGFloat = 184
        static let titleTop: CGFloat = 18
        static let titleHeight: CGFloat = 30
        static let summaryTop: CGFloat = 54
        static let hintTop: CGFloat = 74
        static let lineHeight: CGFloat = 18
        static let primaryTop: CGFloat = 106
        static let primaryHeight: CGFloat = 36
        static let secondaryTop: CGFloat = 150
        static let secondaryHeight: CGFloat = 28
        static let buttonGap: CGFloat = 8
    }

    static let preferredSize = Metrics.size
    /// 水豚换帧的间隔（和场景的 4 帧 / 秒一致）
    static let frameInterval: TimeInterval = 0.25

    let content: ReminderCardContent
    private let petImage: (TimeInterval) -> NSImage?
    private let completeButton = PixelButton(identifier: "reminderStage.complete")
    private let snoozeButton = PixelButton(identifier: "reminderStage.snooze")
    private let skipButton = PixelButton(identifier: "reminderStage.skip")
    private var elapsed: TimeInterval = 0
    private var frameTimer: Timer?

    var onAction: ((HealthReminderOutcome) -> Void)?

    override var isFlipped: Bool { true }

    /// `petImage(elapsed)`：卡片显示了这么久时水豚该是哪一帧；没有素材就只画草地
    init(content: ReminderCardContent, petImage: @escaping (TimeInterval) -> NSImage?) {
        self.content = content
        self.petImage = petImage
        super.init(frame: NSRect(origin: .zero, size: Metrics.size))
        identifier = NSUserInterfaceItemIdentifier("reminderStage")
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { frameTimer?.invalidate() }

    // MARK: - 动画

    func startAnimating() {
        frameTimer?.invalidate()
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            self?.advance(by: Self.frameInterval)
        }
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    func stopAnimating() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    /// 水豚的动作往前走（计时器调；测试里直接调）
    func advance(by seconds: TimeInterval) {
        elapsed += seconds
        setNeedsDisplay(Metrics.stage)
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        let plate = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - CGFloat(Metrics.shadow) * PixelPaint.unit)
        PixelPaint.plate(plate, PixelPalette.paper, corner: 3, shadow: Metrics.shadow)
        drawStage()
        drawText()
    }

    /// 左边的小舞台：天空 + 草地，水豚站在草地上
    private func drawStage() {
        let stage = Metrics.stage
        PixelPaint.plate(stage, PixelPalette.sky, corner: 2)
        let inner = stage.insetBy(dx: PixelPaint.unit, dy: PixelPaint.unit)
        PixelPaint.fill(
            NSRect(x: inner.minX, y: inner.maxY - Metrics.meadowHeight, width: inner.width, height: Metrics.meadowHeight - PixelPaint.unit),
            PixelPalette.meadow
        )
        guard let image = petImage(elapsed) else { return }
        PixelPaint.image(image, in: NSRect(
            x: stage.midX - Metrics.petSide / 2,
            y: stage.maxY - Metrics.petBottomInset - Metrics.petSide,
            width: Metrics.petSide,
            height: Metrics.petSide
        ))
    }

    private func drawText() {
        let columnWidth = bounds.width - Metrics.padding - Metrics.columnX
        let icon: PixelIcon = content.symbol == .drop ? .drop : .eye
        let iconWidth = PixelPaint.iconSize(icon).width
        PixelPaint.draw(icon, centeredIn: NSRect(x: Metrics.columnX, y: Metrics.titleTop, width: iconWidth, height: Metrics.titleHeight))
        let titleX = Metrics.columnX + iconWidth + 8
        PixelPaint.text(
            content.title,
            in: NSRect(x: titleX, y: Metrics.titleTop, width: bounds.width - Metrics.padding - titleX, height: Metrics.titleHeight),
            font: PixelFont.font(scale: 2)
        )
        PixelPaint.text(content.summary, in: NSRect(x: Metrics.columnX, y: Metrics.summaryTop, width: columnWidth, height: Metrics.lineHeight))
        PixelPaint.text(
            content.hint,
            in: NSRect(x: Metrics.columnX, y: Metrics.hintTop, width: columnWidth, height: Metrics.lineHeight),
            color: PixelPalette.shade
        )
    }

    override func layout() {
        super.layout()
        let columnWidth = bounds.width - Metrics.padding - Metrics.columnX
        let half = ((columnWidth - Metrics.buttonGap) / 2 / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        completeButton.frame = NSRect(x: Metrics.columnX, y: Metrics.primaryTop, width: columnWidth, height: Metrics.primaryHeight)
        snoozeButton.frame = NSRect(x: Metrics.columnX, y: Metrics.secondaryTop, width: half, height: Metrics.secondaryHeight)
        skipButton.frame = NSRect(
            x: Metrics.columnX + columnWidth - half, y: Metrics.secondaryTop, width: half, height: Metrics.secondaryHeight
        )
    }

    // MARK: - 点击

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// 卡片其余部分吃掉点击，不让它掉到后面的窗口上
    override func mouseDown(with event: NSEvent) {}

    private func setup() {
        completeButton.title = content.completeTitle
        completeButton.fillColor = PixelPalette.yellow
        snoozeButton.title = content.snoozeTitle
        snoozeButton.fillColor = PixelPalette.paper2
        skipButton.title = content.skipTitle
        skipButton.isFlat = true
        skipButton.textColor = PixelPalette.shade
        for (button, action) in [
            (completeButton, #selector(handleComplete)),
            (snoozeButton, #selector(handleSnooze)),
            (skipButton, #selector(handleSkip)),
        ] {
            button.target = self
            button.action = action
            addSubview(button)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        let separator = TextCatalog.shared.text("common.accessibility_separator")
        setAccessibilityLabel([content.title, content.summary, content.hint].joined(separator: separator))
    }

    @objc private func handleComplete() { onAction?(.completed) }
    @objc private func handleSnooze() { onAction?(.snoozed) }
    @objc private func handleSkip() { onAction?(.skipped) }
}
