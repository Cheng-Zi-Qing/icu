import AppKit

/// 小像素图标：每行一个字符串，字符对应颜色，`.` 是透明
struct PixelIcon: Equatable {
    let rows: [String]

    static let ink: [Character: NSColor] = [
        "o": PixelPalette.outline, "x": PixelPalette.body, "m": PixelPalette.muzzle, "d": PixelPalette.dark,
        "w": PixelPalette.white, "b": PixelPalette.water, "y": PixelPalette.yellow, "g": PixelPalette.grass,
        "e": PixelPalette.paper3, "p": PixelPalette.paper, "s": PixelPalette.shade, "r": PixelPalette.blush,
    ]

    static let drop = PixelIcon(rows: ["...o...", "..obo..", ".obbbo.", ".obbbo.", "obbbbbo", "owbbbbo", "owbbbbo", ".obbbo.", "..ooo.."])
    static let eye = PixelIcon(rows: ["...ooooo...", ".oowwwwwoo.", "owwwoooowwo", "owwwoooowwo", ".oowwwwwoo.", "...ooooo..."])
    static let bell = PixelIcon(rows: ["....o....", "...oyo...", "..oyyyo..", ".oyyyyyo.", ".oyyyyyo.", "oyyyyyyyo", "ooooooooo", "...ooo..."])
    static let clock = PixelIcon(rows: ["..ooooo..", ".owwwwwo.", "owwwowwwo", "owwwowwwo", "owwwoowwo", "owwwwwwwo", ".owwwwwo.", "..ooooo.."])
    static let cupFull = PixelIcon(rows: ["ooooooo", "obbbbbo", "owbbbbo", "obbbbbo", ".obbbo.", "..ooo.."])
    static let cupEmpty = PixelIcon(rows: ["ooooooo", "oeeeeeo", "oeeeeeo", "oeeeeeo", ".oeeeo.", "..ooo.."])
    static let cross = PixelIcon(rows: ["o...o", ".o.o.", "..o..", ".o.o.", "o...o"])
    static let crossWhite = PixelIcon(rows: ["w...w", ".w.w.", "..w..", ".w.w.", "w...w"])
    static let left = PixelIcon(rows: ["..o", ".oo", "ooo", ".oo", "..o"])
    static let right = PixelIcon(rows: ["o..", "oo.", "ooo", "oo.", "o.."])
    static let minus = PixelIcon(rows: ["ooooo"])
    static let lock = PixelIcon(rows: ["..ooo..", ".o...o.", ".o...o.", "ooooooo", "oyyyyyo", "oyyoyyo", "oyyyyyo", "ooooooo"])
    static let check = PixelIcon(rows: ["......o", ".....oo", "o...oo.", "oo.oo..", ".ooo...", "..o...."])
    static let question = PixelIcon(rows: [".sss.", "s...s", "....s", "...s.", "..s..", ".....", "..s.."])
    static let plus = PixelIcon(rows: ["..o..", "..o..", "ooooo", "..o..", "..o.."])
}
