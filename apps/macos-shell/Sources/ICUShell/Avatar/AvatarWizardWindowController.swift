import AppKit

final class AvatarWizardWindowController: NSWindowController, NSWindowDelegate {
    private enum CopyKey {
        static let stepOneTitle = "avatar_wizard.step_one_title"
        static let stepTwoTitle = "avatar_wizard.step_two_title"
        static let stepThreeTitle = "avatar_wizard.step_three_title"
        static let initialStatus = "avatar_wizard.initial_status"
        static let optimizeButton = "avatar_wizard.optimize_button"
        static let stepTwoHint = "avatar_wizard.step_two_hint"
        static let actionPending = "avatar_wizard.action_pending"
        static let generatePersonaButton = "avatar_wizard.generate_persona_button"
        static let backButton = "avatar_wizard.back_button"
        static let nextButton = "avatar_wizard.next_button"
        static let saveAndUseButton = "avatar_wizard.save_and_use_button"
        static let cancelButton = "avatar_wizard.cancel_button"
        static let namePlaceholder = "avatar_wizard.name_placeholder"
        static let modelTokenPlaceholder = "avatar_wizard.model_token_placeholder"
        static let promptLabel = "avatar_wizard.prompt_label"
        static let optimizedPromptLabel = "avatar_wizard.optimized_prompt_label"
        static let modelLabel = "avatar_wizard.model_label"
        static let tokenLabel = "avatar_wizard.token_label"
        static let tokenHintLabel = "avatar_wizard.token_hint_label"
        static let actionButtonFormat = "avatar_wizard.action_button_format"
        static let previewTitle = "avatar_wizard.preview_title"
        static let nameLabel = "avatar_wizard.name_label"
        static let personaLabel = "avatar_wizard.persona_label"
        static let errorMissingPrompt = "avatar_wizard.error_missing_prompt"
        static let optimizingStatus = "avatar_wizard.optimizing_status"
        static let optimizedStatus = "avatar_wizard.optimized_status"
        static let errorMissingOptimizedPrompt = "avatar_wizard.error_missing_optimized_prompt"
        static let generatingStatus = "avatar_wizard.generating_status"
        static let generatingImageStatusFormat = "avatar_wizard.generating_image_status_format"
        static let generatedStatus = "avatar_wizard.generated_status"
        static let generatedImageStatusFormat = "avatar_wizard.generated_image_status_format"
        static let generationFailedStatus = "avatar_wizard.generation_failed_status"
        static let generatingPersonaStatus = "avatar_wizard.generating_persona_status"
        static let generatedPersonaStatus = "avatar_wizard.generated_persona_status"
        static let errorMissingOptimizedPromptBeforeNext = "avatar_wizard.error_missing_optimized_prompt_before_next"
        static let errorMissingActions = "avatar_wizard.error_missing_actions"
        static let errorMissingName = "avatar_wizard.error_missing_name"
        static let fallbackModelName = "avatar_wizard.fallback_model_name"
        static let actionIdleLabel = "avatar_wizard.action_idle_label"
        static let actionWorkingLabel = "avatar_wizard.action_working_label"
        static let actionAlertLabel = "avatar_wizard.action_alert_label"
    }

    private enum StatusTone {
        case muted
        case accent
        case success
        case error
    }

    private let bridge: AvatarBuilderBridge
    private let settingsStore: AvatarSettingsStore
    private var models: [BridgeImageModel]
    private let assetStore: AvatarAssetStore
    private let onSave: (String) -> Void
    private let onClose: () -> Void
    private let sessionID = UUID().uuidString

    private var stepTitleLabel = AvatarPanelTheme.makeTitleLabel(
        TextCatalog.shared.text(CopyKey.stepOneTitle, fallback: "步骤 1/3：优化提示词")
    )
    private var statusLabel = AvatarPanelTheme.makeLabel(
        TextCatalog.shared.text(CopyKey.initialStatus, fallback: "填写描述后即可开始。"),
        color: AvatarPanelTheme.muted
    )
    private var statusTone: StatusTone = .muted

