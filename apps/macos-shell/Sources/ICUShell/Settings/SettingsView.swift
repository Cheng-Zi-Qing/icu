import AppKit

/// 像素风设置窗口的内容：标题栏（上面趴着一只水豚）、健康资料、喝水建议、提醒间隔
final class SettingsView: NSView {
    enum Layout {
        static let width: CGFloat = 360
        /// 标题栏上面留给水豚脑袋的透明区域
        static let decorationHeight = PixelPanelChrome.decorationHeight
        static let titleHeight = PixelPanelChrome.titleHeight
        static let padding: CGFloat = 16
        static let headerHeight: CGFloat = 28
        static let rowHeight: CGFloat = 32
        static let summaryHeight: CGFloat = 48
        static let messageHeight: CGFloat = 20
        static let modeRowHeight: CGFloat = 32
        static let explanationHeight: CGFloat = 36
        static let shadow = PixelPanelChrome.shadow
        static let labelIndent: CGFloat = 32
    }

    private struct Row {
        let field: SettingsForm.Field
        let title: String
        let y: CGFloat
    }

    let closeButton = PixelPanelChrome.makeCloseButton(identifier: "settings.close")
    private(set) var steppers: [SettingsForm.Field: PixelStepper] = [:]
    private(set) var modeButtons: [EyeCareMode: PixelButton] = [:]
    var form: SettingsForm { didSet { refresh() } }
    var message: String? { didSet { needsDisplay = true } }

    private let decoration: NSImage?
    private let onStep: (SettingsForm.Field, Int) -> Void
    private let onSelectMode: (EyeCareMode) -> Void
    private var modeRowY: CGFloat = 0
    private var explanationY: CGFloat = 0
    private var rows: [Row] = []
    private var healthHeaderY: CGFloat = 0
    private var remindHeaderY: CGFloat = 0
    private var summaryY: CGFloat = 0
    private var separatorY: CGFloat = 0
    private var messageY: CGFloat = 0

    override var isFlipped: Bool { true }

    static func preferredSize() -> NSSize {
        let body = 12 + Layout.headerHeight + 3 * Layout.rowHeight + Layout.summaryHeight + 8
            + 16 + Layout.headerHeight + Layout.modeRowHeight + Layout.explanationHeight
            + Layout.rowHeight + Layout.messageHeight + 8
        let height = Layout.decorationHeight + Layout.titleHeight + body + CGFloat(Layout.shadow) * PixelPaint.unit
        return NSSize(width: Layout.width, height: height)
    }

