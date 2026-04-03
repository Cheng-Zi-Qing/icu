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
            "default_config_title": "默认配置",
            "api_key_label": "API Key",
            "test_connection_button": "测试连接",
            "customize_button": "Customize",
            "restore_default_button": "Restore Default",
            "advanced_params_button": "Advanced Params",
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
            "default_config_title": "默认配置卡",
            "api_key_label": "API Secret",
            "test_connection_button": "连通检查",
            "customize_button": "个性化",
            "restore_default_button": "还原默认",
            "advanced_params_button": "高级参数",
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
    _ = try requireButton(in: contentView, title: "OpenAI")
    _ = try requireButton(in: contentView, title: "Anthropic")
    _ = try requireButton(in: contentView, title: "Ollama")
    _ = try requireButton(in: contentView, title: "HuggingFace")
    _ = try requireButton(in: contentView, title: "OpenAI-Compatible")
    _ = try requireLabel(in: contentView, stringValue: "默认配置卡")
    _ = try requireLabel(in: contentView, stringValue: "API Secret")
    _ = try requireActionButton(in: contentView, title: "连通检查")
    _ = try requireActionButton(in: contentView, title: "个性化")
    _ = try requireActionButton(in: contentView, title: "高级参数")
    _ = try requireLabel(in: contentView, stringValue: "文字意图")
    _ = try requireLabel(in: contentView, stringValue: "形象素材")
    _ = try requireLabel(in: contentView, stringValue: "主题样式代码")
}

func testGenerationConfigWindowRendersProviderRailAndDefaultConfigCard() throws {
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

    _ = try requireButton(in: contentView, title: "OpenAI")
    _ = try requireButton(in: contentView, title: "Anthropic")
    _ = try requireButton(in: contentView, title: "Ollama")
    _ = try requireButton(in: contentView, title: "HuggingFace")
    _ = try requireButton(in: contentView, title: "OpenAI-Compatible")
    _ = try requireLabel(in: contentView, stringValue: "Default Config")
    _ = try requireLabel(in: contentView, stringValue: "API Key")
    _ = try requireLabel(in: contentView, stringValue: "Base URL")
    _ = try requireActionButton(in: contentView, title: "Test Connection")
    _ = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultAPIKeyField")
    _ = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultBaseURLField")
}

