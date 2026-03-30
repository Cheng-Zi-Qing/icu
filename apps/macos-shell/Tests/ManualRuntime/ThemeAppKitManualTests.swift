import AppKit

func testAvatarPanelThemeReflectsSharedThemeColors() throws {
    let manager = try makeInstalledThemeManager()
    let pack = makeAppKitTestThemePack(id: "wrapper_refresh")

    try manager.apply(pack)

    try expect(
        hexString(AvatarPanelTheme.accent) == pack.tokens.colors.accentHex,
        "avatar panel accent should reflect the active shared theme"
    )
    try expect(
        hexString(AvatarPanelTheme.text) == pack.tokens.colors.textPrimaryHex,
        "avatar panel text color should reflect the active shared theme"
    )
}

func testAvatarSelectorWindowRestylesWhenThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard
        let window = controller.window,
        let contentView = window.contentView
    else {
        throw TestFailure(message: "selector window should be created")
    }

    let pack = makeAppKitTestThemePack(id: "selector_refresh")

    try manager.apply(pack)
    let refreshedTitleLabel = try requireLabel(in: contentView, stringValue: "选择你的桌宠形象")

    try expect(
        hexString(window.backgroundColor) == pack.tokens.colors.windowBackgroundHex,
        "selector window should refresh background when theme changes"
    )
    try expect(
        hexString(refreshedTitleLabel.textColor) == pack.tokens.colors.accentHex,
        "selector title should refresh accent color when theme changes"
    )
}

func testAvatarSelectorWindowUsesStudioTabsAndThemeBubblePreviewByDefault() throws {
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    _ = try requireButton(in: contentView, title: "主题风格")
    _ = try requireButton(in: contentView, title: "桌宠形象动画")
    _ = try requireButton(in: contentView, title: "话术")
    _ = try requireLabel(in: contentView, stringValue: "当前已应用主题")
    _ = try requireLabel(in: contentView, stringValue: "原始 prompt")
    _ = try requireLabel(in: contentView, stringValue: "优化后 prompt")
    _ = try requireLabel(in: contentView, stringValue: "样式草稿")
    _ = try requireLabel(in: contentView, stringValue: "桌宠气泡预览")
    _ = try requireButton(in: contentView, title: "优化 prompt")
    _ = try requireButton(in: contentView, title: "重新优化")
    _ = try requireButton(in: contentView, title: "预览效果")
    _ = try requireButton(in: contentView, title: "应用主题")
    try expect(
        findButton(in: contentView, title: "生成预览") == nil,
        "theme tab should not reuse the generic preview button"
    )
    try expect(
        findButton(in: contentView, title: "重新生成") == nil,
        "theme tab should not reuse the generic regenerate button"
    )
}

func testAvatarSelectorThemeTabOmitsModelSummaryAndCrossDomainPanels() throws {
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try expect(
        findLabel(in: contentView, stringValue: "本次生成会使用的模型") == nil,
        "theme tab should not show model summary cards after tab decoupling"
    )
    try expect(
        findLabel(in: contentView, stringValue: "形象列表") == nil,
        "theme tab should not show avatar selection panels"
    )
    try expect(
        findLabel(in: contentView, stringValue: "桌宠对话气泡预览") == nil,
        "theme tab should not show speech preview panels"
    )
}

func testAvatarSelectorAvatarTabEntersInlineCreateMode() throws {
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    _ = try requireLabel(in: contentView, stringValue: "当前模式：新建形象")
    _ = try requireButton(in: contentView, title: "返回现有形象")
    _ = try requireButton(in: contentView, title: "保存并应用")
    _ = try requireLabel(in: contentView, stringValue: "形象列表")
    try expect(
        controller.window?.isVisible == true,
        "selector window should stay open when entering inline create mode"
    )
}

func testAvatarSelectorInlineCreateModeReturnsToBrowseModeWithoutClosing() throws {
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    _ = try requireLabel(in: contentView, stringValue: "当前模式：新建形象")

    try requireButton(in: contentView, title: "返回现有形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        findLabel(in: contentView, stringValue: "当前模式：新建形象") == nil,
        "returning to browse mode should hide the create mode title"
    )
    _ = try requireLabel(in: contentView, stringValue: "预览与说明")
    _ = try requireButton(in: contentView, title: "新增自定义形象")
    try expect(
        findButton(in: contentView, title: "返回现有形象") == nil,
        "browse mode should hide the return-to-library button"
    )
    try expect(
        controller.window?.isVisible == true,
        "selector window should remain open after returning to browse mode"
    )
}

func testAvatarSelectorInlineCreateModeOptimizesRawPromptAndUsesOptimizedPromptForPreview() throws {
    let previewURL = try makeTinyPNG()
    let idleURL = try makeTinyPNG()
    let workingURL = try makeTinyPNG()
    let alertURL = try makeTinyPNG()
    var optimizedPrompts: [String] = []
    var generatedPrompts: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        avatarPromptOptimizer: { prompt in
            optimizedPrompts.append(prompt)
            return "optimized::\(prompt)"
        },
        avatarPreviewGenerator: { prompt in
            generatedPrompts.append(prompt)
            return InlineAvatarPreviewDraft(
                actionImageURLs: [
                    "idle": idleURL,
                    "working": workingURL,
                    "alert": alertURL,
                ],
                suggestedPersona: "稳重、冷静、慢半拍"
            )
        },
        onChoose: { _ in },
        onClose: {}
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let rawPromptView = try requireTextView(in: contentView, identifier: "avatarCreateRawPrompt")
    let optimizedPromptView = try requireTextView(in: contentView, identifier: "avatarCreateOptimizedPrompt")

    rawPromptView.string = "raw capybara prompt"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "生成预览").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        optimizedPrompts == ["raw capybara prompt"],
        "avatar optimizer should receive the raw prompt from create mode"
    )
    try expect(
        rawPromptView.string == "raw capybara prompt",
        "avatar raw prompt should remain unchanged after optimization"
    )
    try expect(
        optimizedPromptView.string == "optimized::raw capybara prompt",
        "avatar optimized prompt should be rendered in its dedicated text view"
    )
    try expect(
        generatedPrompts == ["optimized::raw capybara prompt"],
        "avatar preview generation should consume the optimized prompt instead of the raw prompt"
    )
}

