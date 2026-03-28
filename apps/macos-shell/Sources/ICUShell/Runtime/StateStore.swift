import Foundation

final class StateStore {
    private let paths: AppPaths
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(paths: AppPaths, fileManager: FileManager = .default) throws {
        self.paths = paths
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try paths.ensureDirectories(fileManager: fileManager)
    }

    func load() throws -> PersistedRuntimeState {
        if !fileManager.fileExists(atPath: paths.currentStateFile.path) {
            let defaultState = PersistedRuntimeState.idle()
            try save(defaultState)
            return defaultState
        }

        let data = try Data(contentsOf: paths.currentStateFile)
        return try decoder.decode(PersistedRuntimeState.self, from: data)
    }

    func save(_ state: PersistedRuntimeState) throws {
        let data = try encoder.encode(state)
        try data.write(to: paths.currentStateFile, options: .atomic)
    }
}
