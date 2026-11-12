import Foundation

/// 背包存档：`<App Support>/ICU/state/loot.json`
struct LootStore {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(appPaths: AppPaths) {
        self.init(fileURL: appPaths.stateDirectory.appendingPathComponent("loot.json", isDirectory: false))
    }

    /// 没有存档就是空背包。存档坏了：原文件改名留着（`loot.json.corrupt-<时间>`），从空背包开始，不让 app 起不来
    func load(config: LootConfig, now: Date = .now) -> LootState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        do {
            let state = try Self.decoder.decode(LootState.self, from: Data(contentsOf: fileURL))
            return state.sanitized(for: config)
        } catch {
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("loot.json.corrupt-\(Int(now.timeIntervalSince1970))", isDirectory: false)
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
                NSLog("[Loot] could not read \(fileURL.path) (\(error.localizedDescription)); kept it as \(backup.lastPathComponent) and started an empty backpack")
            } catch let moveError {
                NSLog("[Loot] could not read \(fileURL.path) (\(error.localizedDescription)) nor set it aside (\(moveError.localizedDescription)); starting an empty backpack")
            }
            return .empty
        }
    }

    func save(_ state: LootState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
