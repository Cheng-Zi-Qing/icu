import AppKit

/// 贴边探头的帧：`<pet>/edge/peek_<n>.png`
///
/// 图里画布的右边就是屏幕边（贴左边时整张镜像）。
/// 按 `script` 循环：大部分时间静静探头，偶尔多探出一点、眨眼。
final class PetPeekFrames {
    static let framesPerSecond: Double = 4
    /// 0 静止 / 1 眨眼 / 2 往屏幕里多探出一格
    static let script = [0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 1, 0]

    private let sprites: PetPoseSprites
    /// 探头形象的不透明区域（归一化、未镜像）
    let normalizedBounds: CGRect

    init?(sprites: PetPoseSprites?) {
        guard
            let sprites,
            let first = sprites.image(named: Self.fileName(frame: 0)),
            let bounds = PixelArtScaler.opaqueBounds(of: first)
        else {
            return nil
        }
        self.sprites = sprites
        self.normalizedBounds = bounds
    }

    /// 第 `tick` 拍要显示的帧；缺帧时退回第 0 帧
    func image(atTick tick: Int) -> NSImage? {
        let frame = Self.script[((tick % Self.script.count) + Self.script.count) % Self.script.count]
        return sprites.image(named: Self.fileName(frame: frame)) ?? sprites.image(named: Self.fileName(frame: 0))
    }

    static func fileName(frame: Int) -> String {
        "peek_\(frame).png"
    }
}
