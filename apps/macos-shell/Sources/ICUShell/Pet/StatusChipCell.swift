import AppKit

/// 状态小胶囊的文字单元格：左右留白、文字上下居中。
/// 系统默认的 NSTextFieldCell 把文字贴在顶部，放进比字高的胶囊里会显得歪。
final class StatusChipCell: NSTextFieldCell {
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 3

    /// 系统画字时还会在文字框里再留几 pt，宽度要留足余量，否则会被截成「待…」
    private static let drawingSlack: CGFloat = 4

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        centeredTextRect(in: rect)
    }

    /// NSTextFieldCell 画字用的是这个矩形（只在这里缩一次，避免重复缩进）
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        centeredTextRect(in: rect)
    }

    private func centeredTextRect(in rect: NSRect) -> NSRect {
        let inset = rect.insetBy(dx: Self.horizontalPadding - Self.drawingSlack, dy: 0)
        let textHeight = min(lineHeight, rect.height)
        return NSRect(
            x: inset.minX,
            y: rect.minY + ((rect.height - textHeight) / 2).rounded(.down),
            width: max(0, inset.width),
            height: textHeight
        )
    }

    /// 能完整放下当前文字的胶囊尺寸（不超过 `maxWidth`）
    func fittingChipSize(maxWidth: CGFloat) -> NSSize {
        let textWidth = (stringValue as NSString).size(withAttributes: [.font: resolvedFont]).width
        return NSSize(
            width: min(maxWidth, ceil(textWidth) + Self.horizontalPadding * 2 + Self.drawingSlack),
            height: ceil(lineHeight) + Self.verticalPadding * 2
        )
    }

    /// 主题字体能显示这段文字就用主题字体；否则（比如等宽英文字体 Menlo 遇到中文）
    /// 换成系统给这段文字挑的字体（中文是苹方），保持主题字号，字距和基线才正常
    static func displayFont(for text: String, themeFont: NSFont) -> NSFont {
        guard !covers(themeFont, text) else { return themeFont }
        let fallback = CTFontCreateForString(
            themeFont as CTFont,
            text as CFString,
            CFRange(location: 0, length: (text as NSString).length)
        ) as NSFont
        let sized = NSFont(descriptor: fallback.fontDescriptor, size: themeFont.pointSize) ?? fallback
        return covers(sized, text) ? sized : themeFont
    }

    private static func covers(_ font: NSFont, _ text: String) -> Bool {
        let covered = font.coveredCharacterSet
        return text.unicodeScalars.allSatisfy { $0.properties.isWhitespace || covered.contains($0) }
    }

    private var resolvedFont: NSFont {
        font ?? .systemFont(ofSize: NSFont.smallSystemFontSize)
    }

    private var lineHeight: CGFloat {
        let font = resolvedFont
        return ceil(font.ascender - font.descender + font.leading)
    }
}