func testAvatarSelectorInlineCreateModeRequiresThreePreviewsAndNameBeforeSave() throws {
    let previewURL = try makeTinyPNG()
    let idleURL = try makeTinyPNG()
    let workingURL = try makeTinyPNG()
    let alertURL = try makeTinyPNG()
    var previewCallCount = 0

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        avatarPromptOptimizer: { prompt in
            "optimized::\(prompt)"
        },
        avatarPreviewGenerator: { _ in
            previewCallCount += 1
            if previewCallCount == 1 {
                return InlineAvatarPreviewDraft(
                    actionImageURLs: [
                        "idle": idleURL,
                        "working": workingURL,
                    ],
                    suggestedPersona: "稳重、冷静、慢半拍"
                )
            }

            return InlineAvatarPreviewDraft(
                actionImageURLs: [
                    "idle": idleURL,
                    "working": workingURL,
                    "alert": alertURL,
                ],
                suggestedPersona: "稳重、冷静、慢半拍"
            )
        },
        onChoose: { _ in },
        onClose: {}
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let optimizeButton = try requireActionButton(in: contentView, title: "优化 prompt")
    let previewButton = try requireActionButton(in: contentView, title: "生成预览")
    let regenerateButton = try requireActionButton(in: contentView, title: "重新生成")
    let saveButton = try requireActionButton(in: contentView, title: "保存并应用")

    try expect(optimizeButton.isEnabled == true, "avatar optimize button should stay enabled in create mode")
    try expect(previewButton.isEnabled == false, "avatar preview button should stay disabled until optimized prompt exists")
    try expect(regenerateButton.isEnabled == false, "avatar regenerate button should stay disabled before any preview")
    try expect(saveButton.isEnabled == false, "avatar save button should stay disabled before preview and name")

    let rawPromptView = try requireTextView(in: contentView, identifier: "avatarCreateRawPrompt")
    rawPromptView.string = "raw prompt for gating"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let previewButtonAfterOptimize = try requireActionButton(in: contentView, title: "生成预览")
    let saveButtonAfterOptimize = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        previewButtonAfterOptimize.isEnabled == true,
        "avatar preview button should enable after optimization"
    )
    try expect(
        saveButtonAfterOptimize.isEnabled == false,
        "avatar save button should still wait for preview"
    )

    try requireActionButton(in: contentView, title: "生成预览").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let regenerateButtonAfterPreview = try requireActionButton(in: contentView, title: "重新生成")
    let saveButtonAfterPreview = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        regenerateButtonAfterPreview.isEnabled == true,
        "avatar regenerate button should enable after the first preview"
    )
    try expect(
        saveButtonAfterPreview.isEnabled == false,
        "avatar save button should stay disabled when one action preview is missing"
    )

    let nameField = try requireTextField(in: contentView, identifier: "avatarCreateNameField")
    let personaField = try requireTextField(in: contentView, identifier: "avatarCreatePersonaField")
    try expect(
        personaField.stringValue == "稳重、冷静、慢半拍",
        "avatar preview should hydrate the editable persona field from the preview draft"
    )

    nameField.stringValue = "淡定水豚"
    nameField.sendAction(nameField.action, to: nameField.target)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let saveButtonAfterName = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        saveButtonAfterName.isEnabled == false,
        "avatar save button should still stay disabled until idle working alert previews all exist"
    )

    try requireActionButton(in: contentView, title: "重新生成").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let saveButtonAfterCompletePreview = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        saveButtonAfterCompletePreview.isEnabled == true,
        "avatar save button should enable only after all previews exist and name is non-empty"
    )
}

func testAvatarSelectorInlineCreateModeCancelKeepsDraftUnsaved() throws {
    let previewURL = try makeTinyPNG()
    let idleURL = try makeTinyPNG()
    let workingURL = try makeTinyPNG()
    let alertURL = try makeTinyPNG()
    var savedRequests: [InlineAvatarSaveRequest] = []
    var chosenAvatarIDs: [String] = []
    var closeCount = 0

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        avatarPromptOptimizer: { prompt in
            "optimized::\(prompt)"
        },
        avatarPreviewGenerator: { _ in
            InlineAvatarPreviewDraft(
                actionImageURLs: [
                    "idle": idleURL,
                    "working": workingURL,
                    "alert": alertURL,
                ],
                suggestedPersona: "稳重、冷静、慢半拍"
            )
        },
        avatarSaveHandler: { request in
            savedRequests.append(request)
            return "should_not_apply"
        },
        onChoose: { avatarID in
            chosenAvatarIDs.append(avatarID)
        },
        onClose: {
            closeCount += 1
        }
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let rawPromptView = try requireTextView(in: contentView, identifier: "avatarCreateRawPrompt")
    rawPromptView.string = "draft that should be discarded"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "生成预览").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let nameField = try requireTextField(in: contentView, identifier: "avatarCreateNameField")
    nameField.stringValue = "不会保存"
    nameField.sendAction(nameField.action, to: nameField.target)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let saveButtonBeforeCancel = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        saveButtonBeforeCancel.isEnabled == true,
        "avatar save button should be enabled before testing cancel"
    )

    try requireActionButton(in: contentView, title: "返回现有形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(savedRequests.isEmpty, "avatar cancel should leave create mode without calling save")
    try expect(chosenAvatarIDs.isEmpty, "avatar cancel should not apply a new avatar selection")
    try expect(closeCount == 0, "avatar cancel should keep the selector window open")
    try expect(
        findLabel(in: contentView, stringValue: "当前模式：新建形象") == nil,
        "avatar cancel should leave inline create mode"
    )
    _ = try requireButton(in: contentView, title: "新增自定义形象")
    try expect(controller.window?.isVisible == true, "avatar cancel should return to browse mode without closing the selector")
}

func testAvatarSelectorInlineCreateModeSaveWithoutHandlerStaysEditable() throws {
    let previewURL = try makeTinyPNG()
    let idleURL = try makeTinyPNG()
    let workingURL = try makeTinyPNG()
    let alertURL = try makeTinyPNG()

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        avatarPromptOptimizer: { prompt in
            "optimized::\(prompt)"
        },
        avatarPreviewGenerator: { _ in
            InlineAvatarPreviewDraft(
                actionImageURLs: [
                    "idle": idleURL,
                    "working": workingURL,
                    "alert": alertURL,
                ],
                suggestedPersona: "稳重、冷静、慢半拍"
            )
        },
        onChoose: { _ in },
        onClose: {}
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let rawPromptView = try requireTextView(in: contentView, identifier: "avatarCreateRawPrompt")
    rawPromptView.string = "draft without save handler"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "生成预览").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let nameField = try requireTextField(in: contentView, identifier: "avatarCreateNameField")
    nameField.stringValue = "未接线草稿"
    nameField.sendAction(nameField.action, to: nameField.target)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let saveButtonBeforeClick = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        saveButtonBeforeClick.isEnabled == true,
        "avatar save button should be enabled before testing missing save handler"
    )

    try requireActionButton(in: contentView, title: "保存并应用").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let saveButtonAfterClick = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        saveButtonAfterClick.isEnabled == true,
        "avatar save button should remain enabled when no save handler is injected"
    )
    _ = try requireLabel(in: contentView, stringValue: "当前环境未接入形象保存能力，请稍后再试。")
    _ = try requireLabel(in: contentView, stringValue: "当前模式：新建形象")
    try expect(
        controller.window?.isVisible == true,
        "selector window should stay open when inline avatar save is unavailable"
    )

    nameField.stringValue = "继续编辑"
    nameField.sendAction(nameField.action, to: nameField.target)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    let saveButtonAfterEdit = try requireActionButton(in: contentView, title: "保存并应用")
    try expect(
        saveButtonAfterEdit.isEnabled == true,
        "avatar save should stay retryable after an unavailable save attempt"
    )
}

