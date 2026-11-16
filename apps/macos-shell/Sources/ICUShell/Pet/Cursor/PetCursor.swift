import AppKit

/// 鼠标在桌宠哪个部位，就换成哪种手型
enum PetCursorKind: String, CaseIterable {
    /// 头上：平放的小手 + 小爱心（摸摸）
    case pat
    /// 肚子：挠痒痒的小手
    case tickle
    /// 背 / 屁股：戳一下
    case poke
    /// 身上：张开的手（可以拎起来）
    case grab
    /// 已经拖起来：握拳
    case grabbing

    /// 拖拽优先；点按阶段仍按部位显示手型，透明区域让下面的 App 管光标。
    static func kind(
        isDragging: Bool, overBody: Bool, zone: PetPokeZone?, activeClip: PetActionClip?
    ) -> PetCursorKind? {
        if isDragging { return .grabbing }
        guard overBody else { return nil }
        if activeClip == .petted { return .pat }
        if activeClip == .tickled { return .tickle }
        switch zone {
        case .head: return .pat
        case .belly: return .tickle
        case .back: return .poke
        default: return .grab
        }
    }

    /// 这次鼠标移动该怎么动光标
    enum Update: Equatable {
        /// 在桌宠身上：设成这种手型（每次都设，前台 App 可能改回去）
        case show(PetCursorKind)
        /// 刚离开桌宠身体：把箭头还回去，只做一次
        case restoreArrow
        /// 在透明区域上：下面是别的 App（比如终端的文字），光标归它管
        case leaveAlone
    }

    /// 透明区域每动一下都设箭头，会和下面 App 的光标来回抢，光标可能间歇变成白方块
    static func update(from previous: PetCursorKind?, to next: PetCursorKind?) -> Update {
        if let next { return .show(next) }
        return previous == nil ? .leaveAlone : .restoreArrow
    }

    /// 宠物没有像素光标素材时用系统自带的手型
    var systemCursor: NSCursor {
        switch self {
        case .pat, .tickle, .poke: return .pointingHand
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
            // 小位图按点尺寸放大，1 倍 / 2 倍屏的位图都提前备好：系统不用自己缩放
            // （后台换光标时它缩坏了会显示成白方块），像素边缘也清楚
            let pointSize = NSSize(width: manifest.pointSize, height: manifest.pointSize)
            let hotSpot = NSPoint(x: entry.hotSpot[0] * scale, y: entry.hotSpot[1] * scale)
            loaded[kind] = NSCursor(image: PixelArtScaler.pixelImage(image, pointSize: pointSize), hotSpot: hotSpot)
        }
        return loaded
    }
}
