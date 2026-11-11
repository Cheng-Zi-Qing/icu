import Foundation

struct TestFailure: Error {
    let message: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(message: message)
    }
}

func makeTemporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

func writeTextFile(_ content: String, to url: URL) throws {
    try content.write(to: url, atomically: true, encoding: .utf8)
}

func ensureBaseCopyCatalogCoversAllSourceReferences(fileManager: FileManager = .default) throws {
    let repoRootURL = inferredManualTestRepoRootURL(fileManager: fileManager)
    let baseCopyKeys = try loadFlattenedBaseCopyKeys(repoRootURL: repoRootURL)
    let referencedCopyKeys = try collectReferencedCopyKeys(repoRootURL: repoRootURL, fileManager: fileManager)
    let missingKeys = referencedCopyKeys.subtracting(baseCopyKeys).sorted()

    try expect(
        missingKeys.isEmpty,
        "base copy catalog is missing source-referenced keys: \(missingKeys.joined(separator: ", "))"
    )
}

func inferredManualTestRepoRootURL(fileManager: FileManager = .default) -> URL {
    PetAssetLocator.inferredRepoRoot()
        ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
}

func loadFlattenedBaseCopyKeys(repoRootURL: URL) throws -> Set<String> {
    let baseURL = repoRootURL
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("copy", isDirectory: true)
        .appendingPathComponent("base.json", isDirectory: false)
    let data = try Data(contentsOf: baseURL)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw TestFailure(message: "base copy catalog should decode to a JSON object")
    }
    return flattenJSONStringKeys(object: object, prefix: nil)
}

func flattenJSONStringKeys(object: [String: Any], prefix: String?) -> Set<String> {
    var flattened: Set<String> = []

    for (key, value) in object {
        let fullKey = prefix.map { "\($0).\(key)" } ?? key

        if value is String {
            flattened.insert(fullKey)
        } else if let nested = value as? [String: Any] {
            flattened.formUnion(flattenJSONStringKeys(object: nested, prefix: fullKey))
        }
    }

    return flattened
}

func collectReferencedCopyKeys(
    repoRootURL: URL,
    fileManager: FileManager = .default
) throws -> Set<String> {
    let sourcesURL = repoRootURL
        .appendingPathComponent("apps", isDirectory: true)
        .appendingPathComponent("macos-shell", isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("ICUShell", isDirectory: true)

    guard let enumerator = fileManager.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) else {
        throw TestFailure(message: "failed to enumerate Swift source files for copy integrity check")
    }

    let patterns = [
        #"TextCatalog\.shared\.text\(\s*"([a-z_]+(?:\.[a-z0-9_]+)+)""#,
        #"(?:copy|formatCopy|text)\(\s*"([a-z_]+(?:\.[a-z0-9_]+)+)""#,
        #"case\s+\w+\s*=\s*"([a-z_]+(?:\.[a-z0-9_]+)+)""#,
        #"static\s+let\s+\w+\s*=\s*"([a-z_]+(?:\.[a-z0-9_]+)+)""#,
    ]

    var keys: Set<String> = []

    for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "swift" else {
            continue
        }

        let source = try String(contentsOf: fileURL, encoding: .utf8)
        for pattern in patterns {
            keys.formUnion(try regexMatches(in: source, pattern: pattern))
        }
    }

    return keys
}

func regexMatches(in text: String, pattern: String) throws -> Set<String> {
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let nsText = text as NSString

    return Set(regex.matches(in: text, options: [], range: range).compactMap { match in
        guard match.numberOfRanges > 1 else {
            return nil
        }
        return nsText.substring(with: match.range(at: 1))
    })
}

func makeInstalledTextCatalog(
    baseJSON: String,
    overrideJSON: String? = nil
) throws -> TextCatalog {
    let root = try makeTemporaryDirectory()
    let baseURL = root.appendingPathComponent("base.json", isDirectory: false)
    try writeTextFile(baseJSON, to: baseURL)

    let overrideURL: URL?
    if let overrideJSON {
        let activeURL = root.appendingPathComponent("active.json", isDirectory: false)
        try writeTextFile(overrideJSON, to: activeURL)
        overrideURL = activeURL
    } else {
        overrideURL = nil
    }

    let catalog = try TextCatalog(baseURL: baseURL, overrideURL: overrideURL)
    TextCatalog.installShared(catalog)
    return catalog
}