func testAvatarSelectorInlineCreateModeSavesAndAppliesGeneratedAvatar() throws {
    let previewURL = try makeTinyPNG()
    let idleURL = try makeTinyPNG()
    let workingURL = try makeTinyPNG()
    let alertURL = try makeTinyPNG()
    var optimizedPrompts: [String] = []
    var previewPrompts: [String] = []
    var savedRequests: [InlineAvatarSaveRequest] = []
    var chosenAvatarIDs: [String] = []
    var closeCount = 0

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        avatarPromptOptimizer: { prompt in
            optimizedPrompts.append(prompt)
            return "optimized::\(prompt)"
        },
        avatarPreviewGenerator: { prompt in
            previewPrompts.append(prompt)
            return InlineAvatarPreviewDraft(
                actionImageURLs: [
                    "idle": idleURL,
                    "working": workingURL,
                    "alert": alertURL,
                ],
                suggestedPersona: "稳重、冷静、慢半拍"
            )
        },
        avatarSaveHandler: { request in
            savedRequests.append(request)
            return "custom_capybara"
        },
        onChoose: { avatarID in
            chosenAvatarIDs.append(avatarID)
        },
        onClose: {
            closeCount += 1
        }
    )

    controller.present()
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
    try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let rawPromptView = try requireTextView(in: contentView, identifier: "avatarCreateRawPrompt")
    rawPromptView.string = "raw capybara save/apply prompt"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "生成预览").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let nameField = try requireTextField(in: contentView, identifier: "avatarCreateNameField")
    let personaField = try requireTextField(in: contentView, identifier: "avatarCreatePersonaField")
    try expect(
        personaField.stringValue == "稳重、冷静、慢半拍",
        "avatar preview should seed the editable persona before save"
    )
    personaField.stringValue = ""
    personaField.sendAction(personaField.action, to: personaField.target)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    nameField.stringValue = "淡定水豚"
    nameField.sendAction(nameField.action, to: nameField.target)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try requireActionButton(in: contentView, title: "保存并应用").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        optimizedPrompts == ["raw capybara save/apply prompt"],
        "save/apply flow should optimize the raw prompt exactly once"
    )
    try expect(
        previewPrompts == ["optimized::raw capybara save/apply prompt"],
        "save/apply flow should preview using the optimized prompt"
    )
    try expect(savedRequests.count == 1, "save should run exactly once")
    try expect(
        savedRequests[0].name == "淡定水豚",
        "save should receive the edited avatar name"
    )
    try expect(
        savedRequests[0].persona == "",
        "save should receive the current persona draft even when the user clears it"
    )
    try expect(
        savedRequests[0].actionImageURLs == [
            "idle": idleURL,
            "working": workingURL,
            "alert": alertURL,
        ],
        "save should receive all generated action image URLs"
    )
    try expect(
        chosenAvatarIDs == ["custom_capybara"],
        "saved avatar should be applied through the existing choose path"
    )
    try expect(closeCount == 0, "successful save/apply should finish without calling onClose")
    try expect(controller.window?.isVisible == false, "selector should close after a successful save/apply")
}

func testAvatarSelectorThemeTabGeneratesDraftBeforeApplyingTheme() throws {
    let environment = try makeGenerationEnvironment()
    ThemeManager.installShared(environment.themeManager)

    let previewURL = try makeTinyPNG()
    let generatedPack = makeAppKitTestThemePack(id: "generated_preview_theme")
    var optimizedPrompts: [String] = []
    var generatedPrompts: [String] = []
    var appliedPackIDs: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        themePromptOptimizer: { prompt in
            optimizedPrompts.append(prompt)
            return "optimized::\(prompt)"
        },
        themeDraftGenerator: { prompt in
            generatedPrompts.append(prompt)
            return generatedPack
        },
        themeDraftApplier: { pack in
            appliedPackIDs.append(pack.meta.id)
            try environment.themeManager.apply(pack)
        },
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
    let optimizedPromptView = try requireTextView(in: contentView, identifier: "themeOptimizedPrompt")
    rawPromptView.string = "raw cozy pixel vibe"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "预览效果").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        optimizedPrompts == ["raw cozy pixel vibe"],
        "theme optimizer should receive the raw prompt"
    )
    try expect(
        optimizedPromptView.string == "optimized::raw cozy pixel vibe",
        "optimized prompt should be shown separately without overwriting the raw prompt"
    )
    try expect(
        rawPromptView.string == "raw cozy pixel vibe",
        "raw prompt should remain unchanged after optimization"
    )
    try expect(
        generatedPrompts.count == 1,
        "theme preview should call the draft generator exactly once"
    )
    try expect(
        generatedPrompts == ["optimized::raw cozy pixel vibe"],
        "theme preview should use the optimized prompt instead of the raw prompt"
    )
    try expect(
        environment.themeManager.currentTheme.id == "pixel_default",
        "theme preview must not activate the generated theme before apply"
    )
    let activeThemeIDBeforeApply = try environment.settingsStore.loadActiveThemeID()
    try expect(
        activeThemeIDBeforeApply == nil,
        "theme preview must not persist an active theme before apply"
    )

    try requireActionButton(in: contentView, title: "应用主题").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        appliedPackIDs == ["generated_preview_theme"],
        "theme apply should pass the pending generated pack to the applier"
    )
    try expect(
        environment.themeManager.currentTheme.id == "generated_preview_theme",
        "theme apply should activate the generated theme"
    )
    let activeThemeIDAfterApply = try environment.settingsStore.loadActiveThemeID()
    try expect(
        activeThemeIDAfterApply == "generated_preview_theme",
        "theme apply should persist the generated theme id"
    )
}

func testAvatarSelectorThemeTabRequiresPreviewBeforeApply() throws {
    let environment = try makeGenerationEnvironment()
    ThemeManager.installShared(environment.themeManager)

    let previewURL = try makeTinyPNG()
    var optimizedPrompts: [String] = []
    var generatedPrompts: [String] = []
    var appliedPackIDs: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        themePromptOptimizer: { prompt in
            optimizedPrompts.append(prompt)
            return "optimized::\(prompt)"
        },
        themeDraftGenerator: { prompt in
            generatedPrompts.append(prompt)
            return makeAppKitTestThemePack(id: "should_not_generate_here")
        },
        themeDraftApplier: { pack in
            appliedPackIDs.append(pack.meta.id)
            try environment.themeManager.apply(pack)
        },
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
    rawPromptView.string = "raw apply without preview"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try requireActionButton(in: contentView, title: "应用主题").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        optimizedPrompts == ["raw apply without preview"],
        "theme optimizer should still run on the raw prompt before apply"
    )
    try expect(
        generatedPrompts.isEmpty,
        "theme apply should not generate a preview draft on its own"
    )
    try expect(
        appliedPackIDs.isEmpty,
        "theme apply should not call the applier before a preview is generated"
    )
    try expect(
        environment.themeManager.currentTheme.id == "pixel_default",
        "theme apply should keep the current theme unchanged before a preview exists"
    )
    let activeThemeID = try environment.settingsStore.loadActiveThemeID()
    try expect(
        activeThemeID == nil,
        "theme apply should not persist an active theme before a preview exists"
    )
    try expect(
        findLabel(in: contentView, stringValue: "主题草稿已应用。") == nil,
        "theme apply should not report success before a preview exists"
    )
}

