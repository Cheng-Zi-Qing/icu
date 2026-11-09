import AppKit

// MARK: - NSImage alpha 采样扩展

extension NSImage {
    /// 采样图片指定坐标的 alpha 值（0.0–1.0），坐标系为图片像素坐标（左下角原点）
    func alphaValue(at point: NSPoint) -> CGFloat? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let px = Int(point.x)
        let py = Int(point.y)

        guard px >= 0, px < width, py >= 0, py < height else { return nil }

        // 仅采样 1×1 像素
        guard let context = CGContext(
            data: nil,
            width: 1, height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 将目标像素平移到 context 原点
        context.translateBy(x: CGFloat(-px), y: CGFloat(-py))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let pixel = data.load(fromByteOffset: 3, as: UInt8.self)  // alpha channel
        return CGFloat(pixel) / 255.0
    }
}
