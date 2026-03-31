import AppKit

final class StubGenerationConnectionTester: GenerationConnectionTesting {
    private let handler: (GenerationCapabilityConfig) throws -> Void

    private(set) var testedCapabilities: [GenerationCapabilityConfig] = []

    init(handler: @escaping (GenerationCapabilityConfig) throws -> Void = { _ in }) {
        self.handler = handler
    }

    func testConnection(capability: GenerationCapabilityConfig) throws {
        testedCapabilities.append(capability)
        try handler(capability)
    }
}

struct ManualConnectionTestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

func testGenerationConfigWindowUsesAccordionPanelsAndFooterSave() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "common": {
            "save_button": "保存"
          },
          "generation_config": {
            "window_title": "模型配置",
            "window_subtitle": "这里只配置模型，不负责生成与应用。",
            "provider_label": "服务商",
            "text_description_tab_title": "文本描述",
            "animation_avatar_tab_title": "动画形象",
            "code_generation_tab_title": "主题代码"
          }
        }
        """,
        overrideJSON: """
        {
          "generation_config": {
            "window_title": "模型工作台",
            "window_subtitle": "这里只配模型；生成、预览、应用都在创作工坊内完成。",
            "provider_label": "提供方",
            "text_description_tab_title": "文字意图",
            "animation_avatar_tab_title": "形象素材",
            "code_generation_tab_title": "主题样式代码"
          }
        }
        """
    )

    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    _ = try requireLabel(in: contentView, stringValue: "模型工作台")
    _ = try requireLabel(in: contentView, stringValue: "这里只配模型；生成、预览、应用都在创作工坊内完成。")
    _ = try requireLabel(in: contentView, stringValue: "提供方")

    let textToggle = try requireButton(in: contentView, identifier: generationConfigToggleIdentifier(.textDescription))
    let avatarToggle = try requireButton(in: contentView, identifier: generationConfigToggleIdentifier(.animationAvatar))
    let codeToggle = try requireButton(in: contentView, identifier: generationConfigToggleIdentifier(.codeGeneration))

    try expect(textToggle.title == "文字意图", "text-description accordion header should use the installed copy override")
    try expect(avatarToggle.title == "形象素材", "animation-avatar accordion header should use the installed copy override")
    try expect(codeToggle.title == "主题样式代码", "code-generation accordion header should use the installed copy override")

    let textStatus = try requireLabel(in: contentView, identifier: generationConfigHeaderStatusIdentifier(.textDescription))
    let avatarStatus = try requireLabel(in: contentView, identifier: generationConfigHeaderStatusIdentifier(.animationAvatar))
    let codeStatus = try requireLabel(in: contentView, identifier: generationConfigHeaderStatusIdentifier(.codeGeneration))

    try expect(textStatus.stringValue == "● 已配置", "configured text capability should surface a configured status in the accordion header")
    try expect(avatarStatus.stringValue == "未配置", "empty animation capability should surface an unconfigured status in the accordion header")
    try expect(codeStatus.stringValue == "● 已配置", "configured code capability should surface a configured status in the accordion header")

    let textContent = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.textDescription))
    let avatarContent = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.animationAvatar))
    let codeContent = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.codeGeneration))

    try expect(isVisibleForManualTest(textContent), "the first accordion panel should start expanded")
    try expect(!isVisibleForManualTest(avatarContent), "collapsed accordion panels should stay hidden")
    try expect(!isVisibleForManualTest(codeContent), "collapsed accordion panels should stay hidden")

    let footer = try requireView(in: contentView, identifier: generationConfigFooterIdentifier)
    let footerTitles = visibleButtonTitles(in: footer)
    try expect(
        Set(footerTitles) == Set(["取消", "保存"]) && footerTitles.count == 2,
        "generation config footer should expose only explicit cancel/save actions"
    )
}

func testGenerationConfigWindowAllowsMultipleExpandedPanelsWithoutRebuild() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    let textContentBefore = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.textDescription))
    let avatarContentBefore = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.animationAvatar))

    try expect(isVisibleForManualTest(textContentBefore), "text-description panel should start expanded")
    try expect(!isVisibleForManualTest(avatarContentBefore), "animation-avatar panel should start collapsed")

    try requireButton(in: contentView, identifier: generationConfigToggleIdentifier(.animationAvatar)).performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let textContentAfter = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.textDescription))
    let avatarContentAfter = try requireView(in: contentView, identifier: generationConfigContentIdentifier(.animationAvatar))

    try expect(textContentAfter === textContentBefore, "expanding a panel should not rebuild the already-mounted panel views")
    try expect(avatarContentAfter === avatarContentBefore, "accordion toggles should reuse the original hidden content containers")
    try expect(isVisibleForManualTest(textContentAfter), "opening another panel should not collapse the first one")
    try expect(isVisibleForManualTest(avatarContentAfter), "multiple accordion panels should stay expanded together")
}

func testGenerationConfigWindowUsesPlainAuthTokenFieldAndHidesOptionsJSON() throws {
    var settings = makeValidGenerationSettings()
    settings.codeGeneration.auth = ["api_key": "sk-live"]
    settings.codeGeneration.options = ["temperature": 0.6]
    settings.textDescription.options = ["temperature": 0.4]

    let settingsStore = try makeGenerationSettingsStore(settings: settings)
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try requireButton(in: contentView, identifier: generationConfigToggleIdentifier(.codeGeneration)).performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let providerPopup = try requirePopUpButton(in: contentView, identifier: generationConfigProviderIdentifier(.codeGeneration))
    let authField = try requireTextField(in: contentView, identifier: generationConfigAuthIdentifier(.codeGeneration))

    try expect(providerPopup.titleOfSelectedItem == "openai-compatible", "provider should use a dropdown instead of a freeform text field")
    try expect(authField.stringValue == "sk-live", "auth should be presented as a plain token field")

    try expect(
        findVisibleTextField(in: contentView, placeholder: "provider，如 ollama / huggingface / openai-compatible") == nil,
        "provider JSON-era freeform field should not be visible anymore"
    )
    try expect(
        findVisibleTextField(in: contentView, placeholder: "auth JSON，如 {\"api_key\":\"sk-xxx\"}") == nil,
        "auth JSON field should not be visible anywhere in the rewritten config window"
    )
    try expect(
        findVisibleTextField(in: contentView, placeholder: "options JSON，如 {\"temperature\":0.7}") == nil,
        "options JSON field should not be visible anywhere in the rewritten config window"
    )
    try expect(
        findLabel(in: contentView, stringValue: "认证 JSON") == nil,
        "auth JSON labels should be removed from the UI layer"
    )
    try expect(
        findLabel(in: contentView, stringValue: "选项 JSON") == nil,
        "options JSON labels should be removed from the UI layer"
    )
}

func testGenerationConfigWindowCancelDiscardsUnsavedChanges() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    let modelField = try requireTextField(in: contentView, identifier: generationConfigModelIdentifier(.textDescription))
    modelField.stringValue = "qwen3.5:32b"

    try requireButton(in: contentView, title: "取消").performClick(nil)
    try expect(
        waitForCondition(timeout: 0.2) { controller.window?.isVisible != true },
        "cancel should close the generation config window"
    )

    let reopenedController = coordinator.openGenerationConfig()
    guard let reopenedContentView = reopenedController.window?.contentView else {
        throw TestFailure(message: "reopened generation config window content view should exist")
    }

    let reopenedModelField = try requireTextField(in: reopenedContentView, identifier: generationConfigModelIdentifier(.textDescription))
    let persistedSettings = try settingsStore.load()

    try expect(reopenedController !== controller, "cancel should release the previous shared generation config window controller")
    try expect(reopenedModelField.stringValue == "ollama-mini", "cancel should discard unsaved draft changes before reopening")
    try expect(persistedSettings.textDescription.model == "ollama-mini", "cancel should not persist unsaved model edits")
}

func testGenerationConfigWindowShowsInlineConnectionStatusPerPanel() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let connectionTester = StubGenerationConnectionTester { capability in
        if capability.model == "gpt-4.1-mini" {
            throw ManualConnectionTestError(message: "bad auth")
        }
    }
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        connectionTester: connectionTester
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try requireButton(in: contentView, identifier: generationConfigToggleIdentifier(.codeGeneration)).performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try requireButton(in: contentView, identifier: generationConfigConnectionButtonIdentifier(.textDescription)).performClick(nil)
    try requireButton(in: contentView, identifier: generationConfigConnectionButtonIdentifier(.codeGeneration)).performClick(nil)

    try expect(
        waitForCondition(timeout: 0.5) {
            findLabel(in: contentView, identifier: generationConfigConnectionStatusIdentifier(.textDescription))?.stringValue == "● 已连接"
        },
        "successful connection tests should surface an inline per-panel success status"
    )
    try expect(
        waitForCondition(timeout: 0.5) {
            findLabel(in: contentView, identifier: generationConfigConnectionStatusIdentifier(.codeGeneration))?.stringValue == "✕ 连接失败: bad auth"
        },
        "failed connection tests should surface an inline per-panel error status"
    )
    try expect(
        connectionTester.testedCapabilities.map(\.model).sorted() == ["gpt-4.1-mini", "ollama-mini"],
        "connection tests should route through the injected generation coordinator dependency for each panel draft"
    )
}

func testGenerationConfigWindowUsesCompactFrame() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentSize = controller.window?.contentView?.frame.size else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try expect(
        contentSize == NSSize(width: 804, height: 520),
        "generation config window should keep the compact frame introduced by the workbench refresh"
    )
}

func testGenerationConfigWindowUsesThickerFieldDensity() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }
    contentView.layoutSubtreeIfNeeded()

    let modelField = try requireTextField(in: contentView, identifier: generationConfigModelIdentifier(.textDescription))

    let heightConstraint = modelField.constraints.first { constraint in
        constraint.firstAttribute == .height && constraint.firstItem === modelField
    }

    try expect(
        heightConstraint?.constant == 42,
        "model field should keep the thicker field height in the accordion layout"
    )
    try expect(modelField.frame.height == 42, "model field should render at the thicker field height")
}

func testGenerationConfigWindowKeepsCoreFieldsInUpperViewportBand() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }
    contentView.layoutSubtreeIfNeeded()

    let providerPopUp = try requirePopUpButton(in: contentView, identifier: generationConfigProviderIdentifier(.textDescription))
    let fieldFrameInContent = providerPopUp.convert(providerPopUp.bounds, to: contentView)
    let topGap = contentView.bounds.maxY - fieldFrameInContent.maxY

    try expect(
        topGap <= 170,
        "the first editable rows should stay in the upper viewport band after the accordion rewrite"
    )
}

func testGenerationCoordinatorReusesConfigWindowController() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let first = coordinator.openGenerationConfig()
    let second = coordinator.openGenerationConfig()

    try expect(first === second, "generation coordinator should reuse a shared config window controller instance")
}

func testGenerationConfigWindowLoadsSavedSettingsAndRestylesOnThemeChange() throws {
    var settings = makeValidGenerationSettings()
    settings.textDescription.model = "qwen3.5:35b"
    settings.codeGeneration.model = "gpt-4.1-mini"

    let repoRoot = try makeTemporaryDirectory()
    let appPaths = AppPaths(rootURL: repoRoot)
    try appPaths.ensureDirectories()
    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    try settingsStore.save(settings)
    let themeManager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)
    ThemeManager.installShared(themeManager)

    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    let controller = coordinator.openGenerationConfig()

    try expect(
        controller.formState.textDescription.model == "qwen3.5:35b",
        "generation config window should load persisted text-description model"
    )
    try expect(
        controller.formState.codeGeneration.model == "gpt-4.1-mini",
        "generation config window should load persisted code-generation model"
    )

    var pack = PixelTheme.pack
    pack.meta.id = "sunset"
    pack.tokens.colors.windowBackgroundHex = "#351B31"
    try themeManager.apply(pack)

    try expect(
        hexString(controller.window?.backgroundColor) == "#351B31",
        "generation config window should restyle itself when the active theme changes"
    )
}

func testGenerationConfigWindowDoesNotRenderThemeGenerationControls() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appPaths = AppPaths(rootURL: repoRoot)
    try appPaths.ensureDirectories()
    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    try settingsStore.save(makeValidGenerationSettings())
    let themeManager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)
    ThemeManager.installShared(themeManager)

    let coordinator = makeGenerationConfigCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager
    )
    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try expect(
        findButton(in: contentView, title: "生成并应用主题") == nil,
        "pure model config window should not expose a generate button"
    )
    try expect(
        findButton(in: contentView, title: "恢复默认像素风") == nil,
        "pure model config window should not expose theme reset controls"
    )
    try expect(
        findLabel(in: contentView, stringValue: "当前主题") == nil,
        "pure model config window should not render theme summary cards"
    )
}

func makeGenerationConfigCoordinator(
    settingsStore: GenerationSettingsStore,
    themeManager: ThemeManager,
    connectionTester: GenerationConnectionTesting? = nil
) -> GenerationCoordinator {
    let service = ThemeGenerationService(
        transport: StubGenerationTransport(
            results: [
                .success(#"{\"name\":\"Moss Pixel\",\"summary\":\"掌机感、苔藓绿、低饱和\"}"#),
                .success(validThemePackJSONString(id: "moss_pixel"))
            ]
        ),
        settingsStore: settingsStore,
        themeManager: themeManager
    )

    if let connectionTester {
        return GenerationCoordinator(
            settingsStore: settingsStore,
            themeManager: themeManager,
            generationService: service,
            connectionTester: connectionTester
        )
    }

    return GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )
}

func generationConfigToggleIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.toggle.\(kind.rawValue)"
}

func generationConfigHeaderStatusIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.headerStatus.\(kind.rawValue)"
}

func generationConfigContentIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.content.\(kind.rawValue)"
}

func generationConfigProviderIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.provider.\(kind.rawValue)"
}

func generationConfigModelIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.model.\(kind.rawValue)"
}

func generationConfigAuthIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.auth.\(kind.rawValue)"
}

func generationConfigConnectionButtonIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.connectionButton.\(kind.rawValue)"
}

func generationConfigConnectionStatusIdentifier(_ kind: GenerationCapabilityKind) -> String {
    "generationConfig.connectionStatus.\(kind.rawValue)"
}

let generationConfigFooterIdentifier = "generationConfig.footer"

func requireView(in root: NSView, identifier: String) throws -> NSView {
    if let view = findView(in: root, identifier: identifier) {
        return view
    }

    throw TestFailure(message: "expected view '\(identifier)' to exist")
}

func findView(in root: NSView, identifier: String) -> NSView? {
    ([root] + allSubviews(in: root)).first { $0.identifier?.rawValue == identifier }
}

func requireButton(in root: NSView, identifier: String) throws -> NSButton {
    if let button = ([root] + allSubviews(in: root))
        .compactMap({ $0 as? NSButton })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return button
    }

    throw TestFailure(message: "expected button '\(identifier)' to exist")
}

func requireLabel(in root: NSView, identifier: String) throws -> NSTextField {
    if let label = findLabel(in: root, identifier: identifier) {
        return label
    }

    throw TestFailure(message: "expected label '\(identifier)' to exist")
}

func findLabel(in root: NSView, identifier: String) -> NSTextField? {
    ([root] + allSubviews(in: root))
        .compactMap { $0 as? NSTextField }
        .first { isVisibleForManualTest($0) && $0.identifier?.rawValue == identifier }
}

func requirePopUpButton(in root: NSView, identifier: String) throws -> NSPopUpButton {
    if let button = ([root] + allSubviews(in: root))
        .compactMap({ $0 as? NSPopUpButton })
        .first(where: { isVisibleForManualTest($0) && $0.identifier?.rawValue == identifier }) {
        return button
    }

    throw TestFailure(message: "expected pop-up button '\(identifier)' to exist")
}

func visibleButtonTitles(in root: NSView) -> [String] {
    ([root] + allSubviews(in: root))
        .compactMap { $0 as? NSButton }
        .filter { isVisibleForManualTest($0) }
        .map(\.title)
}

func findVisibleTextField(in root: NSView, placeholder: String) -> NSTextField? {
    ([root] + allSubviews(in: root))
        .compactMap { $0 as? NSTextField }
        .first { isVisibleForManualTest($0) && $0.placeholderString == placeholder }
}

func findButton(in root: NSView, title: String) -> NSButton? {
    ([root] + allSubviews(in: root))
        .compactMap { $0 as? NSButton }
        .first { isVisibleForManualTest($0) && $0.title == title }
}

func findLabel(in root: NSView, stringValue: String) -> NSTextField? {
    ([root] + allSubviews(in: root))
        .compactMap { $0 as? NSTextField }
        .first { isVisibleForManualTest($0) && $0.stringValue == stringValue }
}
