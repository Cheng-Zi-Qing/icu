import AppKit

final class AvatarStudioContentView: NSView {
    private let avatarPromptOptimizer: ((String) throws -> String)?
    private let avatarPreviewGenerator: ((String) throws -> InlineAvatarPreviewDraft)?
    private let avatarSaveHandler: ((InlineAvatarSaveRequest) throws -> String)?
    private let onChooseAvatar: (String) throws -> Void
    private let onOpenAvatarPicker: () -> Void

    private var avatars: [AvatarSummary]
    private var currentAvatarID: String?

    private let sectionLabel = AvatarPanelTheme.makeTitleLabel("当前分区：形象生成")
    private let statusLabel = AvatarPanelTheme.makeLabel(
        TextCatalog.shared.text("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。"),
        color: AvatarPanelTheme.muted
    )

    private var referencePreviewImageView = NSImageView()
    private var referenceNameLabel = AvatarPanelTheme.makeTitleLabel("")
    private var referenceStyleLabel = AvatarPanelTheme.makeLabel("", color: AvatarPanelTheme.muted)
    private var referenceTraitsLabel = AvatarPanelTheme.makeLabel("")
    private weak var openPickerButton: NSButton?

    private let avatarCreateRawPromptView = NSTextView()
    private let avatarCreateOptimizedPromptView = NSTextView()
    private let avatarCreateNameField = NSTextField(string: "")
    private let avatarCreatePersonaField = NSTextField(string: "")
    private var createActionStatusLabel = AvatarPanelTheme.makeLabel("")
    private var actionImageViews: [String: NSImageView] = [:]
    private var actionStatusValueLabels: [String: NSTextField] = [:]
    private weak var avatarCreateOptimizeButton: NSButton?
    private weak var avatarCreatePreviewButton: NSButton?
    private weak var avatarCreateRegenerateButton: NSButton?
    private weak var avatarCreateSaveButton: NSButton?

    private var creationRawPrompt = ""
    private var creationOptimizedPrompt = ""
    private var creationPreviewDraft: InlineAvatarPreviewDraft?
    private var creationDraftName = ""
    private var creationDraftPersona = ""
    private var previousSuggestedPersona = ""
    private var creationStage: InlineAvatarCreationStage = .empty
    private var isInlineAvatarPreviewInFlight = false
    private var inlineAvatarPreviewRequestID: UUID?
    private var isInlineAvatarSaveInFlight = false
    private var previewRevision = 0
    private var avatarDraftSummary = TextCatalog.shared.text(
        "avatar_studio.draft_placeholder",
        fallback: "尚未生成新的形象草稿。"
    )

    init(
        avatars: [AvatarSummary],
        currentAvatarID: String?,
        avatarPromptOptimizer: ((String) throws -> String)? = nil,
        avatarPreviewGenerator: ((String) throws -> InlineAvatarPreviewDraft)? = nil,
        avatarSaveHandler: ((InlineAvatarSaveRequest) throws -> String)? = nil,
        onChooseAvatar: @escaping (String) throws -> Void = { _ in },
        onOpenAvatarPicker: @escaping () -> Void = {}
    ) {
        self.avatars = avatars
        self.currentAvatarID = currentAvatarID
        self.avatarPromptOptimizer = avatarPromptOptimizer
        self.avatarPreviewGenerator = avatarPreviewGenerator
        self.avatarSaveHandler = avatarSaveHandler
        self.onChooseAvatar = onChooseAvatar
        self.onOpenAvatarPicker = onOpenAvatarPicker
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        configureTextView(avatarCreateRawPromptView, identifier: "avatarCreateRawPrompt")
        configureTextView(avatarCreateOptimizedPromptView, identifier: "avatarCreateOptimizedPrompt")
        configureTextField(avatarCreateNameField, identifier: "avatarCreateNameField")
        configureTextField(avatarCreatePersonaField, identifier: "avatarCreatePersonaField")

        buildUI()
        refreshReferenceAvatarCard()
        updateCreateModeUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTextViewDelegate(_ delegate: NSTextViewDelegate?) {
        avatarCreateRawPromptView.delegate = delegate
        avatarCreateOptimizedPromptView.delegate = delegate
    }

    func handleTextDidChange(_ textView: NSTextView) {
        switch textView.identifier?.rawValue {
        case "avatarCreateRawPrompt":
            creationRawPrompt = textView.string
            if creationStage == .empty && !normalizedPrompt(creationRawPrompt, fallback: "").isEmpty {
                creationStage = .drafted
            }
        case "avatarCreateOptimizedPrompt":
            creationOptimizedPrompt = textView.string
            invalidateInlineAvatarPreview()
        default:
            return
        }

        updateCreateModeUI()
    }

    func updateAvatars(_ avatars: [AvatarSummary], currentAvatarID: String?) {
        self.avatars = avatars
        self.currentAvatarID = currentAvatarID
        refreshReferenceAvatarCard()
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        root.addArrangedSubview(sectionLabel)
        root.addArrangedSubview(buildReferenceCard())
        buildCreateContainer(in: root)
        root.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    private func buildReferenceCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(root)

        root.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("avatar_studio.applied_summary_title", fallback: "当前已应用形象"),
                color: AvatarPanelTheme.accent
            )
        )

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .top

