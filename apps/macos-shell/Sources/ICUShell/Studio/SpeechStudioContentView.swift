import AppKit

final class SpeechStudioContentView: NSView {
    private var currentAvatar: AvatarSummary?
    private let speechDraftGenerator: ((String) throws -> SpeechDraft)?
    private let speechDraftApplier: ((SpeechDraft) throws -> Void)?

    private let sectionLabel = AvatarPanelTheme.makeTitleLabel("当前分区：话术")
    private let statusLabel = AvatarPanelTheme.makeLabel(
        TextCatalog.shared.text("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。"),
        color: AvatarPanelTheme.muted
    )
    private let promptView = NSTextView()
    private let appliedSummaryValueLabel = AvatarPanelTheme.makeLabel("")
    private let draftSummaryValueLabel = AvatarPanelTheme.makeLabel("")
    private let bubblePreviewValueLabel = AvatarPanelTheme.makeLabel("")
    private weak var currentAvatarImageView: NSImageView?
    private weak var generateButton: NSButton?
    private weak var regenerateButton: NSButton?
    private weak var applyButton: NSButton?

    private var speechPrompt = ""
    private var pendingSpeechDraft: SpeechDraft?
    private var previewRevision = 0

    private var appliedSpeechSummary = TextCatalog.shared.text(
        "speech_studio.applied_summary_default",
        fallback: "今天也一起稳稳推进。"
    )
    private var draftSpeechSummary = TextCatalog.shared.text(
        "speech_studio.text_preview_placeholder",
        fallback: "尚未生成新的话术草稿。"
    )
    private var speechBubblePreviewText = TextCatalog.shared.text(
        "speech_studio.bubble_default",
        fallback: "今天也一起稳稳推进。"
    )

