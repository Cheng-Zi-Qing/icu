import AppKit

/// 姿势帧：`<pet>/drag/`（拖拽）或 `<pet>/edge/`（贴边探头）目录下按姿势命名的 PNG
///
///   hold_<tilt>.png             tilt ∈ -2...2
///   dizzy_<tilt>_<twinkle>.png  twinkle ∈ 0...1
///   land_<frame>.png            frame ∈ 0...1
///
/// 缺少某张帧时返回 nil，调用方保持当前画面，只做变形效果。
final class PetPoseSprites {
    private let directory: URL
    private let canvasPointSize: NSSize
    private let fileManager: FileManager
    private var cache: [String: NSImage] = [:]

    init(directory: URL, canvasPointSize: NSSize, fileManager: FileManager = .default) {
        self.directory = directory
        self.canvasPointSize = canvasPointSize
        self.fileManager = fileManager
    }

    static func fileName(for pose: DragPose) -> String? {
        switch pose {
        case .none:
            return nil
        case let .hold(tilt):
            return "hold_\(tilt).png"
        case let .dizzy(tilt, twinkle):
            return "dizzy_\(tilt)_\(twinkle).png"
        case let .landing(frame):
            return "land_\(frame).png"
        }
    }

    func image(for pose: DragPose) -> NSImage? {
        guard let name = Self.fileName(for: pose) else {
            return nil
        }
        return image(named: name)
    }

    /// 按文件名取姿势帧（贴边探头等非拖拽姿势也用它）
    func image(named name: String) -> NSImage? {
        if let cached = cache[name] {
            return cached
        }

        let url = directory.appendingPathComponent(name, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        guard let image = NSImage(contentsOf: url) else {
            print("[PetPoseSprites] Failed to decode pose sprite at: \(url.path)")
            return nil
        }

        let scaled = PixelArtScaler.upscaledForDisplay(image, canvasPointSize: canvasPointSize)
        cache[name] = scaled
        return scaled
    }
}