func testTextCatalogReturnsBaseValueWhenNoOverrideExists() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let baseURL = root.appendingPathComponent("base.json", isDirectory: false)
    try writeTextFile(
        """
        {
          "menu": {
            "start_work": "开始工作"
          }
        }
        """,
        to: baseURL
    )

    let catalog = try TextCatalog(baseURL: baseURL, overrideURL: nil)

    try expect(
        catalog.text(.menuStartWork, fallback: "fallback") == "开始工作",
        "text catalog should read the base value when no override exists"
    )
}

func testTextCatalogUsesOverrideWithoutDroppingBaseFallback() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let baseURL = root.appendingPathComponent("base.json", isDirectory: false)
    let overrideURL = root.appendingPathComponent("active.json", isDirectory: false)
    try writeTextFile(
        """
        {
          "menu": {
            "show_pet": "显示桌宠",
            "quit_app": "退出"
          }
        }
        """,
        to: baseURL
    )
    try writeTextFile(
        """
        {
          "menu": {
            "show_pet": "召唤桌宠"
          }
        }
        """,
        to: overrideURL
    )

    let catalog = try TextCatalog(baseURL: baseURL, overrideURL: overrideURL)

    try expect(
        catalog.text(.menuShowPet, fallback: "fallback") == "召唤桌宠",
        "text catalog should prefer the override when a matching key exists"
    )
    try expect(
        catalog.text(.menuQuitApp, fallback: "fallback") == "退出",
        "text catalog should keep base values for keys missing in the override"
    )
}

func testTextCatalogFallsBackToCallerDefaultForUnknownKey() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let baseURL = root.appendingPathComponent("base.json", isDirectory: false)
    try writeTextFile("{}", to: baseURL)

    let catalog = try TextCatalog(baseURL: baseURL, overrideURL: nil)

    try expect(
        catalog.text(.menuHidePet, fallback: "藏起来") == "藏起来",
        "text catalog should return the caller fallback when the key is missing everywhere"
    )
}

func testBaseCopyCatalogContainsAllSourceReferencedKeys() throws {
    try ensureBaseCopyCatalogCoversAllSourceReferences()
}

func testDesktopPetCopyUsesInstalledCatalogForSessionMessages() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "pet": {
            "status_idle": "待机中",
            "status_working": "工作中",
            "status_focus": "专注中",
            "status_break": "暂离中",
            "focus_end_light": "抬头缓一缓，再接着做。",
            "focus_end_heavy": "这一段够久了，先休息一下。",
            "stop_work_message": "收工，歇会儿。",
            "eye_reminder": "看看远处，护护眼。",
            "hydration_reminder": "喝口水，慢慢来。"
          }
        }
        """,
        overrideJSON: """
        {
          "pet": {
            "status_idle": "空闲待命",
            "status_working": "正在推进",
            "status_focus": "沉浸专注",
            "status_break": "暂时离开",
            "focus_end_light": "抬头看远一点，再继续。",
            "focus_end_heavy": "已经持续很久了，先完整休息一下。",
            "stop_work_message": "今天先到这里。",
            "eye_reminder": "看向远处，放松一下眼睛。",
            "hydration_reminder": "喝口水，慢一点也没关系。"
          }
        }
        """
    )

    try expect(
        DesktopPetCopy.statusText(for: .idle) == "空闲待命",
        "desktop pet copy should use the override for idle status"
    )
    try expect(
        DesktopPetCopy.statusText(for: .working) == "正在推进",
        "desktop pet copy should use the override for working status"
    )
    try expect(
        DesktopPetCopy.statusText(for: .focus) == "沉浸专注",
        "desktop pet copy should use the override for focus status"
    )
    try expect(
        DesktopPetCopy.statusText(for: .breakState) == "暂时离开",
        "desktop pet copy should use the override for break status"
    )
    try expect(
        DesktopPetCopy.focusSuggestionMessage(for: .light) == "抬头看远一点，再继续。",
        "desktop pet copy should use the override for the light focus suggestion"
    )
    try expect(
        DesktopPetCopy.focusSuggestionMessage(for: .heavy) == "已经持续很久了，先完整休息一下。",
        "desktop pet copy should use the override for the heavy focus suggestion"
    )
    try expect(
        DesktopPetCopy.focusSuggestionMessage(for: nil) == nil,
        "desktop pet copy should keep nil focus suggestions as nil"
    )
    try expect(
        DesktopPetCopy.stopWorkMessage() == "今天先到这里。",
        "desktop pet copy should use the override for the stop work message"
    )
    try expect(
        DesktopPetCopy.eyeReminderMessage() == "看向远处，放松一下眼睛。",
        "desktop pet copy should use the override for the eye reminder"
    )
    try expect(
        DesktopPetCopy.hydrationReminderMessage() == "喝口水，慢一点也没关系。",
        "desktop pet copy should use the override for the hydration reminder"
    )
}

func testUserFacingErrorCopyUsesInstalledCatalogForWorkSessionErrors() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "errors": {
            "work_invalid_enter_focus": "只有在工作中才能进入专注。"
          }
        }
        """,
        overrideJSON: """
        {
          "errors": {
            "work_invalid_enter_focus": "现在还不能进入专注，先开始工作。"
          }
        }
        """
    )

    let message = UserFacingErrorCopy.desktopPetMessage(
        for: WorkSessionError.invalidTransition(from: .idle, attempted: "enterFocus")
    )

    try expect(
        message == "现在还不能进入专注，先开始工作。",
        "user-facing error copy should use the override for work session transition errors"
    )
}

