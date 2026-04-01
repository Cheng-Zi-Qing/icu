import AppKit

final class ThemeStudioContentView: NSView {
    private var currentAvatar: AvatarSummary?
    private let themePromptOptimizer: ((String) throws -> String)?
    private let themeDraftGenerator: ((String) throws -> ThemePack)?
    private let themeDraftApplier: ((ThemePack) throws -> Void)?

    private let sectionLabel = AvatarPanelTheme.makeTitleLabel("当前分区：主题风格")
    private let statusLabel = AvatarPanelTheme.makeLabel(
        TextCatalog.shared.text("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。"),
        color: AvatarPanelTheme.muted
    )
    private let rawPromptView = NSTextView()
    private let optimizedPromptView = NSTextView()
    private let appliedSummaryValueLabel = AvatarPanelTheme.makeLabel("")
    private let draftSummaryValueLabel = AvatarPanelTheme.makeLabel("")
    private let bubblePreviewValueLabel = AvatarPanelTheme.makeLabel("")
    private weak var currentAvatarImageView: NSImageView?
    private weak var optimizeButton: NSButton?
    private weak var previewButton: NSButton?
    private weak var applyButton: NSButton?

    private var themeRawPrompt = ""
    private var themeOptimizedPrompt = ""
    private var pendingThemePack: ThemePack?
    private var lastPreviewedThemePrompt: String?
    private var previewRevision = 0

    private var appliedThemeSummary = TextCatalog.shared.text(
        "theme_studio.applied_summary_default",
        fallback: "默认 PixelTheme 已应用到菜单、配置面板和桌宠状态条。"
    )
    private var draftThemeSummary = TextCatalog.shared.text(
        "theme_studio.draft_placeholder",
        fallback: "尚未生成新的主题草稿。"
    )
    private var themeBubblePreviewText = TextCatalog.shared.text(
        "theme_studio.bubble_default",
        fallback: "待命中，点击我可展开菜单。"
    )

    init(
        currentAvatar: AvatarSummary?,
        themePromptOptimizer: ((String) throws -> String)? = nil,
        themeDraftGenerator: ((String) throws -> ThemePack)? = nil,
        themeDraftApplier: ((ThemePack) throws -> Void)? = nil
    ) {
        self.currentAvatar = currentAvatar
        self.themePromptOptimizer = themePromptOptimizer
        self.themeDraftGenerator = themeDraftGenerator
        self.themeDraftApplier = themeDraftApplier
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configureTextView(rawPromptView, identifier: "themeRawPrompt")
        configureTextView(optimizedPromptView, identifier: "themeOptimizedPrompt")
        buildUI()
        refreshUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTextViewDelegate(_ delegate: NSTextViewDelegate?) {
        rawPromptView.delegate = delegate
        optimizedPromptView.delegate = delegate
    }

    func handleTextDidChange(_ textView: NSTextView) {
        switch textView.identifier?.rawValue {
        case "themeRawPrompt":
            themeRawPrompt = textView.string
        case "themeOptimizedPrompt":
            themeOptimizedPrompt = textView.string
            invalidateThemePreviewPresentation()
        default:
            return
        }

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
            makeBubblePreviewCard(),
            makeChromePreviewCard(),
        ])
        previewRow.orientation = .horizontal
        previewRow.spacing = 16
        previewRow.distribution = .fillEqually

