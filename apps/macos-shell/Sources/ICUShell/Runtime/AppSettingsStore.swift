import Foundation

/// 读写 settings.json：优先用 App Support 下的用户配置，没有就退回仓库里的默认配置。
final class AppSettingsStore {
    private let appPaths: AppPaths?
    private let repoRootURL: URL
    private let fileManager: FileManager

    init(
        appPaths: AppPaths? = nil,
        repoRootURL: URL? = PetAssetLocator.inferredRepoRoot(),
        fileManager: FileManager = .default
    ) {
        self.appPaths = appPaths
        self.repoRootURL = repoRootURL
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        self.fileManager = fileManager
    }

    /// 贴边吸附配置；文件缺失或损坏时用默认值（不影响启动）
    func loadEdgeSnapSettings() -> EdgeSnapSettings {
        EdgeSnapSettings(settingsObject: loadRootObjectOrEmpty(section: "edge_snap"))
    }

    /// 体重、杯子容量、工作时长；读不到时用默认值
    func loadHealthProfile() -> HealthProfile {
        HealthProfile(settingsObject: loadRootObjectOrEmpty(section: "user"))
    }

    /// 护眼提醒间隔；读不到时用默认值
    func loadReminderTimerSettings() -> ReminderTimerSettings {
        ReminderTimerSettings(settingsObject: loadRootObjectOrEmpty(section: "timers"))
    }

    func saveHealthProfile(_ profile: HealthProfile) throws {
        try saveSection("user", mergingInto: [
            "body_weight": profile.bodyWeightKg,
            "cup_volume": profile.cupVolumeMl,
            "work_hours": profile.workHours,
        ])
    }

    func saveReminderTimerSettings(_ timers: ReminderTimerSettings) throws {
        try saveSection("timers", mergingInto: ["eye_mode": timers.eyeMode.rawValue, "eye_interval": timers.customEyeInterval])
    }

    func loadRootObject() throws -> [String: Any] {
        guard let existingURL = resolvedExistingSettingsFileURL() else {
            return [:]
        }

        let data = try Data(contentsOf: existingURL)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// 只改动 key 对应的那一段，其他配置原样保留
    func saveSection(_ key: String, _ value: [String: Any]) throws {
        let merged = try loadRootObject().merging([key: value]) { _, new in new }
        try fileManager.createDirectory(
            at: primarySettingsFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: primarySettingsFileURL, options: .atomic)
    }

    /// 只改这一段里的这几个 key，同一段里的其他 key 保留
    private func saveSection(_ key: String, mergingInto values: [String: Any]) throws {
        let existing = try loadRootObject()[key] as? [String: Any] ?? [:]
        try saveSection(key, existing.merging(values) { _, new in new })
    }

    private func loadRootObjectOrEmpty(section: String) -> [String: Any] {
        do {
            return try loadRootObject()
        } catch {
            NSLog("[AppSettingsStore] failed to read \(section) settings, using defaults: \(error.localizedDescription)")
            return [:]
        }
    }

    private var primarySettingsFileURL: URL {
        if let appPaths {
            return appPaths.configDirectory.appendingPathComponent("settings.json", isDirectory: false)
        }
        return repoSettingsFileURL
    }

    private var repoSettingsFileURL: URL {
        repoRootURL
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    private func resolvedExistingSettingsFileURL() -> URL? {
        let candidates = appPaths == nil ? [primarySettingsFileURL] : [primarySettingsFileURL, repoSettingsFileURL]
        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
    }
}
