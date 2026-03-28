import AppKit

enum AvatarPanelTheme {
    private static var theme: ThemeDefinition {
        ThemeManager.shared.currentTheme
    }

    static var background: NSColor {
        ThemedComponents.color(theme.tokens.colors.windowBackgroundHex, fallback: .windowBackgroundColor)
    }

    static var card: NSColor {
        ThemedComponents.color(theme.tokens.colors.cardBackgroundHex, fallback: .controlBackgroundColor)
    }

    static var input: NSColor {
        ThemedComponents.color(theme.tokens.colors.inputBackgroundHex, fallback: .textBackgroundColor)
    }

    static var border: NSColor {
        ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor)
    }

    static var accent: NSColor {
        ThemedComponents.color(theme.tokens.colors.accentHex, fallback: .controlAccentColor)
    }

    static var accentDark: NSColor {
        ThemedComponents.color(theme.tokens.colors.menuBackgroundHex, fallback: .controlColor)
    }

    static var text: NSColor {
        ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
    }

    static var muted: NSColor {
        ThemedComponents.color(theme.tokens.colors.textSecondaryHex, fallback: .secondaryLabelColor)
    }

    static var danger: NSColor {
        ThemedComponents.color(theme.tokens.colors.dangerHex, fallback: .systemRed)
    }

    static var titleFont: NSFont {
        ThemedComponents.titleFont(theme)
    }

    static var bodyFont: NSFont {
        ThemedComponents.bodyFont(theme)
    }

    static var smallFont: NSFont {
        ThemedComponents.smallFont(theme)
    }

    static func styleWindow(_ window: NSWindow) {
        ThemedComponents.styleWindow(window, theme: theme)
    }

    static func makeCard() -> NSView {
        ThemedComponents.makePanel(theme: theme)
    }

    static func makeTitleLabel(_ text: String) -> NSTextField {
        let label = ThemedComponents.makeTitleLabel(text, theme: theme)
        label.alignment = .left
        return label
    }

    static func makeLabel(_ text: String, color: NSColor = AvatarPanelTheme.text, font: NSFont = AvatarPanelTheme.bodyFont) -> NSTextField {
        let label = ThemedComponents.makeLabel(text, theme: theme, tone: .primary, font: font)
        label.textColor = color
        return label
    }

    static func stylePrimaryButton(_ button: NSButton) {
        ThemedComponents.stylePrimaryButton(button, theme: theme)
    }

    static func styleSecondaryButton(_ button: NSButton) {
        ThemedComponents.styleSecondaryButton(button, theme: theme)
    }

    static func styleButton(_ button: NSButton, backgroundColor: NSColor, foregroundColor: NSColor) {
        ThemedComponents.styleButton(button, theme: theme, backgroundColor: backgroundColor, foregroundColor: foregroundColor)
    }

    static func styleEditableTextField(_ field: NSTextField) {
        ThemedComponents.styleTextField(field, theme: theme)
    }

    static func styleTextView(_ textView: NSTextView) {
        ThemedComponents.styleTextView(textView, theme: theme)
    }

    static func styleScrollView(_ scrollView: NSScrollView) {
        ThemedComponents.styleScrollView(scrollView, theme: theme)
    }

    static func styleImageFrame(_ view: NSView) {
        ThemedComponents.styleImageFrame(view, theme: theme)
    }
}
