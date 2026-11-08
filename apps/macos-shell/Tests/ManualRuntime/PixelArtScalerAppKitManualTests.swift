import AppKit

/// 2×2 测试图：左上红、右上绿、左下蓝、右下透明（按位图行序，第 0 行在顶部）
private func makeCheckerImage() throws -> NSImage {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 2,
        pixelsHigh: 2,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw TestFailure(message: "failed to allocate checker bitmap")
    }
    rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: 0, y: 0)
    rep.setColor(NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), atX: 1, y: 0)
    rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1), atX: 0, y: 1)
    rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: 1, y: 1)
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.addRepresentation(rep)
    return image
}

private func bitmap(of image: NSImage) throws -> NSBitmapImageRep {
    guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
        throw TestFailure(message: "scaled image should carry a bitmap representation")
    }
    return rep
}

private func isApproximately(_ color: NSColor?, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> Bool {
    guard let c = color?.usingColorSpace(.deviceRGB) else { return false }
    let tolerance: CGFloat = 0.02
    return abs(c.alphaComponent - a) < tolerance
        && (a == 0 || (abs(c.redComponent - r) < tolerance
            && abs(c.greenComponent - g) < tolerance
            && abs(c.blueComponent - b) < tolerance))
}

func testPixelArtScalerPicksLargestIntegerFactorThatFits() throws {
    let factor64 = PixelArtScaler.integerScaleFactor(
        sourcePixelSize: CGSize(width: 64, height: 64),
        targetPixelSize: CGSize(width: 256, height: 256)
    )
    try expect(factor64 == 4, "64px art in a 256px canvas should scale by 4 (got \(factor64))")

    let factorTall = PixelArtScaler.integerScaleFactor(
        sourcePixelSize: CGSize(width: 32, height: 48),
        targetPixelSize: CGSize(width: 256, height: 256)
    )
    try expect(factorTall == 5, "non-square art should be limited by its longest side (got \(factorTall))")

    let factorLarge = PixelArtScaler.integerScaleFactor(
        sourcePixelSize: CGSize(width: 512, height: 512),
        targetPixelSize: CGSize(width: 256, height: 256)
    )
    try expect(factorLarge == 1, "art already larger than the canvas should not be upscaled (got \(factorLarge))")

    let factorEmpty = PixelArtScaler.integerScaleFactor(
        sourcePixelSize: .zero,
        targetPixelSize: CGSize(width: 256, height: 256)
    )
    try expect(factorEmpty == 1, "empty images should fall back to a factor of 1 (got \(factorEmpty))")
}

func testPixelArtScalerUsesHardEdgesWhenUpscaling() throws {
    let source = try makeCheckerImage()
    let scaled = PixelArtScaler.upscaledForDisplay(source, canvasPointSize: NSSize(width: 4, height: 4))
    let rep = try bitmap(of: scaled)

    // 4pt 画布 × 2x backing = 8px，2px 源图应整数放大 4 倍
    try expect(rep.pixelsWide == 8 && rep.pixelsHigh == 8, "scaled bitmap should be 8×8 (got \(rep.pixelsWide)×\(rep.pixelsHigh))")
    try expect(scaled.size == NSSize(width: 4, height: 4), "scaled image point size should match the 2x backing (got \(scaled.size))")

    // 每个源像素对应的 4×4 块都必须是纯色，边界处不能出现插值混色
    for y in 0..<8 {
        for x in 0..<8 {
            let color = rep.colorAt(x: x, y: y)
            let ok: Bool
            switch (x / 4, y / 4) {
            case (0, 0): ok = isApproximately(color, 1, 0, 0, 1)
            case (1, 0): ok = isApproximately(color, 0, 1, 0, 1)
            case (0, 1): ok = isApproximately(color, 0, 0, 1, 1)
            default: ok = isApproximately(color, 0, 0, 0, 0)
            }
            try expect(ok, "pixel (\(x), \(y)) should keep its source color without blending (got \(String(describing: color)))")
        }
    }
}

func testPixelArtScalerLeavesHighResolutionImagesUntouched() throws {
    let large = NSImage(size: NSSize(width: 512, height: 512))
    let result = PixelArtScaler.upscaledForDisplay(large, canvasPointSize: NSSize(width: 128, height: 128))
    try expect(result === large, "images that are not low-res pixel art should be returned as-is")
}

private func apply(_ t: CATransform3D, to point: CGPoint) -> CGPoint {
    let x = t.m11 * point.x + t.m21 * point.y + t.m41
    let y = t.m12 * point.x + t.m22 * point.y + t.m42
    let w = t.m14 * point.x + t.m24 * point.y + t.m44
    return CGPoint(x: x / w, y: y / w)
}

func testAnimationEngineStretchHangsFromTopAndLandingSquashesOnFeet() throws {
    let bounds = CGRect(x: 0, y: 0, width: 128, height: 128)
    // NSView 托管的 layer 默认锚点在左下角 (0, 0)：坐标即相对锚点的偏移
    let anchor = CGPoint(x: 0, y: 0)

    let stretched = PetAnimationEngine.composedTransform(
        base: .identity,
        drag: DragOutput(pose: .hold(tilt: 0), stretchY: 1.2, swingDegrees: 0, landingSquash: 1),
        layerBounds: bounds,
        anchorPoint: anchor
    )
    let top = apply(stretched, to: CGPoint(x: 64, y: 128))
    let feet = apply(stretched, to: CGPoint(x: 64, y: 0))
    try expect(abs(top.x - 64) < 0.001 && abs(top.y - 128) < 0.001, "stretch should keep the grab point (top center) fixed (got \(top))")
    try expect(feet.y < -20, "stretch should let the body hang downward (feet moved to \(feet))")

    let landed = PetAnimationEngine.composedTransform(
        base: .identity,
        drag: DragOutput(pose: .landing(frame: 0), stretchY: 1, swingDegrees: 0, landingSquash: 0.8),
        layerBounds: bounds,
        anchorPoint: anchor
    )
    let landedFeet = apply(landed, to: CGPoint(x: 64, y: 0))
    let landedTop = apply(landed, to: CGPoint(x: 64, y: 128))
    try expect(abs(landedFeet.x - 64) < 0.001 && abs(landedFeet.y) < 0.001, "landing squash should keep the feet planted (got \(landedFeet))")
    try expect(abs(landedTop.y - 102.4) < 0.001, "landing squash should lower the head (got \(landedTop))")

    let rest = PetAnimationEngine.composedTransform(base: .identity, drag: .rest, layerBounds: bounds, anchorPoint: anchor)
    try expect(CATransform3DIsIdentity(rest), "rest output should leave the layer untransformed")
}

func testPixelArtScalerMirrorsHorizontallyWithoutBlending() throws {
    let mirrored = PixelArtScaler.mirroredHorizontally(try makeCheckerImage())
    let rep = try bitmap(of: mirrored)
    try expect(rep.pixelsWide == 2 && rep.pixelsHigh == 2, "mirroring should keep the pixel size")
    try expect(isApproximately(rep.colorAt(x: 0, y: 0), 0, 1, 0, 1), "top-left should now be green")
    try expect(isApproximately(rep.colorAt(x: 1, y: 0), 1, 0, 0, 1), "top-right should now be red")
    try expect(isApproximately(rep.colorAt(x: 0, y: 1), 0, 0, 0, 0), "bottom-left should now be transparent")
    try expect(isApproximately(rep.colorAt(x: 1, y: 1), 0, 0, 1, 1), "bottom-right should now be blue")
}

func testPixelArtScalerMeasuresOpaqueBoundsInBottomLeftUnitSpace() throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        throw TestFailure(message: "failed to allocate bounds bitmap")
    }
    for y in 0..<4 { for x in 0..<4 { rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: x, y: y) } }
    // 位图第 0 行在顶部：(1,0) 和 (2,1) 不透明
    rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: 1, y: 0)
    rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: 2, y: 1)
    let image = NSImage(size: NSSize(width: 4, height: 4))
    image.addRepresentation(rep)

    let bounds = PixelArtScaler.opaqueBounds(of: image)
    try expect(
        bounds == CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.5),
        "opaque bounds should be normalized with the origin at the bottom-left (got \(String(describing: bounds)))"
    )

    let empty = NSImage(size: NSSize(width: 4, height: 4))
    try expect(PixelArtScaler.opaqueBounds(of: empty) == nil, "images without pixels should have no bounds")
}
