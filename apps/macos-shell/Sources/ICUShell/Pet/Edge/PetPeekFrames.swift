import AppKit

/// 贴边探头的帧：`<pet>/edge/peek_<n>.png`（正面）和 `turn_<n>.png`（头转成侧面）
///
/// 图里画布的右边就是屏幕边（贴左边时整张镜像）。播放顺序见 `PetPeekScript`。
final class PetPeekFrames {
    static let framesPerSecond = PetPeekScript.framesPerSecond

    private let sprites: PetPoseSprites
    /// 探头形象的不透明区域（归一化、未镜像）
    let normalizedBounds: CGRect

    init?(sprites: PetPoseSprites?) {
        guard
            let sprites,
            let first = sprites.image(named: PetPeekFrame.rest.fileName),
            let bounds = PixelArtScaler.opaqueBounds(of: first)
        else {
            return nil
        }
        self.sprites = sprites
        self.normalizedBounds = bounds
    }

    /// 某一帧的图；缺帧时退回正面静止帧
    func image(for frame: PetPeekFrame) -> NSImage? {
        sprites.image(named: frame.fileName) ?? sprites.image(named: PetPeekFrame.rest.fileName)
    }
}
