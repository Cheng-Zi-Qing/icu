import Foundation

/// 衣柜存档：`<App Support>/ICU/state/wardrobe.json`
struct WardrobeStore {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(appPaths: AppPaths) {
        self.init(fileURL: appPaths.stateDirectory.appendingPathComponent("wardrobe.json", isDirectory: false))
    }

    /// 没有存档、存档坏了都退回新用户的衣柜（坏档会记一条日志，不会让 app 起不来）
    func load(catalog: WardrobeCatalog) -> WardrobeState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .initial(for: catalog)
        }
        do {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: fileURL))
            return WardrobeState(jsonObject: object).sanitized(for: catalog)
        } catch {
            NSLog("[Wardrobe] could not read \(fileURL.path), starting fresh: \(error.localizedDescription)")
            return .initial(for: catalog)
        }
    }

    func save(_ state: WardrobeState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: state.jsonObject, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: fileURL, options: .atomic)
    }
}
