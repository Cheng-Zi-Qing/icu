import AppKit

/// 衣柜用到的图：格子里的装扮小图、试衣台上的水豚、标题栏上趴着的那只。
/// 试衣台和标题栏都跟着「现在穿着什么」走
struct WardrobeArt {
    let itemIcon: (String) -> NSImage?
    let preview: (WardrobeState) -> NSImage?
    let decoration: (WardrobeState) -> NSImage?

    static let none = WardrobeArt(itemIcon: { _ in nil }, preview: { _ in nil }, decoration: { _ in nil })

    /// 从宠物素材里取：`ui/item_<装扮>.png`、换装后的 `idle` 第一帧、换装后的 `ui/bar_peek.png`
    static func live(locator: PetAssetLocator, petID: String, catalog: WardrobeCatalog) -> WardrobeArt {
        func image(_ directory: URL?, _ name: String) -> NSImage? {
            directory.flatMap { NSImage(contentsOf: $0.appendingPathComponent(name)) }
        }
        return WardrobeArt(
            itemIcon: { id in
                image(locator.resolvePoseSpriteDirectory(for: petID, subdirectory: "ui"), "item_\(id).png")
            },
            preview: { state in
                locator.resolveAnimation(for: petID, preferredAction: "idle", outfit: state.outfitID(in: catalog))?
                    .frameURLs.first
                    .flatMap(NSImage.init(contentsOf:))
            },
            decoration: { state in
                image(locator.resolvePoseSpriteDirectory(for: petID, subdirectory: "ui", outfit: state.outfitID(in: catalog)), "bar_peek.png")
            }
        )
    }
}