    init(
        currentAvatar: AvatarSummary?,
        speechDraftGenerator: ((String) throws -> SpeechDraft)? = nil,
        speechDraftApplier: ((SpeechDraft) throws -> Void)? = nil
    ) {
        self.currentAvatar = currentAvatar
        self.speechDraftGenerator = speechDraftGenerator
        self.speechDraftApplier = speechDraftApplier
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configureTextView(promptView, identifier: "speechPrompt")
        buildUI()
        refreshUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTextViewDelegate(_ delegate: NSTextViewDelegate?) {
        promptView.delegate = delegate
    }

    func handleTextDidChange(_ textView: NSTextView) {
        guard textView.identifier?.rawValue == "speechPrompt" else {
            return
        }

        speechPrompt = textView.string
        refreshUI()
    }

    func updateCurrentAvatar(_ avatar: AvatarSummary?) {
        currentAvatar = avatar
        currentAvatarImageView?.image = avatar.flatMap { NSImage(contentsOf: $0.previewURL) }
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)

        let header = NSStackView(views: [sectionLabel, statusLabel])
        header.orientation = .vertical
        header.spacing = 6

        let previewRow = NSStackView(views: [
            makeInfoCard(
                title: copy("speech_studio.text_preview_title", fallback: "文本预览"),
                valueLabel: draftSummaryValueLabel
            ),
            makeBubblePreviewCard(),
        ])
        previewRow.orientation = .horizontal
        previewRow.spacing = 16
        previewRow.distribution = .fillEqually

        root.addArrangedSubview(header)
        root.addArrangedSubview(
            makeInfoCard(
                title: copy("speech_studio.applied_summary_title", fallback: "当前已应用话术"),
                valueLabel: appliedSummaryValueLabel
            )
        )
        root.addArrangedSubview(
            makePromptSection(
                title: copy("common.prompt_label", fallback: "prompt"),
                hint: copy("speech_studio.prompt_hint", fallback: "描述你想要的角色话术、情绪和回应方式。"),
                textView: promptView,
                minHeight: 104
            )
        )
        root.addArrangedSubview(previewRow)
        root.addArrangedSubview(makeActionBar())

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    private func configureTextView(_ textView: NSTextView, identifier: String) {
        AvatarPanelTheme.styleTextView(textView)
        textView.identifier = NSUserInterfaceItemIdentifier(identifier)
        textView.string = ""
        textView.isRichText = false
    }

    private func makeInfoCard(title: String, valueLabel: NSTextField) -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        valueLabel.lineBreakMode = .byWordWrapping
        valueLabel.maximumNumberOfLines = 0

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(title, color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(valueLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
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

    private func makeBubblePreviewCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = currentAvatar.flatMap { NSImage(contentsOf: $0.previewURL) }
        imageView.heightAnchor.constraint(equalToConstant: 132).isActive = true
        currentAvatarImageView = imageView

        stack.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("speech_studio.bubble_preview_title", fallback: "桌宠对话气泡预览"),
                color: AvatarPanelTheme.accent
            )
        )
        stack.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("speech_studio.bubble_preview_note", fallback: "这里展示真实的桌宠气泡弹出预览。"),
                color: AvatarPanelTheme.muted,
                font: AvatarPanelTheme.smallFont
            )
        )
        stack.addArrangedSubview(bubblePreviewValueLabel)
        stack.addArrangedSubview(imageView)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeActionBar() -> NSView {
        let generateButton = NSButton(
            title: TextCatalog.shared.text(.commonPreviewButton),
            target: self,
            action: #selector(handleGeneratePreview)
        )
        let regenerateButton = NSButton(
            title: TextCatalog.shared.text(.commonRegenerateButton),
            target: self,
            action: #selector(handleRegeneratePreview)
        )
        let applyButton = NSButton(
            title: TextCatalog.shared.text(.commonApplyButton),
            target: self,
            action: #selector(handleApply)
        )
        AvatarPanelTheme.styleSecondaryButton(generateButton)
        AvatarPanelTheme.styleSecondaryButton(regenerateButton)
        AvatarPanelTheme.stylePrimaryButton(applyButton)

        generateButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        regenerateButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        applyButton.widthAnchor.constraint(equalToConstant: 88).isActive = true

        self.generateButton = generateButton
        self.regenerateButton = regenerateButton
        self.applyButton = applyButton

        let stack = NSStackView(views: [NSView(), generateButton, regenerateButton, applyButton])
        stack.orientation = .horizontal
        stack.spacing = 12
        return stack
    }

    private func refreshUI() {
        promptView.string = speechPrompt
        appliedSummaryValueLabel.stringValue = appliedSpeechSummary
        draftSummaryValueLabel.stringValue = draftSpeechSummary
        bubblePreviewValueLabel.stringValue = speechBubblePreviewText
        updateActionButtonStates()
    }

    private func updateActionButtonStates() {
        generateButton?.isEnabled = true
        regenerateButton?.isEnabled = previewRevision > 0 || speechDraftGenerator != nil
        applyButton?.isEnabled = pendingSpeechDraft != nil
    }

    private func renderSpeechPreview(regenerated: Bool) throws {
        let prompt = normalizedPrompt(
            speechPrompt,
            fallback: copy("speech_studio.fallback_prompt", fallback: "冷静、克制、简短，像像素桌宠一样回应")
        )

        if let speechDraftGenerator {
            let draft = try speechDraftGenerator(prompt)
            pendingSpeechDraft = draft
            previewRevision += 1
            draftSpeechSummary = draft.previewSummaryText()
            speechBubblePreviewText = draft.bubblePreviewText()
        } else {
            pendingSpeechDraft = nil
            previewRevision += 1
            draftSpeechSummary = formatCopy("speech_studio.draft_format", fallback: "草稿 %d：%@", previewRevision, prompt)
            speechBubblePreviewText = regenerated
                ? copy("speech_studio.bubble_regenerated", fallback: "换一版语气，继续保持简洁和像素感。")
                : copy("speech_studio.bubble_default", fallback: "今天也一起稳稳推进。")
        }

        statusLabel.stringValue = regenerated
            ? copy("speech_studio.preview_regenerated_status", fallback: "话术草稿已重新生成。")
            : copy("speech_studio.preview_generated_status", fallback: "话术草稿已生成。")
        statusLabel.textColor = AvatarPanelTheme.accent
        refreshUI()
    }

    private func applyPendingSpeechDraft() throws {
        guard let pendingSpeechDraft else {
            statusLabel.stringValue = copy("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。")
            statusLabel.textColor = AvatarPanelTheme.muted
            refreshUI()
            return
        }

        if let speechDraftApplier {
            try speechDraftApplier(pendingSpeechDraft)
        }
        appliedSpeechSummary = draftSpeechSummary
        self.pendingSpeechDraft = nil
        statusLabel.stringValue = copy("speech_studio.apply_status", fallback: "话术草稿已应用。")
        statusLabel.textColor = AvatarPanelTheme.text
        refreshUI()
    }

    private func showGenerationError(_ error: Error) {
        if error is AvatarBuilderBridgeError {
            statusLabel.stringValue = UserFacingErrorCopy.avatarMessage(for: error)
        } else {
            statusLabel.stringValue = error.localizedDescription
        }
        statusLabel.textColor = AvatarPanelTheme.danger
        refreshUI()
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

    @objc private func handleGeneratePreview() {
        do {
            try renderSpeechPreview(regenerated: false)
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handleRegeneratePreview() {
        do {
            try renderSpeechPreview(regenerated: true)
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handleApply() {
        do {
            try applyPendingSpeechDraft()
        } catch {
            showGenerationError(error)
        }
    }
}
