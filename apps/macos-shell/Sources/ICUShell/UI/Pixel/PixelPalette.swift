import AppKit

/// 像素界面用的颜色：跟水豚同一套调色板
enum PixelPalette {
    static let outline = rgb(0x2F1C12)
    static let body = rgb(0xB0714A)
    static let shade = rgb(0x8A5236)
    static let dark = rgb(0x4A2E22)
    static let muzzle = rgb(0x99603F)
    static let paper = rgb(0xFFF8EC)
    static let paper2 = rgb(0xF1E3CC)
    static let paper3 = rgb(0xE6D5BC)
    static let yellow = rgb(0xF4BC2C)
    static let grass = rgb(0x6DAA45)
    static let water = rgb(0x7FB2D9)
    static let blush = rgb(0xE58D86)
    static let danger = rgb(0xB5432F)
    static let summaryBackground = rgb(0xEEF5E4)
    /// 衣柜试衣台：天空和草地
    static let sky = rgb(0xDCEEF6)
    static let meadow = rgb(0xC6E0A8)
    /// 衣柜格子：穿着的那件铺浅黄
    static let wornCell = rgb(0xFCEBB0)
    /// 今日报告评分偏低时的底色
    static let reportTired = rgb(0xF8D9D2)
    static let white = NSColor.white
    static let shadow = rgb(0x2F1C12, alpha: 0.35)
    static let highlight = NSColor(white: 1, alpha: 0.45)
    static let lowlight = rgb(0x2F1C12, alpha: 0.18)

    static func rgb(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}
