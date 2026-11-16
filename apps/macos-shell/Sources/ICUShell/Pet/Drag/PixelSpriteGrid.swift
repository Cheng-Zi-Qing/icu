import CoreGraphics
import Foundation

/// 原像素格上的一张小图：一格就是素材里的一个像素（屏幕上 4pt），第 0 行在最上面。
///
/// 拎起来的拉长、甩动都在这张小图上按整格做，最后整张最近邻放大上屏，
/// 所以屏幕上永远是整齐的方块，不会出现半格、斜切或被拉扁的像素。
struct PixelSpriteGrid: Hashable {
    /// 透明格
    static let clear: UInt32 = 0

    let width: Int
    let height: Int
    /// 每格一个 RGBA（预乘，大端排列 r g b a），按行从上到下
    let cells: [UInt32]

    init(width: Int, height: Int, cells: [UInt32]) {
        precondition(width >= 0 && height >= 0 && cells.count == width * height, "cells must fill the grid")
        self.width = width
        self.height = height
        self.cells = cells
    }

    static func empty(width: Int, height: Int) -> PixelSpriteGrid {
        PixelSpriteGrid(width: width, height: height, cells: Array(repeating: clear, count: width * height))
    }

    /// 越界读到的都是透明格，邻居判断不用另外处理边缘
    subscript(x: Int, y: Int) -> UInt32 {
        guard x >= 0, y >= 0, x < width, y < height else { return Self.clear }
        return cells[y * width + x]
    }

    func isOpaque(x: Int, y: Int) -> Bool {
        self[x, y] & 0xFF != 0
    }

    /// 一行里第一格和最后一格不透明的位置；整行透明时为 nil
    func opaqueSpan(row: Int) -> ClosedRange<Int>? {
        guard let first = (0..<width).first(where: { isOpaque(x: $0, y: row) }),
              let last = (0..<width).last(where: { isOpaque(x: $0, y: row) }) else { return nil }
        return first...last
    }
}

// MARK: - 和 CGImage 互转

extension PixelSpriteGrid {
    private static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

    /// 从整数倍放大过的像素图里按格子中心取色，还原出原像素格
    static func sampling(_ image: CGImage, columns: Int, rows: Int) -> PixelSpriteGrid? {
        guard columns > 0, rows > 0, image.width > 0, image.height > 0 else { return nil }
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let cells = (0..<rows).flatMap { row in
            (0..<columns).map { column -> UInt32 in
                let x = min(width - 1, Int((Double(column) + 0.5) * Double(width) / Double(columns)))
                let y = min(height - 1, Int((Double(row) + 0.5) * Double(height) / Double(rows)))
                let offset = (y * width + x) * 4
                return UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
                    | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
            }
        }
        return PixelSpriteGrid(width: columns, height: rows, cells: cells)
    }

    /// 一格一像素的位图；交给图层按最近邻放大
    func makeImage() -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        // 每格按大端存成 r g b a 四个字节
        let bigEndian = cells.map(\.bigEndian)
        let data = bigEndian.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
