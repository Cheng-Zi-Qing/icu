import Foundation

extension Notification.Name {
    static let icuThemeDidChange = Notification.Name("ICUShell.ThemeDidChange")
}

final class ThemeManager {
    private(set) var currentTheme: ThemeDefinition

    private let appPaths: AppPaths
    private let settingsStore: GenerationSettingsStore
    private let fileManager: FileManager
    private let notificationCenter: NotificationCenter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private static var sharedStorage: ThemeManager?

    static var shared: ThemeManager {
        guard let manager = sharedStorage else {
            fatalError("ThemeManager.shared was accessed before installShared(_:)")
        }
        return manager
    }

    static func installShared(_ manager: ThemeManager) {
        sharedStorage = manager
    }

    init(
        appPaths: AppPaths,
        settingsStore: GenerationSettingsStore,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default
    ) throws {
        self.appPaths = appPaths
        self.settingsStore = settingsStore
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        currentTheme = PixelTheme.definition

        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        try appPaths.ensureDirectories(fileManager: fileManager)
        try fileManager.createDirectory(at: appPaths.themesDirectory, withIntermediateDirectories: true)
        try loadThemeFromSettings()
    }

    func apply(_ pack: ThemePack) throws {
        try pack.validate()
        try fileManager.createDirectory(at: appPaths.themesDirectory, withIntermediateDirectories: true)

        let data = try encoder.encode(pack)
        let fileURL = appPaths.themesDirectory.appendingPathComponent("\(pack.meta.id).json", isDirectory: false)
        try data.write(to: fileURL, options: .atomic)

        try settingsStore.saveActiveThemeID(pack.meta.id)
        currentTheme = ThemeDefinition(pack: pack)
        notificationCenter.post(name: .icuThemeDidChange, object: self)
    }

    func resetToPixelDefault() throws {
        try settingsStore.saveActiveThemeID(PixelTheme.id)
        currentTheme = PixelTheme.definition
        notificationCenter.post(name: .icuThemeDidChange, object: self)
    }

    private func loadThemeFromSettings() throws {
        let activeThemeID = try settingsStore.loadActiveThemeID()
        guard let activeThemeID, !activeThemeID.isEmpty else {
            currentTheme = PixelTheme.definition
            return
        }

        if activeThemeID == PixelTheme.id {
            currentTheme = PixelTheme.definition
            return
        }

        if let persistedTheme = try loadPersistedTheme(id: activeThemeID) {
            currentTheme = persistedTheme
            return
        }

        currentTheme = PixelTheme.definition
        try settingsStore.saveActiveThemeID(PixelTheme.id)
    }

    private func loadPersistedTheme(id: String) throws -> ThemeDefinition? {
        let fileURL = appPaths.themesDirectory.appendingPathComponent("\(id).json", isDirectory: false)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let pack = try decoder.decode(ThemePack.self, from: data)
            try pack.validate()
            return ThemeDefinition(pack: pack)
        } catch {
            return nil
        }
    }
}