func testStateStoreCreatesICUDirectoriesAndDefaultsToIdle() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let paths = AppPaths(rootURL: root)
    let store = try StateStore(paths: paths)
    let current = try store.load()

    try expect(FileManager.default.fileExists(atPath: paths.rootURL.path), "root directory should exist")
    try expect(FileManager.default.fileExists(atPath: paths.stateDirectory.path), "state directory should exist")
    try expect(current.state == .idle, "default state should be idle")
}

// MARK: - 中英双语文案

private func repoCatalog(language: AppLanguage) throws -> TextCatalog {
    try TextCatalog.live(repoRootURL: inferredManualTestRepoRootURL(), language: language)
}

private func containsCJK(_ text: String) throws -> Bool {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return try NSRegularExpression(pattern: "[\u{4e00}-\u{9fff}]").firstMatch(in: text, options: [], range: range) != nil
}

private func collectCopyKeys(
    repoRootURL: URL,
    patterns: [String],
    fileManager: FileManager = .default
) throws -> Set<String> {
    let sourcesURL = repoRootURL
        .appendingPathComponent("apps", isDirectory: true)
        .appendingPathComponent("macos-shell", isDirectory: true)
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("ICUShell", isDirectory: true)

    guard let enumerator = fileManager.enumerator(at: sourcesURL, includingPropertiesForKeys: nil) else {
        throw TestFailure(message: "failed to enumerate Swift source files for copy integrity check")
    }

    var keys: Set<String> = []
    for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "swift" else { continue }
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        for pattern in patterns {
            keys.formUnion(try regexMatches(in: source, pattern: pattern))
        }
    }
    return keys
}

private func loadFlattenedCopyKeys(from url: URL) throws -> Set<String> {
    let data = try Data(contentsOf: url)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw TestFailure(message: "\(url.lastPathComponent) should decode to a JSON object")
    }
    return try collectKeys(object: object, prefix: nil)
}

private func collectKeys(object: Any, prefix: String?) throws -> Set<String> {
    var keys: Set<String> = []
    switch object {
    case let dictionary as [String: Any]:
        for (key, value) in dictionary {
            keys.formUnion(try collectKeys(object: value, prefix: prefix.map { "\($0).\(key)" } ?? key))
        }
    case let array as [Any]:
        guard let prefix else { throw TestFailure(message: "a top-level JSON array cannot be copy") }
        for (index, value) in array.enumerated() {
            keys.formUnion(try collectKeys(object: value, prefix: "\(prefix).\(index)"))
        }
    default:
        if let prefix { keys.insert(prefix) }
    }
    return keys
}