    private let promptInput = NSTextView()
    private let optimizedPromptView = NSTextView()
    private let optimizeButton = NSButton(
        title: TextCatalog.shared.text(CopyKey.optimizeButton, fallback: "优化提示词"),
        target: nil,
        action: nil
    )

    private let modelPopup = NSPopUpButton()
    private let modelTokenField = NSSecureTextField(string: "")
    private let previewImageView = NSImageView()
    private var stepTwoHintLabel = AvatarPanelTheme.makeLabel(
        TextCatalog.shared.text(CopyKey.stepTwoHint, fallback: "请生成 `idle / working / alert` 三个动作。"),
        color: AvatarPanelTheme.muted
    )
    private var actionStatusLabels: [String: NSTextField] = [:]
    private var actionButtons: [String: NSButton] = [:]
    private var actionStatusTexts: [String: String] = [
        "idle": TextCatalog.shared.text(CopyKey.actionPending, fallback: "未生成"),
        "working": TextCatalog.shared.text(CopyKey.actionPending, fallback: "未生成"),
        "alert": TextCatalog.shared.text(CopyKey.actionPending, fallback: "未生成"),
    ]
    private var actionButtonEnabledStates: [String: Bool] = [
        "idle": true,
        "working": true,
        "alert": true,
    ]
    private var actionStatusTones: [String: StatusTone] = [
        "idle": .muted,
        "working": .muted,
        "alert": .muted,
    ]

    private let nameField = NSTextField(string: "")
    private let personaTextView = NSTextView()
    private let generatePersonaButton = NSButton(
        title: TextCatalog.shared.text(CopyKey.generatePersonaButton, fallback: "生成人设"),
        target: nil,
        action: nil
    )

    private let backButton = NSButton(
        title: TextCatalog.shared.text(CopyKey.backButton, fallback: "上一步"),
        target: nil,
        action: nil
    )
    private let nextButton = NSButton(
        title: TextCatalog.shared.text(CopyKey.nextButton, fallback: "下一步"),
        target: nil,
        action: nil
    )
    private let cancelButton = NSButton(
        title: TextCatalog.shared.text(CopyKey.cancelButton, fallback: "取消"),
        target: nil,
        action: nil
    )
    private var cancelButtonWidthConstraint: NSLayoutConstraint?
    private var backButtonWidthConstraint: NSLayoutConstraint?
    private var nextButtonWidthConstraint: NSLayoutConstraint?

    private var stepViews: [NSView] = []
    private var stepIndex = 0
    private var generatedActionImageURLs: [String: URL] = [:]
    private var themeObserver: NSObjectProtocol?
    private var didFinish = false

    init(
        bridge: AvatarBuilderBridge,
        models: [BridgeImageModel],
        settingsStore: AvatarSettingsStore,
        assetStore: AvatarAssetStore,
        onSave: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.bridge = bridge
        self.models = models
        self.settingsStore = settingsStore
        self.assetStore = assetStore
        self.onSave = onSave
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        AvatarPanelTheme.styleWindow(window)
        super.init(window: window)
        window.delegate = self

        buildUI()
        populateSelectedModelFields()
        updateStepUI()
        refreshActionStatusLabels()
        subscribeToThemeChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    func present() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if !didFinish {
            onClose()
        }
    }