func testAvatarSelectorThemeTabInvalidatesApplyWhenOptimizedPromptChanges() throws {
    let environment = try makeGenerationEnvironment()
    ThemeManager.installShared(environment.themeManager)

    let previewURL = try makeTinyPNG()
    let generatedPack = makeAppKitTestThemePack(id: "generated_preview_theme_after_edit")
    var generatedPrompts: [String] = []
    var appliedPackIDs: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        themePromptOptimizer: { prompt in
            "optimized::\(prompt)"
        },
        themeDraftGenerator: { prompt in
            generatedPrompts.append(prompt)
            return generatedPack
        },
        themeDraftApplier: { pack in
            appliedPackIDs.append(pack.meta.id)
            try environment.themeManager.apply(pack)
        },
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
    let optimizedPromptView = try requireTextView(in: contentView, identifier: "themeOptimizedPrompt")
    rawPromptView.string = "raw theme prompt"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "预览效果").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    _ = try requireLabel(in: contentView, stringValue: "草稿 1：AppKit Test Theme / optimized::raw theme prompt")
    _ = try requireLabel(in: contentView, stringValue: "待命中，点击我可展开菜单。")

    optimizedPromptView.string = "optimized::raw theme prompt edited"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: optimizedPromptView))

    try requireActionButton(in: contentView, title: "应用主题").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        generatedPrompts == ["optimized::raw theme prompt"],
        "theme preview should lock to the last previewed optimized prompt"
    )
    try expect(
        appliedPackIDs.isEmpty,
        "theme apply should be invalidated after the optimized prompt changes"
    )
    try expect(
        environment.themeManager.currentTheme.id == "pixel_default",
        "theme apply should keep the current theme unchanged after the optimized prompt changes"
    )
    _ = try requireLabel(in: contentView, stringValue: "尚未生成新的主题草稿。")
    _ = try requireLabel(in: contentView, stringValue: "优化后 prompt 已变更，请重新预览效果。")
    try expect(
        findLabel(in: contentView, stringValue: "草稿 1：AppKit Test Theme / optimized::raw theme prompt") == nil,
        "theme draft summary should stop presenting the stale preview as current after optimized prompt changes"
    )
    try expect(
        findLabel(in: contentView, stringValue: "待命中，点击我可展开菜单。") == nil,
        "theme preview bubble should stop presenting the stale preview as current after optimized prompt changes"
    )
    try expect(
        findLabel(in: contentView, stringValue: "主题草稿已应用。") == nil,
        "theme apply should not report success after preview invalidation"
    )
}

func testAvatarSelectorThemeTabBlocksApplyAfterFailedReoptimize() throws {
    let environment = try makeGenerationEnvironment()
    ThemeManager.installShared(environment.themeManager)

    let previewURL = try makeTinyPNG()
    let generatedPack = makeAppKitTestThemePack(id: "generated_preview_theme_reoptimize_failure")
    var optimizeCalls = 0
    var appliedPackIDs: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        themePromptOptimizer: { prompt in
            optimizeCalls += 1
            if optimizeCalls == 1 {
                return "optimized::\(prompt)"
            }
            throw AvatarBuilderBridgeError.executionFailed(command: "optimize-prompt", details: "bridge down")
        },
        themeDraftGenerator: { _ in
            generatedPack
        },
        themeDraftApplier: { pack in
            appliedPackIDs.append(pack.meta.id)
            try environment.themeManager.apply(pack)
        },
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
    rawPromptView.string = "raw theme prompt"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "预览效果").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try requireActionButton(in: contentView, title: "重新优化").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "应用主题").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        appliedPackIDs.isEmpty,
        "theme apply should stay blocked when reoptimize fails after a previous preview"
    )
    try expect(
        environment.themeManager.currentTheme.id == "pixel_default",
        "theme apply should not activate a stale preview after reoptimize fails"
    )
    _ = try requireLabel(in: contentView, stringValue: "尚未生成新的主题草稿。")
    _ = try requireLabel(in: contentView, stringValue: "优化后 prompt 已变更，请重新预览效果。")
}

func testAvatarSelectorThemeTabUpdatesActionButtonStatesAcrossReviewFlow() throws {
    let previewURL = try makeTinyPNG()

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        themePromptOptimizer: { prompt in
            "optimized::\(prompt)"
        },
        themeDraftGenerator: { _ in
            makeAppKitTestThemePack(id: "generated_preview_theme_button_states")
        },
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    let initialPreviewButton = try requireActionButton(in: contentView, title: "预览效果")
    let initialApplyButton = try requireActionButton(in: contentView, title: "应用主题")
    try expect(initialPreviewButton.isEnabled == false, "theme preview button should start disabled before an optimized prompt exists")
    try expect(initialApplyButton.isEnabled == false, "theme apply button should start disabled before a preview exists")

    let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
    let optimizedPromptView = try requireTextView(in: contentView, identifier: "themeOptimizedPrompt")
    rawPromptView.string = "raw button state prompt"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: rawPromptView))

    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let previewButtonAfterOptimize = try requireActionButton(in: contentView, title: "预览效果")
    let applyButtonAfterOptimize = try requireActionButton(in: contentView, title: "应用主题")
    try expect(previewButtonAfterOptimize.isEnabled == true, "theme preview button should enable once an optimized prompt exists")
    try expect(applyButtonAfterOptimize.isEnabled == false, "theme apply button should stay disabled until preview succeeds")

    try requireActionButton(in: contentView, title: "预览效果").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let previewButtonAfterPreview = try requireActionButton(in: contentView, title: "预览效果")
    let applyButtonAfterPreview = try requireActionButton(in: contentView, title: "应用主题")
    try expect(previewButtonAfterPreview.isEnabled == true, "theme preview button should remain enabled after preview")
    try expect(applyButtonAfterPreview.isEnabled == true, "theme apply button should enable after a valid preview exists")

    optimizedPromptView.string = "optimized::raw button state prompt edited"
    controller.textDidChange(Notification(name: NSText.didChangeNotification, object: optimizedPromptView))

    let previewButtonAfterEdit = try requireActionButton(in: contentView, title: "预览效果")
    let applyButtonAfterEdit = try requireActionButton(in: contentView, title: "应用主题")
    try expect(previewButtonAfterEdit.isEnabled == true, "theme preview button should stay enabled when the edited optimized prompt is still non-empty")
    try expect(applyButtonAfterEdit.isEnabled == false, "theme apply button should disable when the optimized prompt invalidates the last preview")
}

func testAvatarWizardWindowRestylesWhenThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let repoRoot = try makeTemporaryDirectory()
    let controller = AvatarWizardWindowController(
        bridge: AvatarBuilderBridge(
            scriptURL: URL(fileURLWithPath: "/tmp/unused-avatar-builder-bridge.py", isDirectory: false)
        ),
        models: [
            BridgeImageModel(
                name: "Test Model",
                url: "https://example.invalid/model",
                token: ""
            )
        ],
        settingsStore: AvatarSettingsStore(repoRootURL: repoRoot),
        assetStore: AvatarAssetStore(repoRootURL: repoRoot),
        onSave: { _ in },
        onClose: {}
    )

    guard
        let window = controller.window,
        let contentView = window.contentView
    else {
        throw TestFailure(message: "wizard window should be created")
    }

    let pack = makeAppKitTestThemePack(id: "wizard_refresh")

    try manager.apply(pack)
    let refreshedStatusLabel = try requireLabel(in: contentView, stringValue: "填写描述后即可开始。")

    try expect(
        hexString(window.backgroundColor) == pack.tokens.colors.windowBackgroundHex,
        "wizard window should refresh background when theme changes"
    )
    try expect(
        hexString(refreshedStatusLabel.textColor) == pack.tokens.colors.textSecondaryHex,
        "wizard status label should refresh muted text color when theme changes"
    )
}