func testGenerationConfigWindowShowsCapabilityCardsWithCustomizeAndCollapsedAdvancedParamsByDefault() throws {
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

    _ = try requireLabel(in: contentView, stringValue: "文本描述")
    _ = try requireLabel(in: contentView, stringValue: "动画形象")
    _ = try requireLabel(in: contentView, stringValue: "主题代码")
    _ = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionProviderPopup")
    _ = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionPresetPopup")
    _ = try requireTextField(in: contentView, identifier: "generationConfigTextDescriptionModelField")
    _ = try requireButton(in: contentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Customize")
    let advancedButton = try requireButton(in: contentView, identifier: "generationConfigTextDescriptionAdvancedButton", title: "Advanced Params")
    _ = try requireLabel(in: contentView, stringValue: "Using Default Config")
    try expect(
        advancedButton.isEnabled == false,
        "Advanced Params should stay disabled until the card enters customize mode"
    )

    try expect(
        findTextField(in: contentView, identifier: "generationConfigTextDescriptionAPIKeyField") == nil,
        "capability customization fields should stay hidden before the card enters customize mode"
    )
    try expect(
        findTextView(in: contentView, identifier: "generationConfigTextDescriptionOptionsEditor") == nil,
        "Advanced Params should stay collapsed by default"
    )

    try clickButton(requireButton(in: contentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Customize"))

    guard let rebuiltContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after entering customize mode")
    }

    _ = try requireTextField(in: rebuiltContentView, identifier: "generationConfigTextDescriptionAPIKeyField")
    _ = try requireTextField(in: rebuiltContentView, identifier: "generationConfigTextDescriptionBaseURLField")
    _ = try requireButton(in: rebuiltContentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Restore Default")
    let rebuiltAdvancedButton = try requireButton(
        in: rebuiltContentView,
        identifier: "generationConfigTextDescriptionAdvancedButton",
        title: "Advanced Params"
    )
    _ = try requireLabel(in: rebuiltContentView, stringValue: "Customized")
    try expect(
        rebuiltAdvancedButton.isEnabled,
        "Advanced Params should enable once the card enters customize mode"
    )
    try expect(
        findTextView(in: rebuiltContentView, identifier: "generationConfigTextDescriptionOptionsEditor") == nil,
        "Advanced Params should remain collapsed even after customization fields are revealed"
    )

    try clickButton(rebuiltAdvancedButton)

    guard let advancedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after expanding advanced params")
    }

    _ = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionHeadersEditor")
    _ = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionAuthEditor")
    _ = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionOptionsEditor")
}

func testGenerationConfigWindowFiltersProviderOptionsPerCapability() throws {
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

    let textPopup = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionProviderPopup")
    let avatarPopup = try requirePopupButton(in: contentView, identifier: "generationConfigAnimationAvatarProviderPopup")
    let codePopup = try requirePopupButton(in: contentView, identifier: "generationConfigCodeGenerationProviderPopup")

    try expect(
        textPopup.itemTitles == ["OpenAI", "Anthropic", "Ollama", "OpenAI-Compatible"],
        "text description capability should only offer providers supported by the router"
    )
    try expect(
        avatarPopup.itemTitles == ["OpenAI", "HuggingFace", "OpenAI-Compatible"],
        "animation avatar capability should filter provider choices to image-capable providers"
    )
    try expect(
        codePopup.itemTitles == ["OpenAI", "Anthropic", "Ollama", "OpenAI-Compatible"],
        "code generation capability should only offer providers supported by the router"
    )
}

func testGenerationConfigWindowProviderRailUpdatesRecommendedPresetChoices() throws {
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

    let initialTextPresetPopup = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionPresetPopup")
    try expect(
        initialTextPresetPopup.itemTitles.contains("gpt-4.1-mini"),
        "OpenAI rail should seed OpenAI text presets by default"
    )

    try clickButton(requireButton(in: contentView, title: "Anthropic"))

    guard let anthropicContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after switching provider rail")
    }

    let textPresetPopup = try requirePopupButton(in: anthropicContentView, identifier: "generationConfigTextDescriptionPresetPopup")
    let codePresetPopup = try requirePopupButton(in: anthropicContentView, identifier: "generationConfigCodeGenerationPresetPopup")

    try expect(
        textPresetPopup.itemTitles.contains("claude-3-5-haiku-latest"),
        "Anthropic rail should update the text capability card with Anthropic preset recommendations"
    )
    try expect(
        codePresetPopup.itemTitles.contains("claude-3-7-sonnet-latest"),
        "Anthropic rail should update the code capability card with Anthropic preset recommendations"
    )
}

func testGenerationConfigWindowTestConnectionReportsProviderSpecificStatusWithoutDiscardingDrafts() throws {
    let originalFactory = GenerationConfigWindowController.makeConnectionTester
    let tester = StubGenerationConnectionTester(results: [
        .success(()),
        .failure(GenerationRouteError.requestFailed("HTTP 401: invalid_api_key"))
    ])
    GenerationConfigWindowController.makeConnectionTester = { tester }
    defer { GenerationConfigWindowController.makeConnectionTester = originalFactory }

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

    let openAIBaseURLField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultBaseURLField")
    updateTextField(openAIBaseURLField, value: "https://api.openai.com/v1")
    try clickButton(requireActionButton(in: contentView, title: "Test Connection"))

    try expect(
        controller.statusLabel.stringValue == "OpenAI connection succeeded.",
        "successful provider tests should report a provider-specific success message"
    )
    try expect(
        tester.requests.first?.provider == .openAI,
        "test connection should probe the currently selected provider"
    )
    try expect(
        tester.requests.first?.defaults.baseURL == "https://api.openai.com/v1",
        "test connection should read the visible provider-default draft instead of stale persisted values"
    )
    try expect(
        openAIBaseURLField.stringValue == "https://api.openai.com/v1",
        "successful connection tests should keep provider-default drafts visible"
    )

    try clickButton(requireButton(in: contentView, title: "Anthropic"))

    guard let anthropicContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after switching provider rail")
    }

    let anthropicBaseURLField = try requireTextField(in: anthropicContentView, identifier: "generationConfigProviderDefaultBaseURLField")
    updateTextField(anthropicBaseURLField, value: "https://api.anthropic.com/v1")
    try clickButton(requireActionButton(in: anthropicContentView, title: "Test Connection"))

    try expect(
        controller.statusLabel.stringValue == "Anthropic connection failed: Generation request failed: HTTP 401: invalid_api_key",
        "failed provider tests should surface provider-specific failure details in the status area"
    )
    try expect(
        tester.requests.last?.provider == .anthropic,
        "test connection should follow the currently selected rail provider after switching"
    )
    try expect(
        anthropicBaseURLField.stringValue == "https://api.anthropic.com/v1",
        "failed connection tests should not wipe visible provider-default drafts"
    )
}

