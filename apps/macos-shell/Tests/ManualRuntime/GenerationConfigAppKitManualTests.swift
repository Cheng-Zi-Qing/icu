import AppKit

func testGenerationConfigWindowUsesInstalledCopyCatalogForVisibleLabels() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "generation_config": {
            "window_title": "模型配置",
            "window_subtitle": "这里只配置模型，不负责生成与应用。",
            "basic_section_title": "基础配置",
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
            "basic_section_title": "基础信息",
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
    _ = try requireLabel(in: contentView, stringValue: "基础信息")
    _ = try requireLabel(in: contentView, stringValue: "提供方")
}

func testGenerationConfigWindowUsesModelTabsByDefault() throws {
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
    _ = try requireLabel(in: contentView, stringValue: "基础配置")
    _ = try requireLabel(in: contentView, stringValue: "服务商")

    try expect(
        findButton(in: contentView, title: "主题生成") == nil,
        "model config window should not expose the theme-generation tab anymore"
    )
    try expect(
        findButton(in: contentView, title: "生成并应用主题") == nil,
        "model config window should not expose generate/apply actions"
    )
}

func testGenerationConfigWindowCapabilityDetailUsesBasicAndAdvancedSections() throws {
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

    try requireButton(in: contentView, title: "文本描述").performClick(nil)

    _ = try requireLabel(in: contentView, stringValue: "基础配置")
    _ = try requireLabel(in: contentView, stringValue: "服务商")
    _ = try requireLabel(in: contentView, stringValue: "模型")
    _ = try requireLabel(in: contentView, stringValue: "接口地址")
    _ = try requireTextField(in: contentView, placeholder: "provider，如 ollama / huggingface / openai-compatible")
    _ = try requireTextField(in: contentView, placeholder: "model")
    _ = try requireTextField(in: contentView, placeholder: "base_url")
    let advancedToggle = try requireButton(in: contentView, title: "显示高级设置")

    try expect(
        findTextField(in: contentView, placeholder: "auth JSON，如 {\"api_key\":\"sk-xxx\"}") == nil,
        "advanced auth field should stay hidden until expanded"
    )
    try expect(
        findTextField(in: contentView, placeholder: "options JSON，如 {\"temperature\":0.7}") == nil,
        "advanced options field should stay hidden until expanded"
    )
    try expect(
        findLabel(in: contentView, stringValue: "高级设置") == nil,
        "advanced section title should stay hidden until expanded"
    )
    try expect(
        findLabel(in: contentView, stringValue: "认证 JSON") == nil,
        "advanced auth label should stay hidden until expanded"
    )
    try expect(
        findLabel(in: contentView, stringValue: "选项 JSON") == nil,
        "advanced options label should stay hidden until expanded"
    )

    advancedToggle.performClick(nil)

    _ = try requireLabel(in: contentView, stringValue: "高级设置")
    _ = try requireLabel(in: contentView, stringValue: "认证 JSON")
    _ = try requireLabel(in: contentView, stringValue: "选项 JSON")
    _ = try requireTextField(in: contentView, placeholder: "auth JSON，如 {\"api_key\":\"sk-xxx\"}")
    _ = try requireTextField(in: contentView, placeholder: "options JSON，如 {\"temperature\":0.7}")
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

    let providerField = try requireTextField(
        in: contentView,
        placeholder: "provider，如 ollama / huggingface / openai-compatible"
    )
    let providerFrameInContent = providerField.convert(providerField.bounds, to: contentView)
    let topGap = contentView.bounds.maxY - providerFrameInContent.maxY

    try expect(
        topGap <= 170,
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

func findButton(in root: NSView, title: String) -> NSButton? {
    allSubviews(in: root).compactMap { $0 as? NSButton }.first { $0.title == title }
}

func findLabel(in root: NSView, stringValue: String) -> NSTextField? {
    allSubviews(in: root).compactMap { $0 as? NSTextField }.first { $0.stringValue == stringValue }
}