func testAvatarWizardUsesInstalledCopyCatalogForVisibleLabels() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "avatar_wizard": {
            "step_one_title": "步骤 1/3：优化提示词",
            "initial_status": "填写描述后即可开始。",
            "optimize_button": "优化提示词"
          }
        }
        """,
        overrideJSON: """
        {
          "avatar_wizard": {
            "step_one_title": "阶段 1/3：整理提示词",
            "initial_status": "先写描述，再开始生成。",
            "optimize_button": "整理提示词"
          }
        }
        """
    )

    let repoRoot = try makeTemporaryDirectory()
    let controller = AvatarWizardWindowController(
        bridge: AvatarBuilderBridge(
            scriptURL: URL(fileURLWithPath: "/tmp/unused-avatar-builder-bridge.py", isDirectory: false)
        ),
        models: [
            BridgeImageModel(
                name: "Test Model",
                url: "https://example.invalid/model",
                token: ""
            )
        ],
        settingsStore: AvatarSettingsStore(repoRootURL: repoRoot),
        assetStore: AvatarAssetStore(repoRootURL: repoRoot),
        onSave: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "wizard content view should exist")
    }

    _ = try requireLabel(in: contentView, stringValue: "阶段 1/3：整理提示词")
    _ = try requireLabel(in: contentView, stringValue: "先写描述，再开始生成。")
    _ = try requireButton(in: contentView, title: "整理提示词")
}

func testAvatarSelectorWindowSpeechTabShowsBubblePreviewAndApplyActions() throws {
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "话术").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    _ = try requireLabel(in: contentView, stringValue: "当前已应用话术")
    _ = try requireLabel(in: contentView, stringValue: "桌宠对话气泡预览")
    _ = try requireButton(in: contentView, title: "生成预览")
    _ = try requireButton(in: contentView, title: "重新生成")
    _ = try requireButton(in: contentView, title: "应用")
}

func testAvatarSelectorSpeechTabOmitsStyleChromeAndModelSummary() throws {
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "话术").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        findLabel(in: contentView, stringValue: "本次生成会使用的模型") == nil,
        "speech tab should not show model summary cards after tab decoupling"
    )
    try expect(
        findLabel(in: contentView, stringValue: "右键菜单与表单预览") == nil,
        "speech tab should not show style chrome preview blocks"
    )
    try expect(
        findLabel(in: contentView, stringValue: "形象列表") == nil,
        "speech tab should not show avatar panels"
    )
}

func testAvatarSelectorWindowUsesInstalledCopyCatalogForStudioLabels() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "theme_studio": {
            "tab_title": "主题风格",
            "applied_summary_title": "当前已应用主题",
            "raw_prompt_title": "原始 prompt",
            "optimized_prompt_title": "优化后 prompt"
          },
          "avatar_studio": {
            "tab_title": "桌宠形象动画"
          },
          "speech_studio": {
            "tab_title": "话术",
            "applied_summary_title": "当前已应用话术"
          }
        }
        """,
        overrideJSON: """
        {
          "theme_studio": {
            "tab_title": "界面样式",
            "applied_summary_title": "已应用样式",
            "raw_prompt_title": "原始描述",
            "optimized_prompt_title": "整理后描述"
          },
          "avatar_studio": {
            "tab_title": "角色动作"
          },
          "speech_studio": {
            "tab_title": "对话文本",
            "applied_summary_title": "已应用文本"
          }
        }
        """
    )

    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    _ = try requireButton(in: contentView, title: "界面样式")
    _ = try requireButton(in: contentView, title: "角色动作")
    _ = try requireButton(in: contentView, title: "对话文本")
    _ = try requireLabel(in: contentView, stringValue: "已应用样式")
    _ = try requireLabel(in: contentView, stringValue: "原始描述")
    _ = try requireLabel(in: contentView, stringValue: "整理后描述")
}

func testAvatarSelectorPreservesSelectedStudioTabWhenThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let previewURL = try makeTinyPNG()
    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "认真",
                tone: "温和"
            )
        ],
        currentAvatarID: "capybara",
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "话术").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try manager.apply(makeAppKitTestThemePack(id: "selector_selection"))

    let speechSectionLabel = try requireLabel(in: contentView, stringValue: "当前已应用话术")
    let bubblePreviewLabel = try requireLabel(in: contentView, stringValue: "桌宠对话气泡预览")
    try expect(
        speechSectionLabel.stringValue == "当前已应用话术",
        "selector should preserve the active studio tab after theme change"
    )
    try expect(
        bubblePreviewLabel.stringValue == "桌宠对话气泡预览",
        "selector should preserve the speech bubble preview after theme change"
    )
}

func testAvatarWizardPreservesInFlightActionButtonStateWhenThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let generatedImageURL = try makeTinyPNG()
    let scriptURL = try makeBridgeScript(
        body: """
import json
import sys
import time

if sys.argv[1] == "generate-image":
    time.sleep(0.6)
    print(json.dumps({"path": "\(generatedImageURL.path)"}))
else:
    print(json.dumps({"prompt": "unused"}))
"""
    )
    let controller = AvatarWizardWindowController(
        bridge: AvatarBuilderBridge(scriptURL: scriptURL),
        models: [
            BridgeImageModel(
                name: "Test Model",
                url: "https://example.invalid/model",
                token: ""
            )
        ],
        settingsStore: AvatarSettingsStore(repoRootURL: try makeTemporaryDirectory()),
        assetStore: AvatarAssetStore(repoRootURL: try makeTemporaryDirectory()),
        onSave: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "wizard content view should exist")
    }

    let textViews = allSubviews(in: contentView).compactMap { $0 as? NSTextView }
    guard textViews.count >= 2 else {
        throw TestFailure(message: "wizard should expose prompt text views")
    }

    textViews[1].string = "optimized prompt"
    try requireButton(in: contentView, title: "下一步").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    let idleButton = try requireButton(in: contentView, title: "生成 idle")
    idleButton.performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    try manager.apply(makeAppKitTestThemePack(id: "wizard_inflight"))

    let disabledButtonAfterThemeChange = try requireButton(in: contentView, title: "生成 idle")
    try expect(disabledButtonAfterThemeChange.isEnabled == false, "wizard should keep action button disabled while generation is in flight")

    RunLoop.current.run(until: Date().addingTimeInterval(0.8))

    let reenabledButton = try requireButton(in: contentView, title: "生成 idle")
    try expect(reenabledButton.isEnabled == true, "wizard should re-enable the current action button when generation finishes")
}

func testAvatarWizardDoesNotAccumulateDuplicateButtonWidthConstraintsAcrossThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let controller = AvatarWizardWindowController(
        bridge: AvatarBuilderBridge(
            scriptURL: URL(fileURLWithPath: "/tmp/unused-avatar-builder-bridge.py", isDirectory: false)
        ),
        models: [
            BridgeImageModel(
                name: "Test Model",
                url: "https://example.invalid/model",
                token: ""
            )
        ],
        settingsStore: AvatarSettingsStore(repoRootURL: try makeTemporaryDirectory()),
        assetStore: AvatarAssetStore(repoRootURL: try makeTemporaryDirectory()),
        onSave: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "wizard content view should exist")
    }

    try manager.apply(makeAppKitTestThemePack(id: "wizard_constraints_1"))
    try manager.apply(makeAppKitTestThemePack(id: "wizard_constraints_2"))

    let nextButton = try requireButton(in: contentView, title: "下一步")
    let widthConstraints = nextButton.constraints.filter {
        $0.firstAttribute == .width && $0.constant == 140
    }
    try expect(widthConstraints.count == 1, "wizard should keep a single width constraint on the next button across theme rebuilds")
}

