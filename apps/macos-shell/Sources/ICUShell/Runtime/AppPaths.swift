import Foundation

struct AppPaths {
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    static func live(fileManager: FileManager = .default) throws -> AppPaths {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return AppPaths(rootURL: appSupport.appendingPathComponent("ICU", isDirectory: true))
    }

    var configDirectory: URL {
        rootURL.appendingPathComponent("config", isDirectory: true)
    }

    var stateDirectory: URL {
        rootURL.appendingPathComponent("state", isDirectory: true)
    }

    var assetsDirectory: URL {
        rootURL.appendingPathComponent("assets", isDirectory: true)
    }

    var builderSessionsDirectory: URL {
        rootURL.appendingPathComponent("builder_sessions", isDirectory: true)
    }

    var logsDirectory: URL {
        rootURL.appendingPathComponent("logs", isDirectory: true)
    }

    var themesDirectory: URL {
        stateDirectory.appendingPathComponent("themes", isDirectory: true)
    }

    var currentStateFile: URL {
        stateDirectory.appendingPathComponent("current_state.json", isDirectory: false)
    }

    func ensureDirectories(fileManager: FileManager = .default) throws {
        let directories = [
            rootURL,
            configDirectory,
            stateDirectory,
            themesDirectory,
            assetsDirectory,
            builderSessionsDirectory,
            logsDirectory,
        ]

        for directory in directories {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
