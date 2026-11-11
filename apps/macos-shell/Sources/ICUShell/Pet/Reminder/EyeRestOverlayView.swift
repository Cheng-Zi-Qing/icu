import AppKit

/// 护眼休息时盖住整块屏幕的像素夜景：星星一闪一闪，月亮挂着，水豚在小山坡上打盹。
/// 中间是大标题和倒计时。屏幕上没有可看的东西，眼睛自然离开屏幕；想走可以「提前结束」（或按 Esc）
final class EyeRestOverlayView: NSView {
    private enum Metrics {
        static let titleTopShare: CGFloat = 0.16
        static let titleHeight: CGFloat = 44
        static let clockHeight: CGFloat = 84
        static let barWidth: CGFloat = 324
        static let barHeight: CGFloat = 14
        static let barGap: CGFloat = 14
        static let hintHeight: CGFloat = 30
        static let petSide: CGFloat = 256
        static let groundShare: CGFloat = 0.2
        static let hillStep: CGFloat = 8
        static let moonSide: CGFloat = 72
        static let starCount = 70
        static let buttonSize = NSSize(width: 148, height: 34)
        static let buttonBottomInset: CGFloat = 36
        static let segmentGap: CGFloat = 2
    }

    private enum Night {
        static let sky = PixelPalette.rgb(0x141B33, alpha: 0.97)
        static let skyLow = PixelPalette.rgb(0x1E2A4A, alpha: 0.97)
        static let horizon = PixelPalette.rgb(0x2A3A60, alpha: 0.97)
        static let farHill = PixelPalette.rgb(0x2F5A3A)
        static let nearHill = PixelPalette.rgb(0x234A30)
        static let moon = PixelPalette.rgb(0xFCEBB0)
        static let moonShade = PixelPalette.rgb(0xE9D08A)
        static let star = PixelPalette.rgb(0xFFF8EC, alpha: 0.9)
        static let dimText = PixelPalette.rgb(0xB9C4E0)
        static let barEmpty = PixelPalette.rgb(0x33426B)
    }

    let content: ReminderCardContent
    private let petImage: (TimeInterval) -> NSImage?
    private let endButton = PixelButton(identifier: "eyeRest.endEarly")
    private(set) var remaining: TimeInterval
    private var elapsed: TimeInterval = 0