    init(
        form: SettingsForm,
        decoration: NSImage?,
        onStep: @escaping (SettingsForm.Field, Int) -> Void,
        onSelectMode: @escaping (EyeCareMode) -> Void
    ) {
        self.form = form
        self.decoration = decoration
        self.onStep = onStep
        self.onSelectMode = onSelectMode
        super.init(frame: NSRect(origin: .zero, size: Self.preferredSize()))
        buildLayout()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var titleBarRect: NSRect {
        PixelPanelChrome.titleBarRect(in: bounds)
    }

    private func buildLayout() {
        addSubview(closeButton)

        var y = Layout.decorationHeight + Layout.titleHeight + 12
        healthHeaderY = y
        y += Layout.headerHeight
        for (field, title) in [(SettingsForm.Field.bodyWeight, "体重"), (.cupVolume, "杯子容量"), (.workHours, "每天工作")] {
            rows.append(Row(field: field, title: title, y: y))
            y += Layout.rowHeight
        }
        summaryY = y + 2
        y += Layout.summaryHeight + 8
        separatorY = y + 6
        y += 16
        remindHeaderY = y
        y += Layout.headerHeight
        modeRowY = y
        y += Layout.modeRowHeight
        explanationY = y
        y += Layout.explanationHeight
        rows.append(Row(field: .eyeInterval, title: "护眼间隔", y: y))
        y += Layout.rowHeight
        messageY = y

        let modes = EyeCareMode.allCases
        let gap: CGFloat = 6
        let buttonWidth = (bounds.width - 2 * Layout.padding - CGFloat(modes.count - 1) * gap) / CGFloat(modes.count)
        for (index, mode) in modes.enumerated() {
            let button = PixelButton(title: mode.title, identifier: "settings.eyeMode.\(mode.rawValue)")
            button.frame = NSRect(
                x: Layout.padding + CGFloat(index) * (buttonWidth + gap),
                y: modeRowY + (Layout.modeRowHeight - PixelStepper.size.height) / 2,
                width: buttonWidth.rounded(.down),
                height: PixelStepper.size.height
            )
            button.target = self
            button.action = #selector(handleSelectMode(_:))
            addSubview(button)
            modeButtons[mode] = button
        }

        for row in rows {
            let stepper = PixelStepper(identifier: "settings.\(row.field)", cycle: row.field == .eyeInterval) { [weak self] direction in
                self?.onStep(row.field, direction)
            }
            stepper.setFrameOrigin(NSPoint(
                x: bounds.width - Layout.padding - PixelStepper.size.width,
                y: row.y + (Layout.rowHeight - PixelStepper.size.height) / 2
            ))
            stepper.setAccessibilityLabel(row.title)
            addSubview(stepper)
            steppers[row.field] = stepper
        }
    }

    /// 当前护眼方式下面那句说明（带出处）
    var eyeModeExplanation: String {
        form.timers.eyeMode.explanation
    }

    private func refresh() {
        for (mode, button) in modeButtons {
            button.fillColor = mode == form.timers.eyeMode ? PixelPalette.yellow : PixelPalette.paper2
            button.setAccessibilityValue(mode == form.timers.eyeMode ? "已选" : nil)
        }
        for (field, stepper) in steppers {
            stepper.update(text: form.valueText(field), canDecrease: form.canStep(field, by: -1), canIncrease: form.canStep(field, by: 1))
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawChrome()
        drawSectionHeader(.drop, "健康资料", y: healthHeaderY)
        drawSectionHeader(.bell, "提醒", y: remindHeaderY)
        for row in rows {
            PixelPaint.text(row.title, in: NSRect(x: Layout.padding + Layout.labelIndent, y: row.y, width: 160, height: Layout.rowHeight))
        }
        drawSummary()
        PixelPaint.wrappedText(
            eyeModeExplanation,
            in: NSRect(x: Layout.padding, y: explanationY + 2, width: bounds.width - 2 * Layout.padding, height: Layout.explanationHeight),
            color: PixelPalette.shade
        )
        PixelPaint.dottedLine(from: Layout.padding, to: bounds.width - Layout.padding, y: separatorY)
        if let message {
            PixelPaint.text(message, in: NSRect(x: Layout.padding, y: messageY, width: bounds.width - 2 * Layout.padding, height: Layout.messageHeight), color: PixelPalette.danger)
        }
    }

    private func drawChrome() {
        PixelPanelChrome.draw(in: bounds, title: "ICU 设置", decoration: decoration)
    }

    private func drawSectionHeader(_ icon: PixelIcon, _ title: String, y: CGFloat) {
        let rect = NSRect(x: Layout.padding, y: y, width: 24, height: Layout.headerHeight)
        PixelPaint.draw(icon, centeredIn: rect)
        PixelPaint.text(title, in: NSRect(x: Layout.padding + Layout.labelIndent, y: y, width: 200, height: Layout.headerHeight))
    }

    /// 喝水建议：第一行喝多少，第二行多久提醒一次 + 每杯一个杯子图标
    private func drawSummary() {
        let rect = NSRect(x: Layout.padding, y: summaryY, width: bounds.width - 2 * Layout.padding, height: Layout.summaryHeight)
        PixelPaint.plate(rect, PixelPalette.summaryBackground, corner: 1, line: PixelPalette.grass)
        let inner = rect.insetBy(dx: 10, dy: 4)
        let lineHeight = inner.height / 2
        PixelPaint.text(form.hydrationHeadline, in: NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: lineHeight), color: PixelPalette.dark)

        let detailRect = NSRect(x: inner.minX, y: inner.minY + lineHeight, width: inner.width, height: lineHeight)
        PixelPaint.text(form.hydrationDetail, in: detailRect, color: PixelPalette.shade)
        let shownCups = min(form.cups, 8)
        var x = inner.minX + PixelPaint.textSize(form.hydrationDetail).width + 10
        for _ in 0..<shownCups where x + 14 <= inner.maxX {
            PixelPaint.draw(.cupFull, centeredIn: NSRect(x: x, y: detailRect.minY, width: 14, height: detailRect.height))
            x += 16
        }
    }

    @objc private func handleSelectMode(_ sender: PixelButton) {
        guard let mode = modeButtons.first(where: { $0.value === sender })?.key else { return }
        onSelectMode(mode)
    }

    override func mouseDown(with event: NSEvent) {
        PixelPanelChrome.handleMouseDown(event, in: self)
    }

    /// 透明的上沿（水豚以外）不接鼠标，点下去落到后面的窗口
    override func hitTest(_ point: NSPoint) -> NSView? {
        PixelPanelChrome.passesThrough(point, in: self) ? nil : super.hitTest(point)
    }
}