/// `en.json` 必须把 `base.json` 的每个 key 都翻掉：漏一个就会掉回中文
func testEnglishCopyCatalogTranslatesEveryBaseKey() throws {
    let chinese = try repoCatalog(language: .chinese)
    let english = try repoCatalog(language: .english)

    let missingKeys = Set(chinese.keys).subtracting(english.keys).sorted()
    try expect(missingKeys.isEmpty, "en.json is missing keys: \(missingKeys.joined(separator: ", "))")

    let untranslated = try english.keys.filter { try containsCJK(english.text($0)) }
    try expect(
        untranslated.isEmpty,
        "en.json still falls back to Chinese for: \(untranslated.joined(separator: ", "))"
    )
    try expect(english.text(.menuStartWork) == "I'm Starting Work", "the English catalog reads English")
}

func testUserVisibleCopyKeysExistInBothCatalogs() throws {
    let chinese = try repoCatalog(language: .chinese)
    let english = try repoCatalog(language: .english)
    for (name, catalog) in [("base.json", chinese), ("en.json", english)] {
        let catalogKeys = Set(catalog.keys)
        let missing = UserVisibleCopyKey.allCases.map(\.rawValue).filter { !catalogKeys.contains($0) }
        try expect(missing.isEmpty, "\(name) is missing menu copy keys: \(missing.joined(separator: ", "))")
    }
}

