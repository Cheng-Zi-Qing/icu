import AppKit

/// 把低分辨率像素画按整数倍、最近邻采样预先放大，避免 NSImageView 平滑插值导致发糊。
///
/// 生成的位图按 2x backing 计算：Retina 屏 1:1 显示；非 Retina 屏恰好整数缩小一半，
/// 每个源像素仍是整块色，边缘保持锐利。
enum PixelArtScaler {
    /// 超过这个边长的图不视为像素画，原样返回
    static let maxPixelArtDimension = 128
    static let targetBackingScale: CGFloat = 2

    /// 在不超出目标像素尺寸的前提下，最大的整数放大倍数（至少为 1）
    static func integerScaleFactor(sourcePixelSize: CGSize, targetPixelSize: CGSize) -> Int {
        guard sourcePixelSize.width > 0, sourcePixelSize.height > 0 else {
            return 1
        }
        let widthFactor = Int(targetPixelSize.width / sourcePixelSize.width)
        let heightFactor = Int(targetPixelSize.height / sourcePixelSize.height)
        return max(1, min(widthFactor, heightFactor))
    }

    /// 对低分辨率像素画返回整数倍放大后的新图；其他图片原样返回
    static func upscaledForDisplay(_ image: NSImage, canvasPointSize: NSSize) -> NSImage {
        guard
            let source = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
            source.pixelsWide > 0,
            source.pixelsHigh > 0,
            source.pixelsWide <= maxPixelArtDimension,
            source.pixelsHigh <= maxPixelArtDimension
        else {
            return image
        }

        let factor = integerScaleFactor(
            sourcePixelSize: CGSize(width: source.pixelsWide, height: source.pixelsHigh),
            targetPixelSize: CGSize(
                width: canvasPointSize.width * targetBackingScale,
                height: canvasPointSize.height * targetBackingScale
            )
        )
        guard factor > 1, let scaledRep = nearestNeighborRep(from: source, factor: factor) else {
            return image
        }

        let scaled = NSImage(size: NSSize(
            width: CGFloat(scaledRep.pixelsWide) / targetBackingScale,
            height: CGFloat(scaledRep.pixelsHigh) / targetBackingScale
        ))
        scaled.addRepresentation(scaledRep)
        return scaled
    }

    /// 像素图按指定点尺寸，备好每种屏幕倍率的位图（最近邻，不插值），系统用时不用再缩放
    static func pixelImage(_ image: NSImage, pointSize: NSSize, backingScales: [Int] = [1, 2]) -> NSImage {
        guard let source = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else { return image }
        let result = NSImage(size: pointSize)
        for scale in backingScales {
            let width = Int(pointSize.width.rounded()) * scale
            let height = Int(pointSize.height.rounded()) * scale
            guard let rep = nearestNeighborRep(from: source, width: width, height: height) else { return image }
            rep.size = pointSize
            result.addRepresentation(rep)
        }
        return result
    }

    private static func nearestNeighborRep(from source: NSBitmapImageRep, factor: Int) -> NSBitmapImageRep? {
        nearestNeighborRep(from: source, width: source.pixelsWide * factor, height: source.pixelsHigh * factor)
    }

    private static func nearestNeighborRep(from source: NSBitmapImageRep, width: Int, height: Int) -> NSBitmapImageRep? {
        guard
            let cgSource = source.cgImage,
            let target = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: target)
        else {
            print("[PixelArtScaler] Failed to allocate \(width)x\(height) bitmap, keeping original image")
            return nil
        }

        let cgContext = context.cgContext
        cgContext.interpolationQuality = .none
        cgContext.setShouldAntialias(false)
        cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
        cgContext.draw(cgSource, in: CGRect(x: 0, y: 0, width: width, height: height))
        return target
    }
}

// MARK: - 朝向与轮廓

extension PixelArtScaler {
    /// 水平镜像（像素一一对应，不插值）。贴左边时让形象脸朝屏幕里。
    static func mirroredHorizontally(_ image: NSImage) -> NSImage {
        guard
            let source = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
            let cgSource = source.cgImage,
            let target = makeRGBARep(width: source.pixelsWide, height: source.pixelsHigh),
            let context = NSGraphicsContext(bitmapImageRep: target)
        else {
            print("[PixelArtScaler] Failed to mirror image, keeping original orientation")
            return image
        }

        let width = CGFloat(source.pixelsWide)
        let cgContext = context.cgContext
        cgContext.interpolationQuality = .none
        cgContext.clear(CGRect(x: 0, y: 0, width: width, height: CGFloat(source.pixelsHigh)))
        cgContext.translateBy(x: width, y: 0)
        cgContext.scaleBy(x: -1, y: 1)
        cgContext.draw(cgSource, in: CGRect(x: 0, y: 0, width: width, height: CGFloat(source.pixelsHigh)))

        let mirrored = NSImage(size: image.size)
        mirrored.addRepresentation(target)
        return mirrored
    }

    /// 不透明像素的包围盒，归一化到 0...1，原点在左下角；全透明时返回 nil
    static func opaqueBounds(of image: NSImage, alphaThreshold: UInt8 = 25) -> CGRect? {
        guard
            let source = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
            let cgSource = source.cgImage
        else {
            return nil
        }

        let width = cgSource.width
        let height = cgSource.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(cgSource, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        // CGContext 缓冲区第 0 行是图像顶部
        var minX = width, maxX = -1, minRow = height, maxRow = -1
        for row in 0..<height {
            for x in 0..<width where pixels[(row * width + x) * 4 + 3] >= alphaThreshold {
                minX = min(minX, x); maxX = max(maxX, x)
                minRow = min(minRow, row); maxRow = max(maxRow, row)
            }
        }
        guard maxX >= 0 else { return nil }

        let w = CGFloat(width), h = CGFloat(height)
        return CGRect(
            x: CGFloat(minX) / w,
            y: CGFloat(height - 1 - maxRow) / h,
            width: CGFloat(maxX - minX + 1) / w,
            height: CGFloat(maxRow - minRow + 1) / h
        )
    }

    private static func makeRGBARep(width: Int, height: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )
    }
}
