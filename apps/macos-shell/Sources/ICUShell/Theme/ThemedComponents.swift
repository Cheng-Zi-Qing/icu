import AppKit

enum ThemedComponents {
    enum LabelTone {
        case primary
        case secondary
        case accent
        case danger
    }

    static func styleWindow(_ window: NSWindow, theme: ThemeDefinition) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = color(theme.tokens.colors.windowBackgroundHex, fallback: .windowBackgroundColor)
    }

    static func makePanel(theme: ThemeDefinition) -> NSView {
        let view = NSView()
        stylePanel(view, theme: theme)
        return view
    }

    static func stylePanel(_ view: NSView, theme: ThemeDefinition) {
        view.wantsLayer = true
        view.layer?.backgroundColor = color(theme.tokens.colors.cardBackgroundHex, fallback: .controlBackgroundColor).cgColor
        view.layer?.cornerRadius = panelCornerRadius(theme)
        view.layer?.borderWidth = borderWidth(theme)
        view.layer?.borderColor = color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
    }

    static func makeTitleLabel(_ text: String, theme: ThemeDefinition) -> NSTextField {
        makeLabel(
            text,
            theme: theme,
            tone: .accent,
            font: titleFont(theme)
        )
    }

    static func makeSectionHeader(_ text: String, theme: ThemeDefinition) -> NSTextField {
        makeLabel(
            text,
            theme: theme,
            tone: .accent,
            font: bodyFont(theme)
        )
    }

    static func makeLabel(
        _ text: String,
        theme: ThemeDefinition,
        tone: LabelTone = .primary,
        font: NSFont? = nil
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        styleLabel(label, theme: theme, tone: tone, font: font)
        return label
    }

    static func styleLabel(
        _ label: NSTextField,
        theme: ThemeDefinition,
        tone: LabelTone = .primary,
        font: NSFont? = nil
    ) {
        label.textColor = labelColor(theme: theme, tone: tone)
        label.font = font ?? bodyFont(theme)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.drawsBackground = false
    }

    static func stylePrimaryButton(_ button: NSButton, theme: ThemeDefinition) {
        let background = color(theme.tokens.colors.accentHex, fallback: .controlAccentColor)
        let foreground = readableForeground(for: background, theme: theme)
        styleButton(button, theme: theme, backgroundColor: background, foregroundColor: foreground)
    }

    static func styleSecondaryButton(_ button: NSButton, theme: ThemeDefinition) {
        styleButton(
            button,
            theme: theme,
            backgroundColor: color(theme.tokens.colors.menuBackgroundHex, fallback: .controlColor),
            foregroundColor: color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        )
    }

    static func styleButton(
        _ button: NSButton,
        theme: ThemeDefinition,
        backgroundColor: NSColor,
        foregroundColor: NSColor
    ) {
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.font = bodyFont(theme)
        button.contentTintColor = foregroundColor
        button.wantsLayer = true
        button.layer?.backgroundColor = backgroundColor.cgColor
        button.layer?.cornerRadius = buttonCornerRadius(theme)
        button.layer?.borderWidth = borderWidth(theme)
        button.layer?.borderColor = color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
    }

    static func styleTextField(_ field: NSTextField, theme: ThemeDefinition) {
        field.font = bodyFont(theme)
        field.textColor = color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        field.isBordered = false
        field.focusRingType = .none
        field.drawsBackground = true
        field.backgroundColor = color(theme.tokens.colors.inputBackgroundHex, fallback: .textBackgroundColor)
        field.wantsLayer = true
        field.layer?.cornerRadius = textFieldCornerRadius(theme)
        field.layer?.borderWidth = borderWidth(theme)
        field.layer?.borderColor = color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
    }

    static func styleTextView(_ textView: NSTextView, theme: ThemeDefinition) {
        textView.font = bodyFont(theme)
        textView.textColor = color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        textView.backgroundColor = color(theme.tokens.colors.inputBackgroundHex, fallback: .textBackgroundColor)
        textView.insertionPointColor = color(theme.tokens.colors.accentHex, fallback: .controlAccentColor)
        textView.isRichText = false
    }

    static func styleScrollView(_ scrollView: NSScrollView, theme: ThemeDefinition) {
        scrollView.drawsBackground = true
        scrollView.backgroundColor = color(theme.tokens.colors.inputBackgroundHex, fallback: .textBackgroundColor)
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = textFieldCornerRadius(theme)
        scrollView.layer?.borderWidth = borderWidth(theme)
        scrollView.layer?.borderColor = color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
    }

    static func styleImageFrame(_ view: NSView, theme: ThemeDefinition) {
        view.wantsLayer = true
        view.layer?.backgroundColor = color(theme.tokens.colors.inputBackgroundHex, fallback: .controlBackgroundColor).cgColor
        view.layer?.cornerRadius = panelCornerRadius(theme)
        view.layer?.borderWidth = borderWidth(theme)
        view.layer?.borderColor = color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
    }

    static func styleStatusChip(_ label: NSTextField, theme: ThemeDefinition) {
        label.alignment = .center
        label.textColor = color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        label.font = statusFont(theme)
        label.drawsBackground = true
        label.backgroundColor = color(theme.tokens.colors.overlayHex, fallback: .black.withAlphaComponent(0.6))
        label.wantsLayer = true
        label.layer?.cornerRadius = max(6, panelCornerRadius(theme) * 0.5)
        label.layer?.masksToBounds = true
        label.layer?.borderWidth = borderWidth(theme)
        label.layer?.borderColor = color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
    }

    static func color(_ hex: String, fallback: NSColor) -> NSColor {
        guard let parsed = parsedColor(hex) else {
            return fallback
        }
        return parsed
    }

    static func titleFont(_ theme: ThemeDefinition) -> NSFont {
        font(theme.tokens.typography.titleFont, fallbackSize: 18, fallbackWeight: .bold)
    }

    static func bodyFont(_ theme: ThemeDefinition) -> NSFont {
        font(theme.tokens.typography.bodyFont, fallbackSize: 12, fallbackWeight: .regular)
    }

    static func smallFont(_ theme: ThemeDefinition) -> NSFont {
        font(theme.tokens.typography.smallFont, fallbackSize: 11, fallbackWeight: .regular)
    }

    static func menuItemFont(_ theme: ThemeDefinition) -> NSFont {
        font(theme.tokens.typography.menuItemFont, fallbackSize: 12, fallbackWeight: .regular)
    }

    static func statusFont(_ theme: ThemeDefinition) -> NSFont {
        font(theme.tokens.typography.statusFont, fallbackSize: 11, fallbackWeight: .medium)
    }

    static func labelColor(theme: ThemeDefinition, tone: LabelTone) -> NSColor {
        switch tone {
        case .primary:
            return color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        case .secondary:
            return color(theme.tokens.colors.textSecondaryHex, fallback: .secondaryLabelColor)
        case .accent:
            return color(theme.tokens.colors.accentHex, fallback: .controlAccentColor)
        case .danger:
            return color(theme.tokens.colors.dangerHex, fallback: .systemRed)
        }
    }

    private static func font(
        _ descriptor: String,
        fallbackSize: CGFloat,
        fallbackWeight: NSFont.Weight
    ) -> NSFont {
        let trimmed = descriptor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .monospacedSystemFont(ofSize: fallbackSize, weight: fallbackWeight)
        }

        let parts = trimmed.split(separator: " ")
        let size = parts.last.flatMap { Double($0) }.map { CGFloat($0) } ?? fallbackSize
        let name = parts.last.flatMap { Double($0) } == nil ? trimmed : parts.dropLast().joined(separator: " ")

        if !name.isEmpty, let font = NSFont(name: name, size: size) {
            return font
        }

        let weight: NSFont.Weight = name.lowercased().contains("bold") ? .bold : fallbackWeight
        return .monospacedSystemFont(ofSize: size, weight: weight)
    }

    private static func parsedColor(_ hex: String) -> NSColor? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else {
            return nil
        }

        let value = String(trimmed.dropFirst())
        guard value.count == 6 || value.count == 8 else {
            return nil
        }

        guard let raw = UInt64(value, radix: 16) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if value.count == 6 {
            red = CGFloat((raw >> 16) & 0xFF) / 255
            green = CGFloat((raw >> 8) & 0xFF) / 255
            blue = CGFloat(raw & 0xFF) / 255
            alpha = 1
        } else {
            red = CGFloat((raw >> 24) & 0xFF) / 255
            green = CGFloat((raw >> 16) & 0xFF) / 255
            blue = CGFloat((raw >> 8) & 0xFF) / 255
            alpha = CGFloat(raw & 0xFF) / 255
        }

        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func readableForeground(for background: NSColor, theme: ThemeDefinition) -> NSColor {
        guard let rgb = background.usingColorSpace(.deviceRGB) else {
            return .black
        }

        let luminance = (0.299 * rgb.redComponent) + (0.587 * rgb.greenComponent) + (0.114 * rgb.blueComponent)
        if luminance > 0.62 {
            return .black
        }

        return color(theme.tokens.colors.textPrimaryHex, fallback: .white)
    }

    private static func panelCornerRadius(_ theme: ThemeDefinition) -> CGFloat {
        numericValue(theme.components.panel.cornerRadius, fallback: numericValue(theme.tokens.surface.cornerRadius, fallback: 12))
    }

    private static func buttonCornerRadius(_ theme: ThemeDefinition) -> CGFloat {
        numericValue(theme.components.button.cornerRadius, fallback: numericValue(theme.tokens.surface.cornerRadius, fallback: 10))
    }

    private static func textFieldCornerRadius(_ theme: ThemeDefinition) -> CGFloat {
        numericValue(theme.components.textField.cornerRadius, fallback: numericValue(theme.tokens.surface.cornerRadius, fallback: 10))
    }

    private static func borderWidth(_ theme: ThemeDefinition) -> CGFloat {
        numericValue(theme.tokens.surface.borderWidth, fallback: 1)
    }

    private static func numericValue(_ value: String, fallback: CGFloat) -> CGFloat {
        CGFloat(Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Double(fallback))
    }
}