/// 衣柜的装扮和套装名字是按 id 现查文案的，配置里有的都得有对应 key
func testWardrobeCopyKeysExistInBothCatalogs() throws {
    let wardrobeURL = inferredManualTestRepoRootURL()
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("wardrobe.json", isDirectory: false)
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: wardrobeURL)) as? [String: Any]
    let itemIDs = (object?["items"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
    let suitIDs = (object?["suits"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
    try expect(!itemIDs.isEmpty && !suitIDs.isEmpty, "the wardrobe config should list items and suits")

    let keys = itemIDs.map { "wardrobe.item.\($0)" }
        + suitIDs.map { "wardrobe.suit.\($0)" }
        + WardrobeSlot.allCases.map { "wardrobe.slot.\($0.rawValue)" }
    for (name, catalog) in [("base.json", try repoCatalog(language: .chinese)), ("en.json", try repoCatalog(language: .english))] {
        let catalogKeys = Set(catalog.keys)
        let missing = keys.filter { !catalogKeys.contains($0) }
        try expect(missing.isEmpty, "\(name) is missing wardrobe copy keys: \(missing.joined(separator: ", "))")
    }
}

/// 带占位符和文案池的 key 也得不漏：现有自查只认 `text("…"` 那种写法
func testBaseCopyCatalogContainsFormattedAndPoolKeys() throws {
    let repoRootURL = inferredManualTestRepoRootURL()
    let baseKeys = try loadFlattenedCopyKeys(from: repoRootURL
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("copy", isDirectory: true)
        .appendingPathComponent("base.json", isDirectory: false))
    let formattedKeys = try collectCopyKeys(
        repoRootURL: repoRootURL,
        patterns: [#"\.format\(\s*"([a-z_]+(?:\.[a-z0-9_]+)+)""#]
    )
    let poolPrefixes = try collectCopyKeys(
        repoRootURL: repoRootURL,
        patterns: [#"\.texts\(\s*"([a-z_]+(?:\.[a-z0-9_]+)+)""#]
    )
    let poolKeys = poolPrefixes.map { "\($0).0" }
    let missing = formattedKeys.union(poolKeys).subtracting(baseKeys).sorted()
    try expect(missing.isEmpty, "base copy catalog is missing formatted or pool keys: \(missing.joined(separator: ", "))")
}

func testChineseCatalogKeepsMenuAndReminderWording() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    TextCatalog.installShared(try repoCatalog(language: .chinese))

    try expect(StatusItemMenuAction.showTodayReport.title == "今日报告…", "menu bar report entry")
    try expect(DesktopPetMenuAction.startWork.title == "我要上班", "pet menu start work: you say it, not the pet")
    try expect(DesktopPetCopy.statusText(for: .working) == "陪你上班", "the chip under the pet speaks for the pet")
    try expect(DesktopPetMenuAction.openWardrobe.title == "衣柜", "pet menu wardrobe")
    try expect(DesktopPetCopy.eyeReminderMessage() == "看看远处，护护眼。", "eye reminder message")
    try expect(AgentActivity.statusText(tool: nil) == "思考中", "agent thinking label")
    try expect(ReminderQuips.nope.first == "我就不", "signature skip line")

    let card = ReminderCardContent(
        payload: ReminderPresentationPayload(id: UUID(), type: .hydration, text: "x", restSeconds: 0),
        cups: CupProgress(done: 3, goal: 6),
        pick: { _ in 0 }
    )
    try expect(card.detail(remaining: 0) == "第 4/6 杯", "cup progress wording (got \(card.detail(remaining: 0)))")
}

func testEnglishCatalogDrivesMenuAndReminderWording() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    TextCatalog.installShared(try repoCatalog(language: .english))

    try expect(StatusItemMenuAction.showTodayReport.title == "Today's Report…", "menu bar report entry")
    try expect(DesktopPetMenuAction.startWork.title == "I'm Starting Work", "pet menu start work: you say it, not the pet")
    try expect(DesktopPetCopy.statusText(for: .working) == "With you", "the chip under the pet speaks for the pet")
    try expect(DesktopPetMenuAction.openWardrobe.title == "Wardrobe", "pet menu wardrobe")
    try expect(DesktopPetCopy.eyeReminderMessage() == "Look far away, rest your eyes.", "eye reminder message")
    try expect(AgentActivity.statusText(tool: nil) == "Thinking", "agent thinking label")
    try expect(ReminderQuips.hydration.lines.count == 8, "the English quip pool keeps all lines")

    let card = ReminderCardContent(
        payload: ReminderPresentationPayload(id: UUID(), type: .hydration, text: "x", restSeconds: 0),
        cups: CupProgress(done: 3, goal: 6),
        pick: { _ in 0 }
    )
    try expect(card.detail(remaining: 0) == "Cup 4/6", "cup progress wording (got \(card.detail(remaining: 0)))")
    try expect(!textContainsCJK(card.title), "the card title is English (got \(card.title))")
}

private func textContainsCJK(_ text: String) -> Bool {
    (try? containsCJK(text)) ?? false
}

func testAppSettingsStoreSavesLanguageWithoutDroppingOtherKeys() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let configDir = root.appendingPathComponent("config", isDirectory: true)
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    let settingsURL = configDir.appendingPathComponent("settings.json", isDirectory: false)
    try writeTextFile(#"{"edge_snap": {"enabled": false}}"#, to: settingsURL)

    let store = AppSettingsStore(repoRootURL: root)
    try expect(store.loadLanguage() == .chinese, "no language key yet reads as Chinese")
    try store.saveLanguage(.english)
    try expect(store.loadLanguage() == .english, "the chosen language round-trips")
    try expect(store.loadEdgeSnapSettings().isEnabled == false, "other sections are kept")

    try writeTextFile(#"{"language": "fr"}"#, to: settingsURL)
    try expect(store.loadLanguage() == .chinese, "an unknown language falls back to Chinese")
}

/// 切语言走的就是这条路：写 settings.json → 重读文案 → 发通知
func testReloadSharedFollowsTheLanguageInSettings() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let copyDir = root.appendingPathComponent("config/copy", isDirectory: true)
    try FileManager.default.createDirectory(at: copyDir, withIntermediateDirectories: true)
    try writeTextFile(#"{"menu": {"start_work": "开始工作"}}"#, to: copyDir.appendingPathComponent("base.json"))
    try writeTextFile(#"{"menu": {"start_work": "Start Work"}}"#, to: copyDir.appendingPathComponent("en.json"))

    let store = AppSettingsStore(repoRootURL: root)
    TextCatalog.installShared(try TextCatalog.live(repoRootURL: root))
    try expect(DesktopPetMenuAction.startWork.title == "开始工作", "no language key yet reads Chinese")

    try store.saveLanguage(.english)
    var notified = 0
    let observer = NotificationCenter.default.addObserver(forName: .icuCopyDidChange, object: nil, queue: nil) { _ in
        notified += 1
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    try TextCatalog.reloadShared(repoRootURL: root)
    try expect(DesktopPetMenuAction.startWork.title == "Start Work", "switching to English picks up en.json")
    try expect(notified == 1, "reloading the copy posts one change notification (got \(notified))")

    try store.saveLanguage(.chinese)
    try TextCatalog.reloadShared(repoRootURL: root)
    try expect(DesktopPetMenuAction.startWork.title == "开始工作", "switching back reads Chinese again")
}