        root.addArrangedSubview(header)
        root.addArrangedSubview(
            makeInfoCard(
                title: copy("theme_studio.applied_summary_title", fallback: "当前已应用主题"),
                valueLabel: appliedSummaryValueLabel
            )
        )
        root.addArrangedSubview(
            makePromptSection(
                title: copy("theme_studio.raw_prompt_title", fallback: "原始 prompt"),
                hint: copy("theme_studio.prompt_hint", fallback: "用 prompt 描述你想要的 GUI 气质，包括右键菜单、配置页和状态气泡。"),
                textView: rawPromptView,
                minHeight: 96
            )
        )
        root.addArrangedSubview(
            makePromptSection(
                title: copy("theme_studio.optimized_prompt_title", fallback: "优化后 prompt"),
                hint: copy("theme_studio.optimized_prompt_hint", fallback: "优化后的 prompt 会用于主题预览和应用，你可以继续手动编辑。"),
                textView: optimizedPromptView,
                minHeight: 96
            )
        )
        root.addArrangedSubview(
            makeInfoCard(
                title: copy("theme_studio.draft_title", fallback: "样式草稿"),
                valueLabel: draftSummaryValueLabel
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

        let noteLabel = AvatarPanelTheme.makeLabel(
            copy("theme_studio.bubble_preview_note", fallback: "主题生成必须覆盖桌宠 transient/status bubble。"),
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = currentAvatar.flatMap { NSImage(contentsOf: $0.previewURL) }
        imageView.heightAnchor.constraint(equalToConstant: 132).isActive = true
        currentAvatarImageView = imageView

        stack.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("theme_studio.bubble_preview_title", fallback: "桌宠气泡预览"),
                color: AvatarPanelTheme.accent
            )
        )
        stack.addArrangedSubview(noteLabel)
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

    private func makeChromePreviewCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let menuCard = AvatarPanelTheme.makeCard()
        let menuStack = NSStackView()
        menuStack.orientation = .vertical
        menuStack.spacing = 6
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuCard.addSubview(menuStack)
        menuStack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("theme_studio.chrome_preview_change_avatar", fallback: "更换形象")))
        menuStack.addArrangedSubview(AvatarPanelTheme.makeLabel("创作工坊"))
        menuStack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("theme_studio.chrome_preview_model_config", fallback: "模型配置")))

        let sampleField = NSTextField(string: copy("theme_studio.chrome_preview_sample_prompt", fallback: "prompt: cozy terminal pixel vibe"))
        sampleField.isEditable = false
        AvatarPanelTheme.styleEditableTextField(sampleField)

        stack.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("theme_studio.chrome_preview_title", fallback: "右键菜单与表单预览"),
                color: AvatarPanelTheme.accent
            )
        )
        stack.addArrangedSubview(
            AvatarPanelTheme.makeLabel(
                copy("theme_studio.chrome_preview_hint", fallback: "主题会统一覆盖右键弹出栏、配置输入框和主要按钮。"),
                color: AvatarPanelTheme.muted,
                font: AvatarPanelTheme.smallFont
            )
        )
        stack.addArrangedSubview(menuCard)
        stack.addArrangedSubview(sampleField)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            menuStack.topAnchor.constraint(equalTo: menuCard.topAnchor, constant: 12),
            menuStack.leadingAnchor.constraint(equalTo: menuCard.leadingAnchor, constant: 12),
            menuStack.trailingAnchor.constraint(equalTo: menuCard.trailingAnchor, constant: -12),
            menuStack.bottomAnchor.constraint(equalTo: menuCard.bottomAnchor, constant: -12),
        ])
        return card
    }

    private func makeActionBar() -> NSView {
        let optimizeButton = NSButton(
            title: copy("theme_studio.optimize_button", fallback: "优化 prompt"),
            target: self,
            action: #selector(handleOptimizeThemePrompt)
        )
        let previewButton = NSButton(
            title: copy("theme_studio.preview_button", fallback: "预览效果"),
            target: self,
            action: #selector(handlePreviewTheme)
        )
        let applyButton = NSButton(
            title: copy("theme_studio.apply_button", fallback: "应用主题"),
            target: self,
            action: #selector(handleApplyTheme)
        )
        AvatarPanelTheme.styleSecondaryButton(optimizeButton)
        AvatarPanelTheme.styleSecondaryButton(previewButton)
        AvatarPanelTheme.stylePrimaryButton(applyButton)

        optimizeButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        previewButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        applyButton.widthAnchor.constraint(equalToConstant: 88).isActive = true

        self.optimizeButton = optimizeButton
        self.previewButton = previewButton
        self.applyButton = applyButton

        let stack = NSStackView(views: [NSView(), optimizeButton, previewButton, applyButton])
        stack.orientation = .horizontal
        stack.spacing = 12
        return stack
    }

    private func refreshUI() {
        rawPromptView.string = themeRawPrompt
        optimizedPromptView.string = themeOptimizedPrompt
        appliedSummaryValueLabel.stringValue = appliedThemeSummary
        draftSummaryValueLabel.stringValue = draftThemeSummary
        bubblePreviewValueLabel.stringValue = themeBubblePreviewText
        updateActionButtonStates()
    }

    private func updateActionButtonStates() {
        optimizeButton?.isEnabled = true
        previewButton?.isEnabled = hasNonEmptyOptimizedThemePrompt()
        applyButton?.isEnabled = hasValidThemePreviewDraft()
    }

    private func hasNonEmptyOptimizedThemePrompt() -> Bool {
        !normalizedPrompt(themeOptimizedPrompt, fallback: "").isEmpty
    }

    private func hasValidThemePreviewDraft() -> Bool {
        let currentPrompt = normalizedPrompt(themeOptimizedPrompt, fallback: "")
        guard
            let pendingThemePack,
            let lastPreviewedThemePrompt,
            !currentPrompt.isEmpty
        else {
            return false
        }

        _ = pendingThemePack
        return currentPrompt == lastPreviewedThemePrompt
    }

    private func invalidateThemePreview() {
        pendingThemePack = nil
        lastPreviewedThemePrompt = nil
    }

    private func invalidateThemePreviewPresentation() {
        invalidateThemePreview()
        draftThemeSummary = copy("theme_studio.draft_placeholder", fallback: "尚未生成新的主题草稿。")
        themeBubblePreviewText = copy("theme_studio.preview_invalidated_bubble", fallback: "优化后 prompt 已变更，请重新预览效果。")
    }

    private func renderOptimizedThemePrompt() throws {
        let prompt = normalizedPrompt(
            themeRawPrompt,
            fallback: copy("theme_studio.fallback_prompt", fallback: "深绿像素主题，右键菜单更紧凑，气泡更清晰")
        )
        let optimized = if let themePromptOptimizer {
            try themePromptOptimizer(prompt)
        } else {
            prompt
        }

        themeOptimizedPrompt = optimized
        invalidateThemePreviewPresentation()
        statusLabel.stringValue = copy("theme_studio.optimized_status", fallback: "prompt 优化完成。")
        statusLabel.textColor = AvatarPanelTheme.accent
        refreshUI()
    }

    private func renderThemePreview() throws {
        let prompt = normalizedPrompt(themeOptimizedPrompt, fallback: "")
        guard !prompt.isEmpty else {
            statusLabel.stringValue = copy("theme_studio.preview_requires_optimized_status", fallback: "请先优化 prompt，再预览效果。")
            statusLabel.textColor = AvatarPanelTheme.muted
            refreshUI()
            return
        }

        if let themeDraftGenerator {
            let pack = try themeDraftGenerator(prompt)
            pendingThemePack = pack
            lastPreviewedThemePrompt = prompt
            previewRevision += 1
            draftThemeSummary = formatCopy(
                "theme_studio.draft_format",
                fallback: "草稿 %d：%@",
                previewRevision,
                "\(themePackDisplayName(pack)) / \(prompt)"
            )
        } else {
            pendingThemePack = nil
            lastPreviewedThemePrompt = prompt
            previewRevision += 1
            draftThemeSummary = formatCopy(
                "theme_studio.draft_format",
                fallback: "草稿 %d：%@",
                previewRevision,
                prompt
            )
        }

        themeBubblePreviewText = copy("theme_studio.bubble_default", fallback: "待命中，点击我可展开菜单。")
        statusLabel.stringValue = copy("theme_studio.preview_generated_status", fallback: "主题草稿已生成。")
        statusLabel.textColor = AvatarPanelTheme.accent
        refreshUI()
    }

    private func themePackDisplayName(_ pack: ThemePack) -> String {
        let name = pack.meta.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? pack.meta.id : name
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

    @objc private func handleOptimizeThemePrompt() {
        do {
            try renderOptimizedThemePrompt()
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handlePreviewTheme() {
        do {
            try renderThemePreview()
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handleApplyTheme() {
        let currentPrompt = normalizedPrompt(themeOptimizedPrompt, fallback: "")
        guard
            let pendingThemePack,
            let lastPreviewedThemePrompt,
            !currentPrompt.isEmpty,
            currentPrompt == lastPreviewedThemePrompt
        else {
            statusLabel.stringValue = copy("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。")
            statusLabel.textColor = AvatarPanelTheme.muted
            refreshUI()
            return
        }

        do {
            if let themeDraftApplier {
                try themeDraftApplier(pendingThemePack)
            }
            appliedThemeSummary = draftThemeSummary
            invalidateThemePreview()
            statusLabel.stringValue = copy("theme_studio.apply_status", fallback: "主题草稿已应用。")
            statusLabel.textColor = AvatarPanelTheme.text
            refreshUI()
        } catch {
            showGenerationError(error)
        }
    }
}