    var onEndEarly: (() -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// `petImage(elapsed)`：休息了这么久时打盹的水豚该是哪一帧
    init(frame: NSRect, content: ReminderCardContent, petImage: @escaping (TimeInterval) -> NSImage?) {
        self.content = content
        self.petImage = petImage
        remaining = content.restSeconds
        super.init(frame: frame)
        identifier = NSUserInterfaceItemIdentifier("eyeRest.overlay")
        endButton.title = TextCatalog.shared.text("rest.end_early")
        endButton.fillColor = PixelPalette.paper2
        endButton.target = self
        endButton.action = #selector(handleEndEarly)
        addSubview(endButton)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        refreshAccessibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var clockText: String { content.detail(remaining: remaining) }

    var litSegments: Int { content.remainingSegments(remaining: remaining) }

    /// 控制器每一拍告诉它：一共歇了多久、还剩多久
    func update(elapsed: TimeInterval, remaining: TimeInterval) {
        self.elapsed = elapsed
        self.remaining = max(0, remaining)
        refreshAccessibility()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        endButton.frame = NSRect(
            x: ((bounds.width - Metrics.buttonSize.width) / 2).rounded(),
            y: bounds.height - Metrics.buttonBottomInset - Metrics.buttonSize.height,
            width: Metrics.buttonSize.width,
            height: Metrics.buttonSize.height
        )
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        drawSky()
        drawStars()
        drawMoon()
        let groundTop = bounds.height * (1 - Metrics.groundShare)
        drawHill(top: groundTop - 40, swell: 26, wavelength: 520, phase: 1.3, color: Night.farHill)
        drawHill(top: groundTop, swell: 18, wavelength: 760, phase: 0, color: Night.nearHill)
        drawPet(groundTop: groundTop)
        drawText()
    }

    private func drawSky() {
        PixelPaint.fill(bounds, Night.sky)
        PixelPaint.fill(NSRect(x: 0, y: bounds.height * 0.5, width: bounds.width, height: bounds.height * 0.5), Night.skyLow)
        PixelPaint.fill(NSRect(x: 0, y: bounds.height * 0.68, width: bounds.width, height: bounds.height * 0.32), Night.horizon)
    }

    /// 星星的位置按下标算出来（每次都一样），每颗隔几拍暗一下
    private func drawStars() {
        let tick = Int(elapsed * 2)
        for index in 0..<Metrics.starCount {
            guard (index + tick) % 7 != 0 else { continue }
            let x = CGFloat((index * 7919 + 131) % 1000) / 1000 * bounds.width
            let y = CGFloat((index * 104_729 + 17) % 1000) / 1000 * bounds.height * 0.6
            let side: CGFloat = index % 5 == 0 ? 4 : 2
            PixelPaint.fill(NSRect(x: (x / 2).rounded() * 2, y: (y / 2).rounded() * 2, width: side, height: side), Night.star)
        }
    }

    private func drawMoon() {
        let moon = NSRect(x: bounds.width * 0.78, y: bounds.height * 0.1, width: Metrics.moonSide, height: Metrics.moonSide)
        PixelPaint.stepped(moon, corner: 6, Night.moon)
        PixelPaint.stepped(NSRect(x: moon.minX + 14, y: moon.minY + 18, width: 12, height: 12), corner: 1, Night.moonShade)
        PixelPaint.stepped(NSRect(x: moon.minX + 40, y: moon.minY + 40, width: 16, height: 16), corner: 2, Night.moonShade)
    }

    /// 一格一格的小山坡
    private func drawHill(top: CGFloat, swell: CGFloat, wavelength: CGFloat, phase: CGFloat, color: NSColor) {
        var x: CGFloat = 0
        while x < bounds.width {
            let wave = sin(x / wavelength * 2 * .pi + phase) * swell
            let y = ((top - wave) / PixelPaint.unit).rounded() * PixelPaint.unit
            PixelPaint.fill(NSRect(x: x, y: y, width: Metrics.hillStep, height: bounds.height - y), color)
            x += Metrics.hillStep
        }
    }

    private func drawPet(groundTop: CGFloat) {
        guard let image = petImage(elapsed) else { return }
        // 画面底边（脚）踩在近处的山坡上
        PixelPaint.image(image, in: NSRect(
            x: ((bounds.width - Metrics.petSide) / 2).rounded(),
            y: (groundTop + 20 - Metrics.petSide).rounded(),
            width: Metrics.petSide,
            height: Metrics.petSide
        ))
    }

    private func drawText() {
        var y = (bounds.height * Metrics.titleTopShare).rounded()
        PixelPaint.text(
            content.restTitle,
            in: NSRect(x: 0, y: y, width: bounds.width, height: Metrics.titleHeight),
            color: PixelPalette.paper, align: 0.5, font: PixelFont.font(scale: 3)
        )
        y += Metrics.titleHeight
        PixelPaint.text(
            clockText,
            in: NSRect(x: 0, y: y, width: bounds.width, height: Metrics.clockHeight),
            color: PixelPalette.yellow, align: 0.5, font: PixelFont.font(scale: 5)
        )
        y += Metrics.clockHeight
        drawProgressBar(at: y)
        y += Metrics.barHeight + Metrics.barGap
        PixelPaint.text(
            TextCatalog.shared.text("rest.hint"),
            in: NSRect(x: 0, y: y, width: bounds.width, height: Metrics.hintHeight),
            color: Night.dimText, align: 0.5, font: PixelFont.font(scale: 2)
        )
    }

    private func drawProgressBar(at y: CGFloat) {
        let count = ReminderCardContent.progressSegments
        let segment = ((Metrics.barWidth - Metrics.segmentGap * CGFloat(count - 1)) / CGFloat(count) / PixelPaint.unit).rounded(.down) * PixelPaint.unit
        let used = segment * CGFloat(count) + Metrics.segmentGap * CGFloat(count - 1)
        let startX = (((bounds.width - used) / 2) / PixelPaint.unit).rounded() * PixelPaint.unit
        let lit = litSegments
        for index in 0..<count {
            let x = startX + CGFloat(index) * (segment + Metrics.segmentGap)
            PixelPaint.fill(NSRect(x: x, y: y, width: segment, height: Metrics.barHeight), index < lit ? PixelPalette.water : Night.barEmpty)
        }
    }

    // MARK: - 提前结束

    override func keyDown(with event: NSEvent) {
        // 53 = Esc
        if event.keyCode == 53 {
            onEndEarly?()
        }
        // 其他按键吃掉：盖着屏幕时不让字打到后面的 App 里
    }

    override func cancelOperation(_ sender: Any?) {
        onEndEarly?()
    }

    override func mouseDown(with event: NSEvent) {}

    @objc private func handleEndEarly() { onEndEarly?() }

    private func refreshAccessibility() {
        setAccessibilityLabel(TextCatalog.shared.format("rest.accessibility", clockText))
    }
}