func testGenerationConfigWindowPreservesDraftAcrossProviderRailSwitches() throws {
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

    let openAIBaseURLField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultBaseURLField")
    updateTextField(openAIBaseURLField, value: "https://api.openai.com/v1")

    try clickButton(requireButton(in: contentView, title: "Anthropic"))

    guard let anthropicContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after switching provider rail")
    }

    let anthropicBaseURLField = try requireTextField(in: anthropicContentView, identifier: "generationConfigProviderDefaultBaseURLField")
    updateTextField(anthropicBaseURLField, value: "https://api.anthropic.com")

    try clickButton(requireButton(in: anthropicContentView, title: "OpenAI"))

    guard let restoredContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after returning to the original rail item")
    }

    let restoredBaseURLField = try requireTextField(in: restoredContentView, identifier: "generationConfigProviderDefaultBaseURLField")
    try expect(
        restoredBaseURLField.stringValue == "https://api.openai.com/v1",
        "provider default drafts should survive switching between rail selections"
    )
}

func testGenerationConfigWindowKeepsCoreFieldsHighWhenDetailCopyGetsLong() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "generation_config": {
            "provider_default_openai_helper": "把共享的 OpenAI key 和入口放在这里。"
          }
        }
        """,
        overrideJSON: """
        {
          "generation_config": {
            "provider_default_openai_helper": "这是一段明显更长的说明文案，用来验证 provider-first 工作台在面对更长的服务商帮助文案时，依然会把 API Key 和 Base URL 这些默认配置字段保持在上方可见区域，而不是被帮助文本无限向下挤压。"
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
    contentView.layoutSubtreeIfNeeded()

    let baseURLField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultBaseURLField")
    let fieldFrameInContent = baseURLField.convert(baseURLField.bounds, to: contentView)
    let topGap = contentView.bounds.maxY - fieldFrameInContent.maxY

    try expect(
        topGap <= 220,
        "long provider helper copy should not push the core default-config field out of the upper viewport band"
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
        contentSize == NSSize(width: 860, height: 540),
        "generation config window should stay compact but give the workbench more horizontal breathing room"
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

    let modelField = try requireTextField(in: contentView, identifier: "generationConfigTextDescriptionModelField")

    let heightConstraint = modelField.constraints.first { constraint in
        constraint.firstAttribute == .height && constraint.firstItem === modelField
    }

    try expect(
        heightConstraint?.constant == 42,
        "model field should use the thicker field height"
    )
    try expect(modelField.frame.height == 42, "model field should render at the thicker field height")
}

func testGenerationConfigWindowStretchesEditableControlsAcrossWorkbenchWidth() throws {
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

    let defaultBaseURLField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultBaseURLField")
    let providerPopup = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionProviderPopup")
    let modelField = try requireTextField(in: contentView, identifier: "generationConfigTextDescriptionModelField")

    try expect(
        abs(providerPopup.frame.width - modelField.frame.width) <= 2,
        "model field should stretch to the same workbench row width as the provider popup"
    )
    try expect(
        abs(defaultBaseURLField.frame.width - modelField.frame.width) <= 2,
        "provider default base URL field should stretch to the same workbench row width as the capability card controls"
    )
    try expect(
        modelField.frame.width >= 540,
        "compact workbench should still give the primary editable controls enough width to avoid a cramped input feel"
    )

    try clickButton(requireButton(in: contentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Customize"))

    guard let customizedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after entering customize mode")
    }

    try clickButton(requireButton(
        in: customizedContentView,
        identifier: "generationConfigTextDescriptionAdvancedButton",
        title: "Advanced Params"
    ))

    guard let advancedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after expanding advanced params")
    }
    advancedContentView.layoutSubtreeIfNeeded()

    let customBaseURLField = try requireTextField(in: advancedContentView, identifier: "generationConfigTextDescriptionBaseURLField")
    let authEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionAuthEditor")
    let optionsEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionOptionsEditor")
    guard
        let authScrollView = authEditor.enclosingScrollView,
        let optionsScrollView = optionsEditor.enclosingScrollView
    else {
        throw TestFailure(message: "advanced JSON editors should remain embedded in scroll views")
    }

    try expect(
        abs(customBaseURLField.frame.width - authScrollView.frame.width) <= 2,
        "auth editor should stretch to the same workbench row width as the provider popup"
    )
    try expect(
        abs(customBaseURLField.frame.width - optionsScrollView.frame.width) <= 2,
        "options editor should stretch to the same workbench row width as the provider popup"
    )
    try expect(
        authScrollView.frame.height >= 132,
        "advanced auth JSON editor should be tall enough for compact-but-usable multiline editing"
    )
    try expect(
        optionsScrollView.frame.height >= 132,
        "advanced options JSON editor should be tall enough for compact-but-usable multiline editing"
    )
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

    let apiKeyField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultAPIKeyField")
    let fieldFrameInContent = apiKeyField.convert(apiKeyField.bounds, to: contentView)
    let topGap = contentView.bounds.maxY - fieldFrameInContent.maxY

    try expect(
        topGap <= 220,
        "provider default card should stay within the upper viewport band for field-first density"
    )
}

func testGenerationConfigWindowSavePersistsProviderDefaultsAndCapabilityCustomizationsAndMarksLaterEditsUnsaved() throws {
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

    let providerDefaultAPIKeyField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultAPIKeyField")
    let providerDefaultBaseURLField = try requireTextField(in: contentView, identifier: "generationConfigProviderDefaultBaseURLField")
    updateTextField(providerDefaultAPIKeyField, value: "openai-default-secret")
    updateTextField(providerDefaultBaseURLField, value: "https://api.openai.com/v1")

    let textProviderPopup = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionProviderPopup")
    try selectPopupItem(textProviderPopup, title: "OpenAI")

    let presetPopup = try requirePopupButton(in: contentView, identifier: "generationConfigTextDescriptionPresetPopup")
    try selectPopupItem(presetPopup, title: "gpt-4.1-mini")

    let modelField = try requireTextField(in: contentView, identifier: "generationConfigTextDescriptionModelField")
    updateTextField(modelField, value: "gpt-4.1-mini")

    try clickButton(requireButton(in: contentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Customize"))

    guard let customizedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after entering customize mode")
    }

    let customAPIKeyField = try requireTextField(in: customizedContentView, identifier: "generationConfigTextDescriptionAPIKeyField")
    let customBaseURLField = try requireTextField(in: customizedContentView, identifier: "generationConfigTextDescriptionBaseURLField")
    updateTextField(customAPIKeyField, value: "text-secret")
    updateTextField(customBaseURLField, value: "https://text.example/v1")

    try clickButton(requireButton(
        in: customizedContentView,
        identifier: "generationConfigTextDescriptionAdvancedButton",
        title: "Advanced Params"
    ))

    guard let advancedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after expanding advanced params")
    }

    let headersEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionHeadersEditor")
    let authEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionAuthEditor")
    let optionsEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionOptionsEditor")
    updateTextView(headersEditor, value: #"{"x-team":"foundation"}"#)
    updateTextView(authEditor, value: #"{"api_key":"text-secret","workspace":"icu"}"#)
    updateTextView(optionsEditor, value: #"{"temperature":0.4}"#)

    try clickButton(requireActionButton(in: advancedContentView, title: "保存"))

    let savedStatus = try requireLabel(in: controller.window?.contentView ?? contentView, stringValue: "模型配置已保存。")
    try expect(savedStatus.stringValue == "模型配置已保存。", "save should report success after persisting the current draft")

    let savedSettings = try settingsStore.load()
    try expect(savedSettings.providerDefaults[.openAI]?.apiKey == "openai-default-secret", "save should persist provider default API keys")
    try expect(savedSettings.providerDefaults[.openAI]?.baseURL == "https://api.openai.com/v1", "save should persist provider default base URLs")
    try expect(savedSettings.textDescription.provider == .openAI, "save should persist the popup-selected provider")
    try expect(savedSettings.textDescription.preset == "gpt-4.1-mini", "save should persist the selected preset")
    try expect(savedSettings.textDescription.model == "gpt-4.1-mini", "save should persist the edited custom model")
    try expect(savedSettings.textDescription.customized, "save should mark customized capability cards as customized")
    try expect(savedSettings.textDescription.custom?.baseURL == "https://text.example/v1", "save should persist customized base URLs in the custom transport block")
    try expect(savedSettings.textDescription.custom?.apiKey == "text-secret", "save should persist customized API keys in the custom transport block")
    try expect(savedSettings.textDescription.custom?.headers == ["x-team": "foundation"], "save should persist header JSON from the multiline editor")
    try expect(savedSettings.textDescription.custom?.auth == ["api_key": "text-secret", "workspace": "icu"], "save should persist auth JSON from the multiline editor")
    try expect(savedSettings.textDescription.options == ["temperature": 0.4], "save should persist options JSON from the multiline editor")

    updateTextField(modelField, value: "gpt-4.1-mini-v2")
    _ = try requireLabel(in: controller.window?.contentView ?? contentView, stringValue: "这里只配置模型，不负责生成与应用。")
    try expect(
        findLabel(in: controller.window?.contentView ?? contentView, stringValue: "模型配置已保存。") == nil,
        "editing after a successful save should clear the stale success message"
    )
}

func testGenerationConfigWindowSaveFailureKeepsAdvancedDraftVisibleForRepair() throws {
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

    try clickButton(requireButton(in: contentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Customize"))

    guard let customizedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after entering customize mode")
    }

    try clickButton(requireButton(
        in: customizedContentView,
        identifier: "generationConfigTextDescriptionAdvancedButton",
        title: "Advanced Params"
    ))

    guard let advancedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after expanding advanced params")
    }

    let authEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionAuthEditor")
    updateTextView(authEditor, value: #"{"api_key":}"#)

    try clickButton(requireActionButton(in: advancedContentView, title: "保存"))

    let failedContentView = controller.window?.contentView ?? advancedContentView
    _ = try requireLabel(in: failedContentView, stringValue: "认证 JSON 需要填写合法的 JSON 对象。")
    let authEditorAfterFailedSave = try requireTextView(in: failedContentView, identifier: "generationConfigTextDescriptionAuthEditor")
    try expect(
        authEditorAfterFailedSave.string == #"{"api_key":}"#,
        "failed saves should keep the invalid auth draft visible for repair"
    )
    _ = try requireTextView(in: failedContentView, identifier: "generationConfigTextDescriptionOptionsEditor")
}

func testGenerationConfigWindowRejectsBooleanOptionsAndKeepsDraftVisibleForRepair() throws {
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

    try clickButton(requireButton(in: contentView, identifier: "generationConfigTextDescriptionCustomizeButton", title: "Customize"))

    guard let customizedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after entering customize mode")
    }

    try clickButton(requireButton(
        in: customizedContentView,
        identifier: "generationConfigTextDescriptionAdvancedButton",
        title: "Advanced Params"
    ))

    guard let advancedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after expanding advanced params")
    }

    let optionsEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigTextDescriptionOptionsEditor")
    updateTextView(optionsEditor, value: #"{"stream":true}"#)

    try clickButton(requireActionButton(in: advancedContentView, title: "保存"))

    let failedContentView = controller.window?.contentView ?? advancedContentView
    _ = try requireLabel(in: failedContentView, stringValue: "选项 JSON 中的字段 'stream' 格式不正确。")
    let optionsEditorAfterFailedSave = try requireTextView(in: failedContentView, identifier: "generationConfigTextDescriptionOptionsEditor")
    try expect(
        optionsEditorAfterFailedSave.string == #"{"stream":true}"#,
        "boolean options should stay visible after a failed save so the user can repair them"
    )

    let persistedSettings = try settingsStore.load()
    try expect(
        persistedSettings.textDescription.options["stream"] == nil,
        "failed saves should not silently persist boolean options as 1.0 or 0.0"
    )
}

func testGenerationConfigWindowPreservesInvalidJSONDraftAcrossThemeChange() throws {
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

    try clickButton(requireButton(in: contentView, identifier: "generationConfigCodeGenerationCustomizeButton", title: "Customize"))

    guard let customizedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after entering customize mode")
    }

    try clickButton(requireButton(
        in: customizedContentView,
        identifier: "generationConfigCodeGenerationAdvancedButton",
        title: "Advanced Params"
    ))

    guard let advancedContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after expanding advanced params")
    }

    let authEditor = try requireTextView(in: advancedContentView, identifier: "generationConfigCodeGenerationAuthEditor")
    updateTextView(authEditor, value: #"{"api_key":}"#)

    var pack = PixelTheme.pack
    pack.meta.id = "sunset"
    pack.tokens.colors.windowBackgroundHex = "#351B31"
    try themeManager.apply(pack)

    guard let rebuiltContentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist after theme rebuild")
    }

    _ = try requireLabel(in: rebuiltContentView, stringValue: "主题代码")
    let authEditorAfterThemeChange = try requireTextView(in: rebuiltContentView, identifier: "generationConfigCodeGenerationAuthEditor")
    try expect(
        authEditorAfterThemeChange.string == #"{"api_key":}"#,
        "theme-driven rebuilds should preserve invalid JSON drafts for recovery"
    )
    try expect(
        hexString(controller.window?.backgroundColor) == "#351B31",
        "theme-driven rebuilds should still restyle the window even when invalid JSON is visible"
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

private func findTextField(in root: NSView, identifier: String) -> NSTextField? {
    allSubviews(in: root)
        .compactMap { $0 as? NSTextField }
        .first { $0.identifier?.rawValue == identifier }
}

private func findTextView(in root: NSView, identifier: String) -> NSTextView? {
    allSubviews(in: root)
        .compactMap { $0 as? NSTextView }
        .first { $0.identifier?.rawValue == identifier }
}

private func requireTextView(in root: NSView, identifier: String) throws -> NSTextView {
    if let textView = findTextView(in: root, identifier: identifier) {
        return textView
    }

    throw TestFailure(message: "expected text view '\(identifier)' to exist")
}

private func requirePopupButton(in root: NSView, identifier: String) throws -> NSPopUpButton {
    if let popup = allSubviews(in: root)
        .compactMap({ $0 as? NSPopUpButton })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return popup
    }

    throw TestFailure(message: "expected popup button '\(identifier)' to exist")
}

private func updateTextField(_ field: NSTextField, value: String) {
    field.stringValue = value
    let notification = Notification(name: NSControl.textDidChangeNotification, object: field)
    NotificationCenter.default.post(notification)
    (field.delegate as? GenerationConfigWindowController)?.controlTextDidChange(notification)
}

private func clickButton(_ button: NSButton) throws {
    guard let action = button.action else {
        throw TestFailure(message: "button '\(button.identifier?.rawValue ?? button.title)' should have an action")
    }

    _ = NSApp.sendAction(action, to: button.target, from: button)
}

private func updateTextView(_ textView: NSTextView, value: String) {
    textView.string = value
    let notification = Notification(name: NSText.didChangeNotification, object: textView)
    NotificationCenter.default.post(notification)
    (textView.delegate as? GenerationConfigWindowController)?.textDidChange(notification)
}

private func selectPopupItem(_ popup: NSPopUpButton, title: String) throws {
    guard popup.itemTitles.contains(title) else {
        throw TestFailure(message: "expected popup item '\(title)' to exist")
    }

    popup.selectItem(withTitle: title)
    guard let action = popup.action else {
        throw TestFailure(message: "popup button '\(popup.identifier?.rawValue ?? "<missing>")' should have an action")
    }

    _ = NSApp.sendAction(action, to: popup.target, from: popup)
}

func findButton(in root: NSView, title: String) -> NSButton? {
    allSubviews(in: root).compactMap { $0 as? NSButton }.first { $0.title == title }
}

private func requireButton(in root: NSView, identifier: String, title: String) throws -> NSButton {
    if let button = allSubviews(in: root)
        .compactMap({ $0 as? NSButton })
        .first(where: { $0.identifier?.rawValue == identifier && $0.title == title }) {
        return button
    }

    throw TestFailure(message: "expected button '\(identifier)' with title '\(title)' to exist")
}

func findLabel(in root: NSView, stringValue: String) -> NSTextField? {
    allSubviews(in: root).compactMap { $0 as? NSTextField }.first { $0.stringValue == stringValue }
}

private final class StubGenerationConnectionTester: GenerationConnectionTesting {
    let results: [Result<Void, Error>]
    private(set) var requests: [(provider: GenerationProvider, defaults: GenerationProviderDefaultConfig)] = []
    private var nextResultIndex = 0

    init(results: [Result<Void, Error>]) {
        self.results = results
    }

    func testConnection(provider: GenerationProvider, defaults: GenerationProviderDefaultConfig) throws {
        requests.append((provider: provider, defaults: defaults))
        guard nextResultIndex < results.count else {
            throw TestFailure(message: "connection tester stub exhausted")
        }

        defer { nextResultIndex += 1 }
        switch results[nextResultIndex] {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