    private func buildUI() {
        guard
            let window,
            let contentView = window.contentView
        else {
            return
        }

        AvatarPanelTheme.styleWindow(window)
        contentView.subviews.forEach { $0.removeFromSuperview() }
        stepViews.removeAll()
        actionStatusLabels.removeAll()
        actionButtons.removeAll()

        let currentStepTitle = stepTitleLabel.stringValue
        stepTitleLabel = AvatarPanelTheme.makeTitleLabel(currentStepTitle)
        stepTitleLabel.alignment = .left
        let currentStatusText = statusLabel.stringValue
        statusLabel = AvatarPanelTheme.makeLabel(currentStatusText, color: color(for: statusTone))
        stepTwoHintLabel = AvatarPanelTheme.makeLabel(
            copy(CopyKey.stepTwoHint, "请生成 `idle / working / alert` 三个动作。"),
            color: AvatarPanelTheme.muted
        )

        optimizeButton.target = self
        optimizeButton.action = #selector(handleOptimizePrompt)
        AvatarPanelTheme.stylePrimaryButton(optimizeButton)

        generatePersonaButton.target = self
        generatePersonaButton.action = #selector(handleGeneratePersona)
        AvatarPanelTheme.styleSecondaryButton(generatePersonaButton)

        backButton.target = self
        backButton.action = #selector(handleBack)
        nextButton.target = self
        nextButton.action = #selector(handleNext)
        cancelButton.target = self
        cancelButton.action = #selector(handleCancel)
        AvatarPanelTheme.styleSecondaryButton(backButton)
        AvatarPanelTheme.stylePrimaryButton(nextButton)
        AvatarPanelTheme.styleSecondaryButton(cancelButton)

        AvatarPanelTheme.styleTextView(promptInput)
        AvatarPanelTheme.styleTextView(optimizedPromptView)
        AvatarPanelTheme.styleTextView(personaTextView)
        AvatarPanelTheme.styleEditableTextField(nameField)
        AvatarPanelTheme.styleEditableTextField(modelTokenField)
        optimizeButton.title = copy(CopyKey.optimizeButton, "优化提示词")
        generatePersonaButton.title = copy(CopyKey.generatePersonaButton, "生成人设")
        backButton.title = copy(CopyKey.backButton, "上一步")
        cancelButton.title = copy(CopyKey.cancelButton, "取消")
        nameField.placeholderString = copy(CopyKey.namePlaceholder, "例如：淡定水豚")
        modelTokenField.placeholderString = copy(CopyKey.modelTokenPlaceholder, "如模型需要鉴权，请填写 Hugging Face Token")

        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        modelPopup.font = AvatarPanelTheme.bodyFont

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let header = NSStackView(views: [stepTitleLabel, statusLabel])
        header.orientation = .vertical
        header.spacing = 6

        let stepContainer = AvatarPanelTheme.makeCard()
        stepContainer.translatesAutoresizingMaskIntoConstraints = false
        buildStepViews(in: stepContainer)

        let buttons = NSStackView(views: [cancelButton, backButton, NSView(), nextButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        root.addArrangedSubview(header)
        root.addArrangedSubview(stepContainer)
        root.addArrangedSubview(buttons)

        applyStatusLabelStyle()
        ensureButtonWidthConstraints()

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            stepContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 470),
        ])
    }

    private func buildStepViews(in container: NSView) {
        let stepOne = buildStepOneView()
        let stepTwo = buildStepTwoView()
        let stepThree = buildStepThreeView()
        stepViews = [stepOne, stepTwo, stepThree]

        for stepView in stepViews {
            stepView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(stepView)
            NSLayoutConstraint.activate([
                stepView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
                stepView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                stepView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                stepView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            ])
        }
    }

    private func buildStepOneView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 12

        let promptLabel = AvatarPanelTheme.makeLabel(copy(CopyKey.promptLabel, "1. 描述你想要的桌宠形象"), color: AvatarPanelTheme.accent)
        let promptScroll = makeTextScrollView(textView: promptInput, minHeight: 120)
        let optimizedLabel = AvatarPanelTheme.makeLabel(copy(CopyKey.optimizedPromptLabel, "2. 优化后的英文提示词"), color: AvatarPanelTheme.accent)
        let optimizedScroll = makeTextScrollView(textView: optimizedPromptView, minHeight: 200)
        optimizedPromptView.isEditable = true

        view.addArrangedSubview(promptLabel)
        view.addArrangedSubview(promptScroll)
        view.addArrangedSubview(optimizeButton)
        view.addArrangedSubview(optimizedLabel)
        view.addArrangedSubview(optimizedScroll)
        return view
    }

    private func buildStepTwoView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 12

        let modelLabel = AvatarPanelTheme.makeLabel(copy(CopyKey.modelLabel, "选择图像模型"), color: AvatarPanelTheme.accent)
        modelPopup.font = AvatarPanelTheme.bodyFont
        refreshModelPopup()
        modelPopup.target = self
        modelPopup.action = #selector(handleModelSelectionChanged)

        let modelRow = NSStackView(views: [modelLabel, modelPopup, NSView()])
        modelRow.orientation = .horizontal
        modelRow.spacing = 12

        let tokenLabel = AvatarPanelTheme.makeLabel(copy(CopyKey.tokenLabel, "Hugging Face Token"), color: AvatarPanelTheme.accent)
        let tokenHintLabel = AvatarPanelTheme.makeLabel(
            copy(CopyKey.tokenHintLabel, "如果当前图像模型需要鉴权，请在这里填写。点击生成时会自动保存到当前模型配置。"),
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )

        let actionsCard = AvatarPanelTheme.makeCard()
        actionsCard.translatesAutoresizingMaskIntoConstraints = false
        let actionsStack = NSStackView()
        actionsStack.orientation = .vertical
        actionsStack.spacing = 12
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsCard.addSubview(actionsStack)

        for action in ["idle", "working", "alert"] {
            let button = NSButton(
                title: String(format: copy(CopyKey.actionButtonFormat, "生成 %@"), actionDisplayName(action)),
                target: self,
                action: #selector(handleGenerateAction(_:))
            )
            button.identifier = NSUserInterfaceItemIdentifier(action)
            AvatarPanelTheme.styleSecondaryButton(button)
            button.isEnabled = actionButtonEnabledStates[action] ?? true
            actionButtons[action] = button
            let status = AvatarPanelTheme.makeLabel(
                actionStatusTexts[action] ?? copy(CopyKey.actionPending, "未生成"),
                color: color(for: actionStatusTones[action] ?? .muted),
                font: AvatarPanelTheme.smallFont
            )
            actionStatusLabels[action] = status

            let row = NSStackView(views: [button, status, NSView()])
            row.orientation = .horizontal
            row.spacing = 12
            actionsStack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: actionsCard.topAnchor, constant: 16),
            actionsStack.leadingAnchor.constraint(equalTo: actionsCard.leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: actionsCard.trailingAnchor, constant: -16),
            actionsStack.bottomAnchor.constraint(equalTo: actionsCard.bottomAnchor, constant: -16),
        ])

        let previewCard = AvatarPanelTheme.makeCard()
        previewCard.translatesAutoresizingMaskIntoConstraints = false
        let previewTitle = AvatarPanelTheme.makeLabel(copy(CopyKey.previewTitle, "最新预览"), color: AvatarPanelTheme.accent)
        previewTitle.translatesAutoresizingMaskIntoConstraints = false
        let previewFrame = NSView()
        previewFrame.translatesAutoresizingMaskIntoConstraints = false
        AvatarPanelTheme.styleImageFrame(previewFrame)
        previewCard.addSubview(previewTitle)
        previewCard.addSubview(previewFrame)
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewFrame.addSubview(previewImageView)

        NSLayoutConstraint.activate([
            previewTitle.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 16),
            previewTitle.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewTitle.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            previewFrame.topAnchor.constraint(equalTo: previewTitle.bottomAnchor, constant: 12),
            previewFrame.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewFrame.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            previewFrame.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -16),
            previewImageView.centerXAnchor.constraint(equalTo: previewFrame.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: previewFrame.centerYAnchor),
            previewImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
            previewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 220),
        ])

        let contentRow = NSStackView(views: [actionsCard, previewCard])
        contentRow.orientation = .horizontal
        contentRow.spacing = 16
        contentRow.distribution = .fillEqually

        view.addArrangedSubview(modelRow)
        view.addArrangedSubview(tokenLabel)
        view.addArrangedSubview(modelTokenField)
        view.addArrangedSubview(tokenHintLabel)
        view.addArrangedSubview(stepTwoHintLabel)
        view.addArrangedSubview(contentRow)
        return view
    }

    private func buildStepThreeView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 12

        let nameLabel = AvatarPanelTheme.makeLabel(copy(CopyKey.nameLabel, "形象名称"), color: AvatarPanelTheme.accent)
        let personaLabel = AvatarPanelTheme.makeLabel(copy(CopyKey.personaLabel, "人设描述（可编辑）"), color: AvatarPanelTheme.accent)
        let personaScroll = makeTextScrollView(textView: personaTextView, minHeight: 240)

        view.addArrangedSubview(nameLabel)
        view.addArrangedSubview(nameField)
        view.addArrangedSubview(generatePersonaButton)
        view.addArrangedSubview(personaLabel)
        view.addArrangedSubview(personaScroll)
        return view
    }

    private func makeTextScrollView(textView: NSTextView, minHeight: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView()
        AvatarPanelTheme.styleScrollView(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        return scrollView
    }

    private func updateStepUI() {
        for (index, stepView) in stepViews.enumerated() {
            stepView.isHidden = index != stepIndex
        }

        switch stepIndex {
        case 0:
            stepTitleLabel.stringValue = copy(CopyKey.stepOneTitle, "步骤 1/3：优化提示词")
            nextButton.title = copy(CopyKey.nextButton, "下一步")
        case 1:
            stepTitleLabel.stringValue = copy(CopyKey.stepTwoTitle, "步骤 2/3：生成动作图")
            nextButton.title = copy(CopyKey.nextButton, "下一步")
        default:
            stepTitleLabel.stringValue = copy(CopyKey.stepThreeTitle, "步骤 3/3：生成人设并保存")
            nextButton.title = copy(CopyKey.saveAndUseButton, "保存并使用")
        }

        backButton.isEnabled = stepIndex > 0
    }

    @objc private func handleOptimizePrompt() {
        let userText = promptInput.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else {
            showError(message: copy(CopyKey.errorMissingPrompt, "请先输入形象描述。"))
            return
        }

        optimizeButton.isEnabled = false
        setStatusMessage(copy(CopyKey.optimizingStatus, "正在优化提示词..."), tone: .accent)
        runAsync {
            try self.bridge.optimizePrompt(userText)
        } completion: { result in
            self.optimizeButton.isEnabled = true
            switch result {
            case let .success(prompt):
                self.optimizedPromptView.string = prompt
                self.setStatusMessage(self.copy(CopyKey.optimizedStatus, "提示词优化完成。"), tone: .success)
            case let .failure(error):
                self.showError(error: error)
            }
        }
    }

    @objc private func handleGenerateAction(_ sender: NSButton) {
        guard let action = sender.identifier?.rawValue else {
            return
        }

        let optimizedPrompt = optimizedPromptView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !optimizedPrompt.isEmpty else {
            showError(message: copy(CopyKey.errorMissingOptimizedPrompt, "请先完成提示词优化。"))
            return
        }

        let model = selectedModel()
        do {
            try persistSelectedModelConfigurationIfNeeded(using: model)
        } catch {
            showError(error: error)
            return
        }

        setActionButtonEnabled(action, isEnabled: false)
        setActionStatus(action, text: copy(CopyKey.generatingStatus, "生成中..."), tone: .accent)
        setStatusMessage(
            String(format: copy(CopyKey.generatingImageStatusFormat, "正在生成 %@ 图像..."), actionDisplayName(action)),
            tone: .accent
        )

        runAsync {
            try self.bridge.generateImage(
                prompt: "\(optimizedPrompt), \(action) pose, single character, centered, solid white background, high contrast, clean edges",
                model: model,
                sessionID: self.sessionID
            )
        } completion: { result in
            self.setActionButtonEnabled(action, isEnabled: true)
            switch result {
            case let .success(url):
                self.generatedActionImageURLs[action] = url
                self.setActionStatus(action, text: self.copy(CopyKey.generatedStatus, "已生成"), tone: .success)
                self.previewImageView.image = NSImage(contentsOf: url)
                self.setStatusMessage(
                    String(
                        format: self.copy(CopyKey.generatedImageStatusFormat, "%@ 图像生成完成。"),
                        self.actionDisplayName(action)
                    ),
                    tone: .success
                )
            case let .failure(error):
                self.setActionStatus(action, text: self.copy(CopyKey.generationFailedStatus, "生成失败"), tone: .error)
                self.showError(error: error)
            }
        }
    }

    @objc private func handleModelSelectionChanged() {
        populateSelectedModelFields()
    }

    @objc private func handleGeneratePersona() {
        let userText = promptInput.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else {
            showError(message: copy(CopyKey.errorMissingPrompt, "请先输入形象描述。"))
            return
        }

        generatePersonaButton.isEnabled = false
        setStatusMessage(copy(CopyKey.generatingPersonaStatus, "正在生成人设..."), tone: .accent)
        runAsync {
            try self.bridge.generatePersona(userText)
        } completion: { result in
            self.generatePersonaButton.isEnabled = true
            switch result {
            case let .success(persona):
                self.personaTextView.string = persona
                self.setStatusMessage(self.copy(CopyKey.generatedPersonaStatus, "人设生成完成。"), tone: .success)
            case let .failure(error):
                self.showError(error: error)
            }
        }
    }

    @objc private func handleBack() {
        guard stepIndex > 0 else {
            return
        }
        stepIndex -= 1
        updateStepUI()
    }

    @objc private func handleNext() {
        if stepIndex < 2 {
            guard validateCurrentStep() else {
                return
            }

            stepIndex += 1
            updateStepUI()
            return
        }

        guard validateCurrentStep() else {
            return
        }

        do {
            let avatarID = try assetStore.saveCustomAvatar(
                name: nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                persona: personaTextView.string.trimmingCharacters(in: .whitespacesAndNewlines),
                generatedActionImageURLs: generatedActionImageURLs
            )
            didFinish = true
            onSave(avatarID)
            close()
        } catch {
            showError(error: error)
        }
    }

    @objc private func handleCancel() {
        didFinish = true
        onClose()
        close()
    }

    private func validateCurrentStep() -> Bool {
        switch stepIndex {
        case 0:
            guard !optimizedPromptView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                showError(message: copy(CopyKey.errorMissingOptimizedPromptBeforeNext, "请先生成优化后的提示词。"))
                return false
            }
        case 1:
            let requiredActions = Set(["idle", "working", "alert"])
            guard Set(generatedActionImageURLs.keys).isSuperset(of: requiredActions) else {
                showError(message: copy(CopyKey.errorMissingActions, "请先生成三个动作图。"))
                return false
            }
        default:
            guard !nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                showError(message: copy(CopyKey.errorMissingName, "请先填写形象名称。"))
                return false
            }
        }

        return true
    }

    private func refreshModelPopup() {
        let selectedTitle = modelPopup.titleOfSelectedItem
        modelPopup.removeAllItems()
        for model in models {
            modelPopup.addItem(withTitle: model.name)
        }
        if let selectedTitle, modelPopup.itemTitles.contains(selectedTitle) {
            modelPopup.selectItem(withTitle: selectedTitle)
        }
    }

    private func populateSelectedModelFields() {
        modelTokenField.stringValue = storedSelectedModel().token
    }

    private func selectedModel() -> BridgeImageModel {
        var model = storedSelectedModel()
        model.token = modelTokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return model
    }

    private func storedSelectedModel() -> BridgeImageModel {
        let selectedIndex = max(modelPopup.indexOfSelectedItem, 0)
        if models.indices.contains(selectedIndex) {
            return models[selectedIndex]
        }

        return BridgeImageModel(
            name: copy(CopyKey.fallbackModelName, "Stable Diffusion XL"),
            url: "stabilityai/stable-diffusion-xl-base-1.0",
            token: ""
        )
    }

    private func persistSelectedModelConfigurationIfNeeded(using model: BridgeImageModel) throws {
        let selectedIndex = max(modelPopup.indexOfSelectedItem, 0)
        guard models.indices.contains(selectedIndex) else {
            return
        }

        guard models[selectedIndex] != model else {
            return
        }

        models[selectedIndex] = model
        try settingsStore.saveImageModels(models)
    }

    private func runAsync<T>(
        _ work: @escaping () throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let value = try work()
                DispatchQueue.main.async {
                    completion(.success(value))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func showError(error: Error) {
        showError(message: UserFacingErrorCopy.avatarMessage(for: error))
    }

    private func showError(message: String) {
        NSSound.beep()
        setStatusMessage(message, tone: .error)
    }

    private func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.buildUI()
            self?.updateStepUI()
            self?.refreshActionStatusLabels()
        }
    }

    private func setStatusMessage(_ text: String, tone: StatusTone) {
        statusLabel.stringValue = text
        statusTone = tone
        applyStatusLabelStyle()
    }

    private func applyStatusLabelStyle() {
        statusLabel.textColor = color(for: statusTone)
        statusLabel.font = AvatarPanelTheme.bodyFont
    }

    private func setActionStatus(_ action: String, text: String, tone: StatusTone) {
        actionStatusTexts[action] = text
        actionStatusTones[action] = tone

        guard let label = actionStatusLabels[action] else {
            return
        }

        label.stringValue = text
        label.textColor = color(for: tone)
        label.font = AvatarPanelTheme.smallFont
    }

    private func refreshActionStatusLabels() {
        for action in ["idle", "working", "alert"] {
            if generatedActionImageURLs[action] != nil, actionStatusTexts[action] == copy(CopyKey.actionPending, "未生成") {
                actionStatusTexts[action] = copy(CopyKey.generatedStatus, "已生成")
                actionStatusTones[action] = .success
            }

            if let label = actionStatusLabels[action] {
                label.stringValue = actionStatusTexts[action] ?? copy(CopyKey.actionPending, "未生成")
                label.textColor = color(for: actionStatusTones[action] ?? .muted)
                label.font = AvatarPanelTheme.smallFont
            }
        }
    }

    private func setActionButtonEnabled(_ action: String, isEnabled: Bool) {
        actionButtonEnabledStates[action] = isEnabled
        actionButtons[action]?.isEnabled = isEnabled
    }

    private func copy(_ key: String, _ fallback: String) -> String {
        TextCatalog.shared.text(key, fallback: fallback)
    }

    private func actionDisplayName(_ action: String) -> String {
        switch action {
        case "idle":
            return copy(CopyKey.actionIdleLabel, "idle")
        case "working":
            return copy(CopyKey.actionWorkingLabel, "working")
        case "alert":
            return copy(CopyKey.actionAlertLabel, "alert")
        default:
            return action
        }
    }

    private func ensureButtonWidthConstraints() {
        if cancelButtonWidthConstraint == nil {
            cancelButtonWidthConstraint = cancelButton.widthAnchor.constraint(equalToConstant: 96)
            cancelButtonWidthConstraint?.isActive = true
        }

        if backButtonWidthConstraint == nil {
            backButtonWidthConstraint = backButton.widthAnchor.constraint(equalToConstant: 96)
            backButtonWidthConstraint?.isActive = true
        }

        if nextButtonWidthConstraint == nil {
            nextButtonWidthConstraint = nextButton.widthAnchor.constraint(equalToConstant: 140)
            nextButtonWidthConstraint?.isActive = true
        }
    }

    private func color(for tone: StatusTone) -> NSColor {
        switch tone {
        case .muted:
            return AvatarPanelTheme.muted
        case .accent:
            return AvatarPanelTheme.accent
        case .success:
            return AvatarPanelTheme.text
        case .error:
            return AvatarPanelTheme.danger
        }
    }
}
