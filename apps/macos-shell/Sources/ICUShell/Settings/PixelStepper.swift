import AppKit

/// [−] 数值 [+]：右边对齐放在设置行里。`cycle` 为 true 时两边是左右箭头（在几个选项里挑）
final class PixelStepper: NSView {
    static let size = NSSize(width: 128, height: 24)

    let minusButton: PixelButton
    let plusButton: PixelButton
    private(set) var valueText = "" { didSet { needsDisplay = true; setAccessibilityValue(valueText) } }
    private let onStep: (Int) -> Void

    override var isFlipped: Bool { true }

    init(identifier: String, cycle: Bool, onStep: @escaping (Int) -> Void) {
        self.onStep = onStep
        minusButton = PixelButton(icon: cycle ? .left : .minus, identifier: "\(identifier).minus")
        plusButton = PixelButton(icon: cycle ? .right : .plus, identifier: "\(identifier).plus")
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setAccessibilityRole(.incrementor)

        let side = Self.size.height
        minusButton.frame = NSRect(x: 0, y: 0, width: side, height: side)
        plusButton.frame = NSRect(x: Self.size.width - side, y: 0, width: side, height: side)
        minusButton.setAccessibilityLabel(TextCatalog.shared.text("common.decrease"))
        plusButton.setAccessibilityLabel(TextCatalog.shared.text("common.increase"))
        for button in [minusButton, plusButton] {
            button.target = self
            button.action = #selector(handleStep(_:))
            addSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(text: String, canDecrease: Bool, canIncrease: Bool) {
        valueText = text
        minusButton.isEnabled = canDecrease
        plusButton.isEnabled = canIncrease
    }

    override func draw(_ dirtyRect: NSRect) {
        let side = Self.size.height
        let field = NSRect(x: side + 4, y: 0, width: bounds.width - 2 * side - 8, height: side)
        PixelPaint.plate(field, PixelPalette.white, corner: 1)
        // 凹进去的内阴影
        PixelPaint.fill(NSRect(x: field.minX + PixelPaint.unit, y: field.minY + PixelPaint.unit, width: field.width - 2 * PixelPaint.unit, height: PixelPaint.unit), PixelPalette.paper3)
        PixelPaint.text(valueText, in: field.offsetBy(dx: 0, dy: 1), align: 0.5)
    }

    @objc private func handleStep(_ sender: PixelButton) {
        onStep(sender === plusButton ? 1 : -1)
    }
}