func testDesktopPetViewRefreshesStatusChipWhenThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    view.setStatusText("测试状态")

    let statusLabel = try requireStatusLabel(in: view)
    let pack = makeAppKitTestThemePack(id: "pet_refresh")

    try manager.apply(pack)

    try expect(
        hexString(statusLabel.textColor) == pack.tokens.colors.textPrimaryHex,
        "desktop pet status chip should refresh text color when theme changes"
    )
}

func testDesktopPetViewUsesInstalledCopyCatalogForInitialStatusLabel() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "pet": {
            "status_idle": "待机中"
          }
        }
        """,
        overrideJSON: """
        {
          "pet": {
            "status_idle": "空闲待命"
          }
        }
        """
    )

    let manager = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    _ = manager
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )

    let statusLabel = try requireStatusLabel(in: view)

    try expect(
        statusLabel.stringValue == "空闲待命",
        "desktop pet view should use the installed copy catalog for its initial status text"
    )
}

func testDesktopPetViewShowsTransientBubbleSeparateFromStatusChip() throws {
    let manager = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    _ = manager
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    view.setStatusText("待机中")

    let statusLabel = try requireStatusLabel(in: view)
    try expect(statusLabel.stringValue == "待机中", "test setup should keep the persistent status chip visible")
    try expect(
        findTransientBubbleLabel(in: view) == nil,
        "desktop pet should not create a transient bubble before a message is shown"
    )

    view.showTransientMessage("看看远处", duration: 0.05)

    let bubbleLabel = try requireTransientBubbleLabel(in: view)
    try expect(
        bubbleLabel.stringValue == "看看远处",
        "transient message should render inside a dedicated bubble label"
    )
    try expect(
        statusLabel.stringValue == "待机中",
        "transient bubble should not overwrite the persistent status chip text"
    )

    try expect(
        waitForCondition(timeout: 0.3) {
            findTransientBubbleLabel(in: view) == nil
        },
        "transient bubble should dismiss itself after the requested duration"
    )
    try expect(
        statusLabel.stringValue == "待机中",
        "persistent status chip should remain visible after the transient bubble disappears"
    )
}

func testDesktopPetViewAdvancesFramesForMultiFrameIdleAnimation() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let frame0 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let frame1 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("1.png", isDirectory: false)
    try makeColorPNG(at: frame0, color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))
    try makeColorPNG(at: frame1, color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    try expect(view.currentFrameIndexForTesting == 0, "multi-frame animation should start at frame 0")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 0, blue: 0),
        "desktop pet should render the first frame immediately after load"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 1, "frame advance should move to next frame index")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 255, blue: 0),
        "frame advance should render the next frame image"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 0, "frame advance should wrap around for looping animations")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 0, blue: 0),
        "wrapped frame advance should render frame 0 again"
    )
}

func testDesktopPetViewKeepsLegacySingleFrameAnimationStatic() throws {
    let appPaths = try makeTemporaryAppPaths()
    let legacyFrame = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try makeColorPNG(at: legacyFrame, color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    try expect(view.currentFrameIndexForTesting == 0, "legacy single-frame animation should start at frame 0")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 0, blue: 255),
        "legacy animation should render the only available frame"
    )

    view.advanceAnimationFrameForTesting()
    view.advanceAnimationFrameForTesting()

    try expect(view.currentFrameIndexForTesting == 0, "legacy single-frame animation should not advance out of bounds")
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 0, blue: 255),
        "legacy single-frame animation should remain visually static when advanced"
    )
}

func testDesktopPetViewDoesNotAutoAdvanceWhileDetachedFromWindow() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    let frame0 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    let frame1 = petRoot
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("main", isDirectory: true)
        .appendingPathComponent("1.png", isDirectory: false)
    try makeColorPNG(at: frame0, color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))
    try makeColorPNG(at: frame1, color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )

    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

    try expect(
        view.currentFrameIndexForTesting == 0,
        "desktop pet should not auto-advance frames before it is attached to a window"
    )
}

func testDesktopPetViewHitTestUsesAspectFitImageRectForTransparency() throws {
    let appPaths = try makeTemporaryAppPaths()
    let frameURL = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
        .appendingPathComponent("idle", isDirectory: true)
        .appendingPathComponent("0.png", isDirectory: false)
    try makeRightHalfOpaquePNG(at: frameURL, opaqueColor: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1))

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 80, height: 40),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )

    let transparentPaddingPoint = NSPoint(x: 70, y: 20)
    let opaqueImagePoint = NSPoint(x: 50, y: 20)

    try expect(
        view.hitTest(transparentPaddingPoint) == nil,
        "hit testing should click through right-side aspect-fit padding"
    )
    try expect(
        view.hitTest(opaqueImagePoint) != nil,
        "hit testing should still hit opaque pixels inside the drawn image rect"
    )
}

func testDesktopPetViewSetWorkStateImmediatelyReloadsMatchingAnimationFamily() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "idle",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 0, blue: 0),
        "desktop pet should start from the idle animation family"
    )

    view.setWorkState(.working)

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "setWorkState(.working) should immediately load the working animation family"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 255, blue: 0),
        "working state should immediately replace the displayed frame"
    )
}

func testDesktopPetViewMapsFocusToWorkingAndBreakToAlertAnimationFamilies() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara"
    )
    let imageView = try requirePetImageView(in: view)

    view.setWorkState(.focus)
    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "focus should map onto the working animation family"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 255, blue: 0),
        "focus should reuse the working animation frames"
    )

    view.setWorkState(.breakState)
    try expect(
        view.currentAnimationStateIDForTesting == "alert",
        "break should map onto the alert animation family"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 0, green: 0, blue: 255),
        "break should immediately switch to the alert frames"
    )
}

func testDesktopPetViewVariantRotationStaysWithinCurrentStateFamily() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([1])
    )
    let imageView = try requirePetImageView(in: view)
    view.setWorkState(.working)

    try expect(view.currentAnimationStateIDForTesting == "working", "test setup should enter working state")
    try expect(view.currentVariantIDForTesting == "main", "working state should start from the default variant")

    view.triggerVariantRotationForTesting()

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "same-state variant rotation must stay inside the working animation family"
    )
    try expect(
        view.currentVariantIDForTesting == "alt",
        "same-state variant rotation should be able to select a sibling working variant"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 255, blue: 0),
        "same-state variant rotation should load the selected working variant frame"
    )
}

func testDesktopPetViewTimedVariantRotationStaysWithinCurrentStateFamily() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 1,
        color: NSColor(deviceRed: 0, green: 0.5, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([0])
    )
    let imageView = try requirePetImageView(in: view)
    view.setWorkState(.working)

    try expect(view.currentAnimationStateIDForTesting == "working", "test setup should enter working state")
    try expect(view.currentVariantIDForTesting == "main", "working state should start from the default variant")

    for tick in 1...4 {
        view.advanceAnimationFrameForTesting()
        try expect(
            view.currentAnimationStateIDForTesting == "working",
            "cooldown tick \(tick) should keep the timed rotation inside the working state family"
        )
        try expect(
            view.currentVariantIDForTesting == "main",
            "cooldown tick \(tick) should not rotate variants before the working cooldown expires"
        )
    }

    view.advanceAnimationFrameForTesting()

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "timed same-state rotation must stay inside the working animation family"
    )
    try expect(
        view.currentVariantIDForTesting == "alt",
        "timed same-state rotation should select a sibling working variant after the cooldown expires"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 255, blue: 0),
        "timed same-state rotation should load the selected working variant frame instead of alert"
    )
}

func testDesktopPetViewTimedVariantRotationWorksForSingleFrameVariants() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "alert",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 0, blue: 1, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([0])
    )
    let imageView = try requirePetImageView(in: view)
    view.setWorkState(.working)

    try expect(view.currentAnimationStateIDForTesting == "working", "test setup should enter working state")
    try expect(view.currentVariantIDForTesting == "main", "single-frame working state should start from the default variant")

    for tick in 1...4 {
        view.advanceAnimationTickForTesting()
        try expect(
            view.currentAnimationStateIDForTesting == "working",
            "single-frame cooldown tick \(tick) should keep the runtime inside the working family"
        )
        try expect(
            view.currentVariantIDForTesting == "main",
            "single-frame cooldown tick \(tick) should not rotate before the working cooldown expires"
        )
    }

    view.advanceAnimationTickForTesting()

    try expect(
        view.currentAnimationStateIDForTesting == "working",
        "single-frame timed rotation must stay inside the working animation family"
    )
    try expect(
        view.currentVariantIDForTesting == "alt",
        "single-frame timed rotation should rotate to a sibling working variant after the cooldown expires"
    )
    try expect(
        matchesColor(sampleCenterColor(in: imageView.image), red: 255, green: 255, blue: 0),
        "single-frame timed rotation should load the selected working variant frame instead of alert"
    )
}

func testDesktopPetViewVariantRotationWaitsForOneCompletedLoop() throws {
    let appPaths = try makeTemporaryAppPaths()
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 1,
        color: NSColor(deviceRed: 0, green: 0.5, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([1, 1])
    )
    view.setWorkState(.working)

    try expect(view.currentVariantIDForTesting == "main", "working state should start on the primary variant")

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "main",
        "variant rotation must not interrupt the current variant before one full loop completes"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 1, "test setup should advance into the second frame")

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "main",
        "variant rotation must still be blocked before the first loop wraps to frame 0"
    )

    view.advanceAnimationFrameForTesting()
    try expect(view.currentFrameIndexForTesting == 0, "working variant should wrap after one full loop")

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "alt",
        "variant rotation should unlock after the current variant completes a full loop"
    )
}

func testDesktopPetViewOnceVariantUnlocksRotationAtLastFrame() throws {
    let appPaths = try makeTemporaryAppPaths()
    let petRoot = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 0,
        color: NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "main",
        frameIndex: 1,
        color: NSColor(deviceRed: 0, green: 0.5, blue: 0, alpha: 1)
    )
    try makeStateColorPNG(
        appPaths: appPaths,
        petID: "capybara",
        stateID: "working",
        variantID: "alt",
        frameIndex: 0,
        color: NSColor(deviceRed: 1, green: 1, blue: 0, alpha: 1)
    )
    try writeText(
        at: petRoot.appendingPathComponent("config.json", isDirectory: false),
        contents: """
        {
          "id": "capybara",
          "animations": {
            "working": {
              "variants": {
                "main": { "loop_mode": "once" }
              }
            }
          }
        }
        """
    )

    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 64, height: 64),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "capybara",
        variantIndexProvider: makeDeterministicVariantIndexProvider([0])
    )
    view.setWorkState(.working)

    try expect(view.currentVariantIDForTesting == "main", "working once variant should start on main")

    view.advanceAnimationFrameForTesting()
    try expect(
        view.currentFrameIndexForTesting == 1,
        "once variant should advance to its last frame before unlocking rotation"
    )

    view.triggerVariantRotationForTesting()
    try expect(
        view.currentVariantIDForTesting == "alt",
        "once variants should unlock same-state rotation after reaching their last frame"
    )
}

func testPetMotionEnhancerProvidesDistinctProfilesPerState() throws {
    let idle = PetMotionEnhancer.profile(for: "idle")
    let working = PetMotionEnhancer.profile(for: "working")
    let alert = PetMotionEnhancer.profile(for: "alert")

    try expect(idle != working, "idle and working motion profiles should differ")
    try expect(working != alert, "working and alert motion profiles should differ")
    try expect(idle != alert, "idle and alert motion profiles should differ")
}

func testAvatarSelectorSpeechTabAppliesGeneratedCopyToDesktopPetRuntime() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    let repoRoot = try makeTemporaryDirectory()
    let appPaths = try makeTemporaryAppPaths()
    let baseCopyURL = repoRoot
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("copy", isDirectory: true)
        .appendingPathComponent("base.json", isDirectory: false)
    try writeText(
        at: baseCopyURL,
        contents: """
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
        """
    )
    TextCatalog.installShared(try TextCatalog.live(appPaths: appPaths, repoRootURL: repoRoot))

    let manager = try makeInstalledThemeManager()
    _ = manager

    let petView = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    let initialStatusLabel = try requireStatusLabel(in: petView)
    try expect(initialStatusLabel.stringValue == "待机中", "desktop pet should start from the base speech copy")

    let previewURL = try makeTinyPNG()
    let draft = SpeechDraft(
        statusIdle: "空闲待命",
        statusWorking: "稳步推进",
        statusFocus: "沉浸专注",
        statusBreak: "暂时离开",
        focusEndLight: "抬头看远一点，再继续。",
        focusEndHeavy: "已经持续很久了，先完整休息一下。",
        stopWorkMessage: "今天先到这里。",
        eyeReminder: "看向远处，放松一下眼睛。"
    )
    let store = CopyOverrideStore(appPaths: appPaths, repoRootURL: repoRoot)
    var generatedPrompts: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        speechDraftGenerator: { prompt in
            generatedPrompts.append(prompt)
            return draft
        },
        speechDraftApplier: { appliedDraft in
            try store.applySpeechDraft(appliedDraft)
        },
        onChoose: { _ in },
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    try requireButton(in: contentView, title: "话术").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    try requireActionButton(in: contentView, title: "生成预览").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        generatedPrompts.count == 1,
        "speech preview should call the speech draft generator exactly once"
    )
    try expect(
        DesktopPetCopy.statusText(for: .idle) == "待机中",
        "speech preview must not mutate the active desktop pet copy before apply"
    )
    let statusLabelBeforeApply = try requireStatusLabel(in: petView)
    try expect(
        statusLabelBeforeApply.stringValue == "待机中",
        "desktop pet view should keep its current status before speech apply"
    )

    try requireActionButton(in: contentView, title: "应用").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(
        DesktopPetCopy.statusText(for: .idle) == "空闲待命",
        "speech apply should replace the active desktop pet idle status copy"
    )
    let statusLabelAfterApply = try requireStatusLabel(in: petView)
    try expect(
        statusLabelAfterApply.stringValue == "空闲待命",
        "desktop pet view should refresh its visible status after speech apply"
    )
}

func makeInstalledThemeManager() throws -> ThemeManager {
    let repoRoot = try makeTemporaryDirectory()
    let appPaths = try makeTemporaryAppPaths()
    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    let manager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)
    ThemeManager.installShared(manager)
    return manager
}

func makeAppKitTestThemePack(id: String) -> ThemePack {
    var pack = PixelTheme.pack
    pack.meta.id = id
    pack.meta.name = "AppKit Test Theme"
    pack.meta.version += 1
    pack.tokens.colors.windowBackgroundHex = "#3A1022"
    pack.tokens.colors.cardBackgroundHex = "#4A1832"
    pack.tokens.colors.inputBackgroundHex = "#5B2641"
    pack.tokens.colors.menuBackgroundHex = "#2D0C1A"
    pack.tokens.colors.accentHex = "#FFD166"
    pack.tokens.colors.borderHex = "#F28482"
    pack.tokens.colors.textPrimaryHex = "#FFF3E6"
    pack.tokens.colors.textSecondaryHex = "#F6BD60"
    pack.tokens.colors.dangerHex = "#FF6B6B"
    pack.tokens.colors.overlayHex = "#1C0822"
    return pack
}

func requireLabel(in root: NSView, stringValue: String) throws -> NSTextField {
    if let label = allSubviews(in: root).compactMap({ $0 as? NSTextField }).first(where: { $0.stringValue == stringValue }) {
        return label
    }

    throw TestFailure(message: "expected label '\(stringValue)' to exist")
}

func requireStatusLabel(in view: DesktopPetView) throws -> NSTextField {
    if let label = view.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.identifier?.rawValue == "desktopPet.statusLabel" }) {
        return label
    }

    throw TestFailure(message: "desktop pet status label should exist")
}

func findTransientBubbleLabel(in view: DesktopPetView) -> NSTextField? {
    allSubviews(in: view)
        .compactMap { $0 as? NSTextField }
        .first(where: { $0.identifier?.rawValue == "desktopPet.transientBubbleLabel" && !$0.isHidden && !($0.superview?.isHidden ?? false) })
}

func requireTransientBubbleLabel(in view: DesktopPetView) throws -> NSTextField {
    if let label = findTransientBubbleLabel(in: view) {
        return label
    }

    throw TestFailure(message: "desktop pet transient bubble label should exist")
}

func requirePetImageView(in view: DesktopPetView) throws -> NSImageView {
    if let imageView = view.subviews.compactMap({ $0 as? NSImageView }).first {
        return imageView
    }

    throw TestFailure(message: "desktop pet image view should exist")
}

@discardableResult
func waitForCondition(
    timeout: TimeInterval,
    pollInterval: TimeInterval = 0.01,
    _ condition: () -> Bool
) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
    }

    return condition()
}

func requireButton(in root: NSView, title: String) throws -> NSButton {
    if let button = allSubviews(in: root).compactMap({ $0 as? NSButton }).first(where: { $0.title == title }) {
        return button
    }

    throw TestFailure(message: "expected button '\(title)' to exist")
}

func requireActionButton(in root: NSView, title: String) throws -> NSButton {
    if let button = allSubviews(in: root)
        .compactMap({ $0 as? NSButton })
        .first(where: { $0.title == title && $0.action != nil }) {
        return button
    }

    throw TestFailure(message: "expected actionable button '\(title)' to exist")
}

func requireTextView(in root: NSView, identifier: String) throws -> NSTextView {
    if let textView = allSubviews(in: root)
        .compactMap({ $0 as? NSTextView })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return textView
    }
    throw TestFailure(message: "missing text view: \(identifier)")
}

func requireTextField(in root: NSView, identifier: String) throws -> NSTextField {
    if let textField = allSubviews(in: root)
        .compactMap({ $0 as? NSTextField })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return textField
    }

    throw TestFailure(message: "missing text field: \(identifier)")
}

func allSubviews(in root: NSView) -> [NSView] {
    var result: [NSView] = [root]
    for subview in root.subviews {
        result.append(contentsOf: allSubviews(in: subview))
    }
    return result
}

func hexString(_ color: NSColor?) -> String? {
    guard let converted = color?.usingColorSpace(.deviceRGB) else {
        return nil
    }

    let red = Int(round(converted.redComponent * 255))
    let green = Int(round(converted.greenComponent * 255))
    let blue = Int(round(converted.blueComponent * 255))
    return String(format: "#%02X%02X%02X", red, green, blue)
}

func matchesColor(
    _ color: NSColor?,
    red: Int,
    green: Int,
    blue: Int,
    tolerance: Int = 4
) -> Bool {
    guard let converted = color?.usingColorSpace(.deviceRGB) else {
        return false
    }

    let actualRed = Int(round(converted.redComponent * 255))
    let actualGreen = Int(round(converted.greenComponent * 255))
    let actualBlue = Int(round(converted.blueComponent * 255))

    return abs(actualRed - red) <= tolerance
        && abs(actualGreen - green) <= tolerance
        && abs(actualBlue - blue) <= tolerance
}

func makeTinyPNG() throws -> URL {
    let url = try makeTemporaryDirectory().appendingPathComponent("preview.png", isDirectory: false)
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.white.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
    image.unlockFocus()

    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw TestFailure(message: "failed to generate preview png")
    }

    try pngData.write(to: url, options: .atomic)
    return url
}

func makeColorPNG(at url: URL, color: NSColor) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
    image.unlockFocus()

    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw TestFailure(message: "failed to generate color png")
    }

    try pngData.write(to: url, options: .atomic)
}

func makeStateColorPNG(
    appPaths: AppPaths,
    petID: String,
    stateID: String,
    variantID: String? = nil,
    frameIndex: Int,
    color: NSColor
) throws {
    var url = appPaths.assetsDirectory
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent(petID, isDirectory: true)
        .appendingPathComponent(stateID, isDirectory: true)

    if let variantID {
        url.appendPathComponent(variantID, isDirectory: true)
    }

    url.appendPathComponent("\(frameIndex).png", isDirectory: false)
    try makeColorPNG(at: url, color: color)
}

func makeDeterministicVariantIndexProvider(_ indexes: [Int]) -> (Int) -> Int {
    var remaining = indexes
    return { upperBound in
        guard upperBound > 0 else {
            return 0
        }
        guard !remaining.isEmpty else {
            return 0
        }
        return max(0, min(remaining.removeFirst(), upperBound - 1))
    }
}

func makeRightHalfOpaquePNG(at url: URL, opaqueColor: NSColor) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
    opaqueColor.setFill()
    NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 8)).fill()
    image.unlockFocus()

    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw TestFailure(message: "failed to generate half-opaque png")
    }

    try pngData.write(to: url, options: .atomic)
}

func sampleCenterColor(in image: NSImage?) -> NSColor? {
    guard
        let image,
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        return nil
    }

    let width = cgImage.width
    let height = cgImage.height
    let px = width / 2
    let py = height / 2
    guard px >= 0, py >= 0, px < width, py < height else {
        return nil
    }

    guard let context = CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.translateBy(x: CGFloat(-px), y: CGFloat(-py))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let data = context.data else {
        return nil
    }
    let buffer = data.bindMemory(to: UInt8.self, capacity: 4)
    return NSColor(
        deviceRed: CGFloat(buffer[0]) / 255.0,
        green: CGFloat(buffer[1]) / 255.0,
        blue: CGFloat(buffer[2]) / 255.0,
        alpha: CGFloat(buffer[3]) / 255.0
    )
}

func makeBridgeScript(body: String) throws -> URL {
    let url = try makeTemporaryDirectory().appendingPathComponent("bridge.py", isDirectory: false)
    try writeText(at: url, contents: body)
    return url
}
