import AppKit

func testGenerationConfigWindowUsesWorkbenchChromeAndInstalledCopy() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "generation_config": {
            "window_title": "模型配置",
            "window_subtitle": "这里只配置模型，不负责生成与应用。",
            "basic_button": "基础入口",
            "advanced_button": "高级入口",
            "save_button": "立即保存",
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
            "window_subtitle": "这里只配模型；生成、预览、应用都在更换形象页。",
            "basic_button": "核心参数",
            "advanced_button": "JSON 编辑器",
            "save_button": "保存这组模型",
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    _ = try requireLabel(in: contentView, stringValue: "模型工作台")
    _ = try requireLabel(in: contentView, stringValue: "这里只配模型；生成、预览、应用都在更换形象页。")
    _ = try requireButton(in: contentView, title: "文字意图")
    _ = try requireButton(in: contentView, title: "形象素材")
    _ = try requireButton(in: contentView, title: "主题样式代码")
    _ = try requireActionButton(in: contentView, title: "核心参数")
    _ = try requireActionButton(in: contentView, title: "JSON 编辑器")
    _ = try requireActionButton(in: contentView, title: "保存这组模型")
    _ = try requireLabel(in: contentView, stringValue: "提供方")
}

func testGenerationConfigWindowUsesPopupProviderAndCollapsedAdvancedEditorsByDefault() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    _ = try requireButton(in: contentView, title: "文本描述")
    _ = try requireButton(in: contentView, title: "动画形象")
    _ = try requireButton(in: contentView, title: "主题代码")
    _ = try requireActionButton(in: contentView, title: "基础")
    _ = try requireActionButton(in: contentView, title: "高级")
    _ = try requireActionButton(in: contentView, title: "保存")
    _ = try requireLabel(in: contentView, stringValue: "服务商")
    _ = try requireLabel(in: contentView, stringValue: "模型")
    _ = try requireLabel(in: contentView, stringValue: "接口地址")

    let providerPopup = try requirePopupButton(in: contentView, identifier: "generationConfigProviderPopup")
    try expect(
        providerPopup.itemTitles == ["ollama", "huggingface", "openai-compatible"],
        "provider popup should expose all providers"
    )
    _ = try requireTextField(in: contentView, placeholder: "model")
    _ = try requireTextField(in: contentView, placeholder: "base_url")

    try expect(
        findTextField(in: contentView, placeholder: "provider，如 ollama / huggingface / openai-compatible") == nil,
        "provider should render as a popup instead of a free-text field"
    )
    try expect(
        findTextView(in: contentView, identifier: "generationConfigAuthEditor") == nil,
        "auth editor should stay hidden by default"
    )
    try expect(
        findTextView(in: contentView, identifier: "generationConfigOptionsEditor") == nil,
        "options editor should stay hidden by default"
    )
}

func testGenerationConfigWindowShowsMultilineJSONEditorsWhenAdvancedIsSelected() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appPaths = AppPaths(rootURL: repoRoot)
    try appPaths.ensureDirectories()
    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    try settingsStore.save(makeValidGenerationSettings())
    let themeManager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)
    ThemeManager.installShared(themeManager)
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    _ = try requireActionButton(in: contentView, title: "基础")
    let advancedToggle = try requireActionButton(in: contentView, title: "高级")

    try expect(findTextView(in: contentView, identifier: "generationConfigAuthEditor") == nil, "auth editor should stay hidden by default")

    advancedToggle.performClick(nil)

    _ = try requireLabel(in: contentView, stringValue: "认证 JSON")
    _ = try requireLabel(in: contentView, stringValue: "选项 JSON")
    _ = try requireTextView(in: contentView, identifier: "generationConfigAuthEditor")
    _ = try requireTextView(in: contentView, identifier: "generationConfigOptionsEditor")
}

func testGenerationConfigWindowPreservesDraftAcrossNavigationSwitches() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try requireButton(in: contentView, title: "文本描述").performClick(nil)
    let modelField = try requireTextField(in: contentView, placeholder: "model")
    modelField.stringValue = "qwen3.5:32b"

    try requireButton(in: contentView, title: "主题代码").performClick(nil)
    try requireButton(in: contentView, title: "文本描述").performClick(nil)

    let restoredModelField = try requireTextField(in: contentView, placeholder: "model")
    try expect(
        restoredModelField.stringValue == "qwen3.5:32b",
        "draft capability edits should survive navigation between config sections"
    )
}

func testGenerationConfigWindowUsesCompactFrame() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentSize = controller.window?.contentView?.frame.size else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try expect(
        contentSize == NSSize(width: 804, height: 520),
        "generation config window should use a tighter default content size"
    )
}

func testGenerationConfigWindowUsesThickerFieldDensity() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }
    contentView.layoutSubtreeIfNeeded()

    let modelField = try requireTextField(in: contentView, placeholder: "model")

    let heightConstraint = modelField.constraints.first { constraint in
        constraint.firstAttribute == .height && constraint.firstItem === modelField
    }

    try expect(
        heightConstraint?.constant == 42,
        "model field should use the thicker field height"
    )
    try expect(modelField.frame.height == 42, "model field should render at the thicker field height")
}

func testGenerationConfigWindowKeepsCoreFieldsInUpperViewportBand() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )

    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }
    contentView.layoutSubtreeIfNeeded()

    let providerPopup = try requirePopupButton(in: contentView, identifier: "generationConfigProviderPopup")
    let providerFrameInContent = providerPopup.convert(providerPopup.bounds, to: contentView)
    let topGap = contentView.bounds.maxY - providerFrameInContent.maxY

    try expect(
        topGap <= 220,
        "provider field should stay within the upper viewport band for field-first density"
    )
}

func testGenerationCoordinatorReusesConfigWindowController() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
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
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
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

func findTextField(in root: NSView, placeholder: String) -> NSTextField? {
    allSubviews(in: root)
        .compactMap { $0 as? NSTextField }
        .first { $0.placeholderString == placeholder }
}

func requireTextField(in root: NSView, placeholder: String) throws -> NSTextField {
    if let field = findTextField(in: root, placeholder: placeholder) {
        return field
    }

    throw TestFailure(message: "expected text field with placeholder '\(placeholder)' to exist")
}

private func findTextView(in root: NSView, identifier: String) -> NSTextView? {
    allSubviews(in: root)
        .compactMap { $0 as? NSTextView }
        .first { $0.identifier?.rawValue == identifier }
}

private func requirePopupButton(in root: NSView, identifier: String) throws -> NSPopUpButton {
    if let popup = allSubviews(in: root)
        .compactMap({ $0 as? NSPopUpButton })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return popup
    }

    throw TestFailure(message: "expected popup button '\(identifier)' to exist")
}

func findButton(in root: NSView, title: String) -> NSButton? {
    allSubviews(in: root).compactMap { $0 as? NSButton }.first { $0.title == title }
}

func findLabel(in root: NSView, stringValue: String) -> NSTextField? {
    allSubviews(in: root).compactMap { $0 as? NSTextField }.first { $0.stringValue == stringValue }
}