        let imageFrame = NSView()
        imageFrame.translatesAutoresizingMaskIntoConstraints = false
        AvatarPanelTheme.styleImageFrame(imageFrame)
        imageFrame.widthAnchor.constraint(equalToConstant: 120).isActive = true
        imageFrame.heightAnchor.constraint(equalToConstant: 120).isActive = true
        referencePreviewImageView.translatesAutoresizingMaskIntoConstraints = false
        referencePreviewImageView.imageScaling = .scaleProportionallyUpOrDown
        imageFrame.addSubview(referencePreviewImageView)
        NSLayoutConstraint.activate([
            referencePreviewImageView.centerXAnchor.constraint(equalTo: imageFrame.centerXAnchor),
            referencePreviewImageView.centerYAnchor.constraint(equalTo: imageFrame.centerYAnchor),
            referencePreviewImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 108),
            referencePreviewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 108),
        ])
        row.addArrangedSubview(imageFrame)

        let infoStack = NSStackView(views: [referenceNameLabel, referenceStyleLabel, referenceTraitsLabel])
        infoStack.orientation = .vertical
        infoStack.spacing = 8
        row.addArrangedSubview(infoStack)

        root.addArrangedSubview(row)

        let openPickerButton = NSButton(
            title: copy("avatar_studio.open_picker_button", fallback: "打开更换形象"),
            target: self,
            action: #selector(handleOpenPicker)
        )
        AvatarPanelTheme.styleSecondaryButton(openPickerButton)
        openPickerButton.widthAnchor.constraint(equalToConstant: 132).isActive = true
        self.openPickerButton = openPickerButton
        root.addArrangedSubview(openPickerButton)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func buildCreateContainer(in root: NSStackView) {
        createActionStatusLabel = AvatarPanelTheme.makeLabel(
            avatarDraftSummary,
            color: AvatarPanelTheme.text
        )

        avatarCreateNameField.placeholderString = copy("avatar_studio.create_name_placeholder", fallback: "例如：淡定水豚")
        avatarCreatePersonaField.placeholderString = copy("avatar_studio.create_persona_placeholder", fallback: "预览后会自动填入建议人设，可继续编辑。")

        root.addArrangedSubview(
            makePromptSection(
                title: copy("avatar_studio.create_prompt_title", fallback: "原始 prompt"),
                hint: copy("avatar_studio.create_prompt_hint", fallback: "描述你想生成的形象、动作和动画关键词。"),
                textView: avatarCreateRawPromptView,
                minHeight: 96
            )
        )
        root.addArrangedSubview(
            makePromptSection(
                title: copy("avatar_studio.create_optimized_prompt_title", fallback: "优化后 prompt"),
                hint: copy("avatar_studio.create_optimized_prompt_hint", fallback: "优化后的 prompt 会用于生成 idle / working / alert 三组预览。"),
                textView: avatarCreateOptimizedPromptView,
                minHeight: 96
            )
        )
        root.addArrangedSubview(makeActionPreviewCard())
        root.addArrangedSubview(makeFieldCard())
        root.addArrangedSubview(createActionStatusLabel)
        root.addArrangedSubview(makeCreateActionBar())
    }

    private func configureTextView(_ textView: NSTextView, identifier: String) {
        AvatarPanelTheme.styleTextView(textView)
        textView.identifier = NSUserInterfaceItemIdentifier(identifier)
        textView.isRichText = false
        textView.string = ""
    }

    private func configureTextField(_ textField: NSTextField, identifier: String) {
        AvatarPanelTheme.styleEditableTextField(textField)
        textField.identifier = NSUserInterfaceItemIdentifier(identifier)
        textField.target = self
        textField.action = #selector(handleFieldAction(_:))
    }

    private func makePromptSection(
        title: String,
        hint: String,
        textView: NSTextView,
        minHeight: CGFloat
    ) -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(title, color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(hint, color: AvatarPanelTheme.muted, font: AvatarPanelTheme.smallFont))
        stack.addArrangedSubview(makeTextScrollView(textView: textView, minHeight: minHeight))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeTextScrollView(textView: NSTextView, minHeight: CGFloat) -> NSScrollView {
        let scrollView = NSScrollView()
        AvatarPanelTheme.styleScrollView(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        return scrollView
    }

    private func makeActionPreviewCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("avatar_studio.create_actions_title", fallback: "动作生成"), color: AvatarPanelTheme.accent))

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually

        for action in InlineAvatarCreation.requiredActions {
            let actionCard = AvatarPanelTheme.makeCard()
            let actionStack = NSStackView()
            actionStack.orientation = .vertical
            actionStack.spacing = 8
            actionStack.translatesAutoresizingMaskIntoConstraints = false
            actionCard.addSubview(actionStack)

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.heightAnchor.constraint(equalToConstant: 72).isActive = true

            let label = AvatarPanelTheme.makeLabel(action, color: AvatarPanelTheme.accent)
            let statusValueLabel = AvatarPanelTheme.makeLabel("", color: AvatarPanelTheme.text)

            actionImageViews[action] = imageView
            actionStatusValueLabels[action] = statusValueLabel

            actionStack.addArrangedSubview(label)
            actionStack.addArrangedSubview(imageView)
            actionStack.addArrangedSubview(statusValueLabel)

            NSLayoutConstraint.activate([
                actionStack.topAnchor.constraint(equalTo: actionCard.topAnchor, constant: 12),
                actionStack.leadingAnchor.constraint(equalTo: actionCard.leadingAnchor, constant: 12),
                actionStack.trailingAnchor.constraint(equalTo: actionCard.trailingAnchor, constant: -12),
                actionStack.bottomAnchor.constraint(equalTo: actionCard.bottomAnchor, constant: -12),
            ])

            row.addArrangedSubview(actionCard)
        }

        stack.addArrangedSubview(row)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeFieldCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("avatar_studio.create_name_title", fallback: "形象名称"), color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(avatarCreateNameField)
        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("avatar_studio.create_persona_title", fallback: "人设描述"), color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(avatarCreatePersonaField)
        stack.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("avatar_studio.create_save_info_title", fallback: "保存后将自动应用这个新形象。"),
                color: AvatarPanelTheme.muted,
                font: AvatarPanelTheme.smallFont
            )
        )

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeCreateActionBar() -> NSView {
        let optimizeButton = NSButton(
            title: copy("avatar_studio.create_optimize_button", fallback: "优化 prompt"),
            target: self,
            action: #selector(handleOptimizeInlineAvatarPrompt)
        )
        let previewButton = NSButton(
            title: TextCatalog.shared.text(.commonPreviewButton),
            target: self,
            action: #selector(handleGeneratePreview)
        )
        let regenerateButton = NSButton(
            title: TextCatalog.shared.text(.commonRegenerateButton),
            target: self,
            action: #selector(handleRegeneratePreview)
        )
        let saveAndApplyButton = NSButton(
            title: copy("avatar_studio.save_and_apply_button", fallback: "保存并应用"),
            target: self,
            action: #selector(handleSaveAndApplyInlineAvatar)
        )

        AvatarPanelTheme.styleSecondaryButton(optimizeButton)
        AvatarPanelTheme.styleSecondaryButton(previewButton)
        AvatarPanelTheme.styleSecondaryButton(regenerateButton)
        AvatarPanelTheme.stylePrimaryButton(saveAndApplyButton)

        optimizeButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        previewButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        regenerateButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        saveAndApplyButton.widthAnchor.constraint(equalToConstant: 110).isActive = true

        avatarCreateOptimizeButton = optimizeButton
        avatarCreatePreviewButton = previewButton
        avatarCreateRegenerateButton = regenerateButton
        avatarCreateSaveButton = saveAndApplyButton

        let stack = NSStackView(views: [NSView(), optimizeButton, previewButton, regenerateButton, saveAndApplyButton])
        stack.orientation = .horizontal
        stack.spacing = 12
        return stack
    }

    private func currentAppliedAvatarSummary() -> AvatarSummary? {
        if let currentAvatarID {
            return avatars.first(where: { $0.id == currentAvatarID }) ?? avatars.first
        }
        return avatars.first
    }

    private func currentAvatarSummaryText() -> String {
        guard let avatar = currentAppliedAvatarSummary() else {
            return copy("avatar_studio.empty_summary", fallback: "暂无已应用形象。")
        }

        let styleValue = avatar.style.isEmpty ? copy("avatar_studio.missing_style_summary", fallback: "未标注风格") : avatar.style
        return "\(avatar.name) / \(styleValue)"
    }

    private func refreshReferenceAvatarCard() {
        guard let avatar = currentAppliedAvatarSummary() else {
            referenceNameLabel.stringValue = copy("avatar_studio.no_selection_title", fallback: "未选择形象")
            referenceStyleLabel.stringValue = ""
            referenceTraitsLabel.stringValue = copy("avatar_studio.empty_summary", fallback: "暂无已应用形象。")
            referencePreviewImageView.image = nil
            return
        }

        referenceNameLabel.stringValue = avatar.name
        let styleValue = avatar.style.isEmpty ? copy("avatar_studio.missing_style", fallback: "未标注") : avatar.style
        referenceStyleLabel.stringValue = formatCopy("avatar_studio.style_format", fallback: "风格：%@", styleValue)
        let toneText = avatar.tone.isEmpty ? "" : formatCopy("avatar_studio.tone_format", fallback: "\n语气：%@", avatar.tone)
        referenceTraitsLabel.stringValue = avatar.traits.isEmpty
            ? copy("avatar_studio.no_persona", fallback: "这个形象还没有 persona 摘要。")
            : formatCopy("avatar_studio.traits_format", fallback: "特质：%@%@", avatar.traits, toneText)
        referencePreviewImageView.image = NSImage(contentsOf: avatar.previewURL)
    }

    private func inlineAvatarActionStatusLines() -> [String] {
        let availableActions = creationPreviewDraft?.actionImageURLs ?? [:]
        return InlineAvatarCreation.requiredActions.map { action in
            let suffix = availableActions[action] == nil
                ? copy("avatar_wizard.action_pending", fallback: "未生成")
                : copy("avatar_wizard.generated_status", fallback: "已生成")
            return "\(action): \(suffix)"
        }
    }

    private func updateCreateModeUI() {
        avatarCreateRawPromptView.string = creationRawPrompt
        avatarCreateOptimizedPromptView.string = creationOptimizedPrompt
        avatarCreateNameField.stringValue = creationDraftName
        avatarCreatePersonaField.stringValue = creationDraftPersona
        createActionStatusLabel.stringValue = avatarDraftSummary

        let actionLines = inlineAvatarActionStatusLines()
        for (index, action) in InlineAvatarCreation.requiredActions.enumerated() {
            actionStatusValueLabels[action]?.stringValue = actionLines[index]
            actionImageViews[action]?.image = creationPreviewDraft?.actionImageURLs[action].flatMap { NSImage(contentsOf: $0) }
        }

        updateAvatarCreateActionButtonStates()
    }

    private func hasNonEmptyInlineAvatarOptimizedPrompt() -> Bool {
        !normalizedPrompt(creationOptimizedPrompt, fallback: "").isEmpty
    }

    private func hasCompleteInlineAvatarPreviewDraft() -> Bool {
        creationPreviewDraft?.hasRequiredActionImages == true
    }

    private func syncInlineAvatarStage() {
        if hasCompleteInlineAvatarPreviewDraft() {
            creationStage = .previewReady
        } else if hasNonEmptyInlineAvatarOptimizedPrompt() || !normalizedPrompt(creationRawPrompt, fallback: "").isEmpty {
            creationStage = .drafted
        } else {
            creationStage = .empty
        }
    }

    private func invalidateInlineAvatarPreview() {
        isInlineAvatarPreviewInFlight = false
        inlineAvatarPreviewRequestID = nil
        creationPreviewDraft = nil
        avatarDraftSummary = copy("avatar_studio.draft_placeholder", fallback: "尚未生成新的形象草稿。")
        syncInlineAvatarStage()
        updateCreateModeUI()
    }

    private func updateAvatarCreateActionButtonStates() {
        let hasName = !normalizedPrompt(creationDraftName, fallback: "").isEmpty
        let isBusy = isInlineAvatarPreviewInFlight || isInlineAvatarSaveInFlight
        avatarCreateOptimizeButton?.isEnabled = !isBusy
        avatarCreatePreviewButton?.isEnabled = !isBusy && hasNonEmptyInlineAvatarOptimizedPrompt()
        avatarCreateRegenerateButton?.isEnabled = !isBusy && creationPreviewDraft != nil
        avatarCreateSaveButton?.isEnabled = !isBusy && creationStage == .previewReady && hasName
    }

    private func renderOptimizedInlineAvatarPrompt() throws {
        let prompt = normalizedPrompt(
            creationRawPrompt,
            fallback: copy("avatar_studio.fallback_prompt", fallback: "保留当前形象，但增加 idle / working / alert 三组动作")
        )
        let optimized = if let avatarPromptOptimizer {
            try avatarPromptOptimizer(prompt)
        } else {
            prompt
        }

        creationOptimizedPrompt = optimized
        invalidateInlineAvatarPreview()
        statusLabel.stringValue = copy("avatar_studio.optimized_status", fallback: "prompt 优化完成。")
        statusLabel.textColor = AvatarPanelTheme.accent
        updateCreateModeUI()
    }

    private func makeFallbackInlineAvatarPreviewDraft() -> InlineAvatarPreviewDraft {
        let previewURL = currentAppliedAvatarSummary()?.previewURL ?? URL(fileURLWithPath: "/tmp/inline-avatar-preview-fallback.png")
        let suggestedPersona = currentAppliedAvatarSummary()?.traits.isEmpty == false
            ? currentAppliedAvatarSummary()?.traits ?? ""
            : copy("avatar_studio.no_persona", fallback: "这个形象还没有 persona 摘要。")
        return InlineAvatarPreviewDraft(
            actionImageURLs: [
                "idle": previewURL,
                "working": previewURL,
                "alert": previewURL,
            ],
            suggestedPersona: suggestedPersona
        )
    }

    private func generateInlineAvatarPreviewDraft(for prompt: String) throws -> InlineAvatarPreviewDraft {
        if let avatarPreviewGenerator {
            return try avatarPreviewGenerator(prompt)
        }

        _ = prompt
        return makeFallbackInlineAvatarPreviewDraft()
    }

    private func applyInlineAvatarPreviewDraft(_ draft: InlineAvatarPreviewDraft, regenerated: Bool, prompt: String) {
        let shouldReplacePersonaSuggestion = normalizedPrompt(creationDraftPersona, fallback: "").isEmpty
            || creationDraftPersona == previousSuggestedPersona

        creationPreviewDraft = draft
        if shouldReplacePersonaSuggestion {
            creationDraftPersona = draft.suggestedPersona
        }
        previousSuggestedPersona = draft.suggestedPersona
        syncInlineAvatarStage()
        previewRevision += 1
        avatarDraftSummary = formatCopy(
            "avatar_studio.draft_format",
            fallback: "草稿 %d：%@ / %@",
            previewRevision,
            normalizedPrompt(creationDraftName, fallback: currentAvatarSummaryText()),
            prompt
        )
        statusLabel.stringValue = regenerated
            ? copy("avatar_studio.preview_regenerated_status", fallback: "形象动画草稿已重新生成。")
            : copy("avatar_studio.preview_generated_status", fallback: "形象动画草稿已生成。")
        statusLabel.textColor = AvatarPanelTheme.accent
        updateCreateModeUI()
    }

    private func startInlineAvatarPreview(regenerated: Bool) {
        let prompt = normalizedPrompt(creationOptimizedPrompt, fallback: "")
        guard !prompt.isEmpty else {
            statusLabel.stringValue = copy("avatar_studio.preview_requires_optimized_status", fallback: "请先优化 prompt，再生成预览。")
            statusLabel.textColor = AvatarPanelTheme.muted
            return
        }

        guard !isInlineAvatarPreviewInFlight else {
            return
        }

        let requestID = UUID()
        inlineAvatarPreviewRequestID = requestID
        isInlineAvatarPreviewInFlight = true
        statusLabel.stringValue = copy("avatar_wizard.generating_status", fallback: "生成中...")
        statusLabel.textColor = AvatarPanelTheme.accent
        updateAvatarCreateActionButtonStates()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                return
            }

            let result = Result {
                try self.generateInlineAvatarPreviewDraft(for: prompt)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                guard self.inlineAvatarPreviewRequestID == requestID else {
                    return
                }

                self.inlineAvatarPreviewRequestID = nil
                self.isInlineAvatarPreviewInFlight = false

                switch result {
                case let .success(draft):
                    self.applyInlineAvatarPreviewDraft(draft, regenerated: regenerated, prompt: prompt)
                case let .failure(error):
                    self.updateAvatarCreateActionButtonStates()
                    self.showGenerationError(error)
                }
            }
        }
    }

    private func currentInlineAvatarSaveRequest() -> InlineAvatarSaveRequest? {
        guard
            creationStage == .previewReady,
            let previewDraft = creationPreviewDraft
        else {
            return nil
        }

        let name = normalizedPrompt(creationDraftName, fallback: "")
        guard !name.isEmpty else {
            return nil
        }

        return InlineAvatarSaveRequest(
            name: name,
            persona: creationDraftPersona.trimmingCharacters(in: .whitespacesAndNewlines),
            actionImageURLs: previewDraft.actionImageURLs
        )
    }

    private func resetInlineAvatarCreationDraft() {
        isInlineAvatarPreviewInFlight = false
        inlineAvatarPreviewRequestID = nil
        isInlineAvatarSaveInFlight = false
        creationRawPrompt = ""
        creationOptimizedPrompt = ""
        creationPreviewDraft = nil
        creationDraftName = ""
        creationDraftPersona = ""
        previousSuggestedPersona = ""
        creationStage = .empty
        avatarDraftSummary = copy("avatar_studio.draft_placeholder", fallback: "尚未生成新的形象草稿。")
        updateCreateModeUI()
    }

    private func updateInlineAvatarField(_ textField: NSTextField) {
        switch textField.identifier?.rawValue {
        case "avatarCreateNameField":
            creationDraftName = textField.stringValue
            updateAvatarCreateActionButtonStates()
        case "avatarCreatePersonaField":
            creationDraftPersona = textField.stringValue
        default:
            break
        }
        updateCreateModeUI()
    }

    private func completeSaveAndApply(with avatarID: String) {
        currentAvatarID = avatarID
        refreshReferenceAvatarCard()
        statusLabel.stringValue = copy("avatar_studio.save_success_status", fallback: "新形象已保存并应用。")
        statusLabel.textColor = AvatarPanelTheme.accent
        resetInlineAvatarCreationDraft()
    }

    private func showGenerationError(_ error: Error) {
        if error is AvatarBuilderBridgeError {
            statusLabel.stringValue = UserFacingErrorCopy.avatarMessage(for: error)
        } else {
            statusLabel.stringValue = error.localizedDescription
        }
        statusLabel.textColor = AvatarPanelTheme.danger
    }

    private func normalizedPrompt(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func copy(_ key: String, fallback: String) -> String {
        TextCatalog.shared.text(key, fallback: fallback)
    }

    private func formatCopy(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(format: copy(key, fallback: fallback), arguments: arguments)
    }

    @objc private func handleOpenPicker() {
        onOpenAvatarPicker()
    }

    @objc private func handleFieldAction(_ sender: NSTextField) {
        updateInlineAvatarField(sender)
    }

    @objc private func handleOptimizeInlineAvatarPrompt() {
        do {
            try renderOptimizedInlineAvatarPrompt()
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handleGeneratePreview() {
        startInlineAvatarPreview(regenerated: false)
    }

    @objc private func handleRegeneratePreview() {
        startInlineAvatarPreview(regenerated: true)
    }

    @objc private func handleSaveAndApplyInlineAvatar() {
        guard let request = currentInlineAvatarSaveRequest() else {
            statusLabel.stringValue = copy("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。")
            statusLabel.textColor = AvatarPanelTheme.muted
            return
        }

        guard let avatarSaveHandler else {
            syncInlineAvatarStage()
            updateAvatarCreateActionButtonStates()
            statusLabel.stringValue = copy(
                "avatar_studio.save_unavailable_status",
                fallback: "当前环境未接入形象保存能力，请稍后再试。"
            )
            statusLabel.textColor = AvatarPanelTheme.danger
            return
        }

        guard !isInlineAvatarSaveInFlight else {
            return
        }

        isInlineAvatarSaveInFlight = true
        creationStage = .saving
        updateAvatarCreateActionButtonStates()
        defer {
            isInlineAvatarSaveInFlight = false
            syncInlineAvatarStage()
            updateAvatarCreateActionButtonStates()
        }

        do {
            let avatarID = try avatarSaveHandler(request)
            try onChooseAvatar(avatarID)
            completeSaveAndApply(with: avatarID)
        } catch {
            showGenerationError(error)
        }
    }
}
