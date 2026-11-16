import AppKit

/// 把衣柜接到 app 上：读装扮表和存档、开衣柜窗口、换装后保存并让桌宠换整套帧
@MainActor
final class WardrobeCoordinator {
    let catalog: WardrobeCatalog
    private let store: WardrobeStore
    private let art: WardrobeArt
    private let onOutfitChanged: (String?) -> Void
    private(set) var state: WardrobeState
    private(set) var windowController: WardrobeWindowController?

    /// - Parameters:
    ///   - catalogURL: `config/wardrobe.json`；读不到就用内置的表（橙子 + 草帽）
    ///   - onOutfitChanged: 头顶那件换了，桌宠要换成哪套帧（nil = 默认橙子）
    init(
        catalogURL: URL?,
        store: WardrobeStore,
        makeArt: (WardrobeCatalog) -> WardrobeArt,
        onOutfitChanged: @escaping (String?) -> Void
    ) {
        let catalog = Self.loadCatalog(from: catalogURL)
        self.catalog = catalog
        self.store = store
        self.art = makeArt(catalog)
        self.onOutfitChanged = onOutfitChanged
        self.state = store.load(catalog: catalog)
    }

    var outfitID: String? { state.outfitID(in: catalog) }

    /// 标题栏上趴着的那只，跟着现在的装扮（设置窗口也用）
    var decoration: NSImage? { art.decoration(state) }

    func open() {
        if let windowController {
            windowController.present()
            return
        }
        let controller = WardrobeWindowController(catalog: catalog, state: state, art: art) { [weak self] next in
            try self?.apply(next)
        }
        windowController = controller
        controller.present()
    }

    var unownedOutfits: [OutfitCandidate] { state.unownedOutfits(in: catalog) }

    /// 宝箱开出一件装扮：放进衣柜并保存，开着的衣柜窗口跟着刷新。存不上返回 false（这件就当没拿到）
    func grant(_ itemID: String) -> Bool {
        guard let next = state.granting(itemID, in: catalog) else { return false }
        do {
            try apply(next)
            windowController?.refresh(state: next)
            return true
        } catch {
            NSLog("[Wardrobe] failed to save a dropped outfit \(itemID): \(error.localizedDescription)")
            return false
        }
    }

    private func apply(_ next: WardrobeState) throws {
        try store.save(next)
        let outfitChanged = next.outfitID(in: catalog) != outfitID
        state = next
        if outfitChanged {
            onOutfitChanged(outfitID)
        }
    }

    private static func loadCatalog(from url: URL?) -> WardrobeCatalog {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return .builtIn }
        do {
            return WardrobeCatalog(jsonObject: try JSONSerialization.jsonObject(with: Data(contentsOf: url)))
        } catch {
            NSLog("[Wardrobe] could not read \(url.path), using the built-in catalog: \(error.localizedDescription)")
            return .builtIn
        }
    }
}
