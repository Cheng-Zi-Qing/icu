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
          "common": {
            "apply_button": "应用"
          }
        }
        """,
        to: baseURL
    )

    let catalog = try TextCatalog(baseURL: baseURL, overrideURL: nil)

    try expect(
        catalog.text(.commonApplyButton, fallback: "fallback") == "应用",
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
          "common": {
            "close_button": "关闭"
          },
          "theme_studio": {
            "tab_title": "主题风格"
          }
        }
        """,
        to: baseURL
    )
    try writeTextFile(
        """
        {
          "theme_studio": {
            "tab_title": "像素主题"
          }
        }
        """,
        to: overrideURL
    )

    let catalog = try TextCatalog(baseURL: baseURL, overrideURL: overrideURL)

    try expect(
        catalog.text(.themeStudioTabTitle, fallback: "fallback") == "像素主题",
        "text catalog should prefer the override when a matching key exists"
    )
    try expect(
        catalog.text(.commonCloseButton, fallback: "fallback") == "关闭",
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
        catalog.text(.speechStudioBubblePreviewTitle, fallback: "桌宠对话气泡预览") == "桌宠对话气泡预览",
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
            "eye_reminder": "看看远处，护护眼。"
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
            "eye_reminder": "看向远处，放松一下眼睛。"
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

func testUserFacingErrorCopyUsesInstalledCatalogForAvatarBridgeErrors() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "errors": {
            "avatar_generate_image_failed": "暂时无法生成形象动作，请检查图像模型配置或鉴权信息。"
          }
        }
        """,
        overrideJSON: """
        {
          "errors": {
            "avatar_generate_image_failed": "图像动作生成失败，请先检查模型和令牌。"
          }
        }
        """
    )

    let message = UserFacingErrorCopy.avatarMessage(
        for: AvatarBuilderBridgeError.executionFailed(command: "generate-image", details: "token missing")
    )

    try expect(
        message == "图像动作生成失败，请先检查模型和令牌。",
        "user-facing error copy should use the override for avatar bridge errors"
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
