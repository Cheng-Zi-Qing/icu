import AppKit

/// 鼠标在桌宠哪个部位，就换成哪种手型
enum PetCursorKind: String, CaseIterable {
    /// 头上：平放的小手 + 小爱心（摸摸）
    case pat
    /// 身上：张开的手（可以拎起来）
    case grab
    /// 按住 / 拖着走：握拳
    case grabbing

    /// - Parameters:
    ///   - isGrabbing: 正按着桌宠或正在拖（快速拖时鼠标会短暂跑出身体，拳头不能松）
    ///   - overBody: 鼠标在不透明的像素上
    ///   - overHead: 鼠标在头那一截上
    /// - Returns: nil 表示用普通箭头（透明区域本来就点不到桌宠）
    static func kind(isGrabbing: Bool, overBody: Bool, overHead: Bool) -> PetCursorKind? {
        if isGrabbing { return .grabbing }
        guard overBody else { return nil }
        return overHead ? .pat : .grab
    }

    /// 宠物没有像素光标素材时用系统自带的手型
    var systemCursor: NSCursor {
        switch self {
        case .pat: return .pointingHand
        case .grab: return .openHand
        case .grabbing: return .closedHand
        }
    }
}

/// 某只宠物的像素光标：`<pet>/cursor/` 下的 PNG + cursors.json（热点、尺寸），
/// 由 tools/pixel_pets/capybara/build.mjs 生成。缺哪个就用系统手型顶上。
final class PetCursorSet {
    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let file: String
            let hotSpot: [Double]
        }

        let pixelSize: Double
        let pointSize: Double
        let cursors: [String: Entry]
    }

    private var cursors: [PetCursorKind: NSCursor] = [:]

    init(directory: URL?, fileManager: FileManager = .default) {
        guard let directory else { return }
        let manifestURL = directory.appendingPathComponent("cursors.json", isDirectory: false)
        guard fileManager.fileExists(atPath: manifestURL.path) else { return }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
            cursors = Self.load(manifest, from: directory)
        } catch {
            print("[PetCursorSet] Failed to read \(manifestURL.path): \(error); using system cursors")
        }
    }

    func cursor(for kind: PetCursorKind) -> NSCursor {
        cursors[kind] ?? kind.systemCursor
    }

    private static func load(_ manifest: Manifest, from directory: URL) -> [PetCursorKind: NSCursor] {
        let scale = manifest.pointSize / max(manifest.pixelSize, 1)
        var loaded: [PetCursorKind: NSCursor] = [:]
        for kind in PetCursorKind.allCases {
            guard let entry = manifest.cursors[kind.rawValue], entry.hotSpot.count == 2 else { continue }
            let url = directory.appendingPathComponent(entry.file, isDirectory: false)
            guard let image = NSImage(contentsOf: url) else {
                print("[PetCursorSet] Missing cursor image \(url.path); using the system cursor")
                continue
            }
            // 位图是 3 倍导出的，按点尺寸显示：Retina 下像素边缘仍然清楚
            image.size = NSSize(width: manifest.pointSize, height: manifest.pointSize)
            let hotSpot = NSPoint(x: entry.hotSpot[0] * scale, y: entry.hotSpot[1] * scale)
            loaded[kind] = NSCursor(image: image, hotSpot: hotSpot)
        }
        return loaded
    }
}
