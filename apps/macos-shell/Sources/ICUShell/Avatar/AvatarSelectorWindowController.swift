import AppKit

final class AvatarSelectorWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
    private enum StudioTab: CaseIterable {
        case theme
        case avatar
        case speech

        var title: String {
            switch self {
            case .theme:
                return TextCatalog.shared.text("theme_studio.tab_title", fallback: "主题风格")
            case .avatar:
                return TextCatalog.shared.text("avatar_studio.tab_title", fallback: "桌宠形象动画")
            case .speech:
                return TextCatalog.shared.text("speech_studio.tab_title", fallback: "话术")
            }
        }
    }

    private let avatars: [AvatarSummary]
    private let themePromptOptimizer: ((String) throws -> String)?
    private let themeDraftGenerator: ((String) throws -> ThemePack)?
    private let themeDraftApplier: ((ThemePack) throws -> Void)?
    private let speechDraftGenerator: ((String) throws -> SpeechDraft)?
    private let speechDraftApplier: ((SpeechDraft) throws -> Void)?
    private let onChoose: (String) -> Void
    private let onAddCustom: () -> Void
    private let onClose: () -> Void

    private var selectedTab: StudioTab = .theme
    private var selectedAvatarID: String?
    private var pendingThemePack: ThemePack?
    private var pendingSpeechDraft: SpeechDraft?
    private var lastPreviewedThemePrompt: String?

    private var tableView = NSTableView()
    private var previewImageView = NSImageView()
    private var nameLabel = AvatarPanelTheme.makeTitleLabel("")
    private var styleLabel = AvatarPanelTheme.makeLabel("", color: AvatarPanelTheme.muted)
    private var traitsLabel = AvatarPanelTheme.makeLabel("")
    private var contentCard = AvatarPanelTheme.makeCard()
    private var statusLabel = AvatarPanelTheme.makeLabel(
        TextCatalog.shared.text("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。"),
        color: AvatarPanelTheme.muted
    )
    private var tabButtons: [StudioTab: NSButton] = [:]
    private var themeObserver: NSObjectProtocol?
    private var didFinish = false

    private let themeRawPromptView = NSTextView()
    private let themeOptimizedPromptView = NSTextView()
    private let avatarPromptView = NSTextView()
    private let speechPromptView = NSTextView()

    private var themeRawPrompt = ""
    private var themeOptimizedPrompt = ""
    private var avatarPrompt = ""
    private var speechPrompt = ""

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

    private var avatarDraftSummary = TextCatalog.shared.text(
        "avatar_studio.draft_placeholder",
        fallback: "尚未生成新的形象草稿。"
    )

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

    private var previewRevision = 0

    init(
        avatars: [AvatarSummary],
        currentAvatarID: String?,
        themePromptOptimizer: ((String) throws -> String)? = nil,
        themeDraftGenerator: ((String) throws -> ThemePack)? = nil,
        themeDraftApplier: ((ThemePack) throws -> Void)? = nil,
        speechDraftGenerator: ((String) throws -> SpeechDraft)? = nil,
        speechDraftApplier: ((SpeechDraft) throws -> Void)? = nil,
        onChoose: @escaping (String) -> Void,
        onAddCustom: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.avatars = avatars
        self.selectedAvatarID = currentAvatarID ?? avatars.first?.id
        self.themePromptOptimizer = themePromptOptimizer
        self.themeDraftGenerator = themeDraftGenerator
        self.themeDraftApplier = themeDraftApplier
        self.speechDraftGenerator = speechDraftGenerator
        self.speechDraftApplier = speechDraftApplier
        self.onChoose = onChoose
        self.onAddCustom = onAddCustom
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        AvatarPanelTheme.styleWindow(window)
        super.init(window: window)
        window.delegate = self

        configureTextViews()
        buildUI()
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

    func numberOfRows(in tableView: NSTableView) -> Int {
        avatars.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AvatarCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView) ?? NSTableCellView()
        cell.identifier = identifier

        let label: NSTextField
        if let existing = cell.textField {
            label = existing
        } else {
            label = AvatarPanelTheme.makeLabel("")
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        let avatar = avatars[row]
        label.stringValue = "\(avatar.name) (\(avatar.style.isEmpty ? copy("avatar_studio.unnamed_style", fallback: "未命名风格") : avatar.style))"
        label.textColor = AvatarPanelTheme.text
        label.font = AvatarPanelTheme.bodyFont
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if avatars.indices.contains(tableView.selectedRow) {
            selectedAvatarID = avatars[tableView.selectedRow].id
        }
        updateAvatarDetailPanel()
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else {
            return
        }

        switch textView.identifier?.rawValue {
        case "themeRawPrompt":
            themeRawPrompt = textView.string
        case "themeOptimizedPrompt":
            themeOptimizedPrompt = textView.string
            invalidateThemePreview()
        case "avatarPrompt":
            avatarPrompt = textView.string
        case "speechPrompt":
            speechPrompt = textView.string
        default:
            break
        }
    }

    func windowWillClose(_ notification: Notification) {
        if !didFinish {
            onClose()
        }
    }

    private func copy(_ key: String, fallback: String) -> String {
        TextCatalog.shared.text(key, fallback: fallback)
    }

    private func formatCopy(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(format: copy(key, fallback: fallback), arguments: arguments)
    }

    private func configureTextViews() {
        configureTextView(themeRawPromptView, identifier: "themeRawPrompt", text: themeRawPrompt)
        configureTextView(themeOptimizedPromptView, identifier: "themeOptimizedPrompt", text: themeOptimizedPrompt)
        configureTextView(avatarPromptView, identifier: "avatarPrompt", text: avatarPrompt)
        configureTextView(speechPromptView, identifier: "speechPrompt", text: speechPrompt)
    }

    private func configureTextView(_ textView: NSTextView, identifier: String, text: String) {
        AvatarPanelTheme.styleTextView(textView)
        textView.identifier = NSUserInterfaceItemIdentifier(identifier)
        textView.delegate = self
        textView.string = text
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
        tabButtons.removeAll()
        statusLabel = AvatarPanelTheme.makeLabel(
            copy("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。"),
            color: AvatarPanelTheme.muted
        )
        contentCard = AvatarPanelTheme.makeCard()
        contentCard.translatesAutoresizingMaskIntoConstraints = false

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let title = AvatarPanelTheme.makeTitleLabel(copy("avatar_studio.window_title", fallback: "选择你的桌宠形象"))
        let subtitle = AvatarPanelTheme.makeLabel(
            copy("avatar_studio.window_subtitle", fallback: "统一管理主题风格、桌宠形象动画和话术，所有内容都先预览再应用。"),
            color: AvatarPanelTheme.muted
        )
        let header = NSStackView(views: [title, subtitle, statusLabel])
        header.orientation = .vertical
        header.spacing = 6

        let tabsBar = makeTabsBar()
        let footer = makeFooter()

        root.addArrangedSubview(header)
        root.addArrangedSubview(tabsBar)
        root.addArrangedSubview(contentCard)
        root.addArrangedSubview(footer)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            tabsBar.heightAnchor.constraint(equalToConstant: 38),
            contentCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 460),
        ])

        renderSelectedTab()
        updateTabStyles()
    }

    private func makeTabsBar() -> NSStackView {
        let tabsBar = NSStackView()
        tabsBar.orientation = .horizontal
        tabsBar.spacing = 12
        tabsBar.alignment = .centerY
        tabsBar.translatesAutoresizingMaskIntoConstraints = false

        for tab in StudioTab.allCases {
            let button = NSButton(title: tab.title, target: self, action: #selector(handleTabSelection(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(tab.title)
            tabButtons[tab] = button
            tabsBar.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: tab == .avatar ? 168 : 120).isActive = true
        }

        tabsBar.addArrangedSubview(NSView())
        return tabsBar
    }

    private func makeFooter() -> NSStackView {
        let cancelButton = NSButton(title: TextCatalog.shared.text(.commonCloseButton), target: self, action: #selector(handleCancel))
        AvatarPanelTheme.styleSecondaryButton(cancelButton)
        cancelButton.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let footer = NSStackView(views: [NSView(), cancelButton])
        footer.orientation = .horizontal
        footer.spacing = 12
        return footer
    }

    private func renderSelectedTab() {
        contentCard.subviews.forEach { $0.removeFromSuperview() }

        let activeView: NSView
        switch selectedTab {
        case .theme:
            activeView = buildThemeTabView()
        case .avatar:
            activeView = buildAvatarTabView()
        case .speech:
            activeView = buildSpeechTabView()
        }

        activeView.translatesAutoresizingMaskIntoConstraints = false
        contentCard.addSubview(activeView)
        NSLayoutConstraint.activate([
            activeView.topAnchor.constraint(equalTo: contentCard.topAnchor, constant: 16),
            activeView.leadingAnchor.constraint(equalTo: contentCard.leadingAnchor, constant: 16),
            activeView.trailingAnchor.constraint(equalTo: contentCard.trailingAnchor, constant: -16),
            activeView.bottomAnchor.constraint(equalTo: contentCard.bottomAnchor, constant: -16),
        ])

        updateTabStyles()
    }

    private func buildThemeTabView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 14

        let rawPromptSection = makePromptSection(
            title: copy("theme_studio.raw_prompt_title", fallback: "prompt"),
            hint: copy("theme_studio.prompt_hint", fallback: "用 prompt 描述你想要的 GUI 气质，包括右键菜单、配置页和状态气泡。"),
            textView: themeRawPromptView,
            storedText: themeRawPrompt,
            minHeight: 96
        )

        let optimizedPromptSection = makePromptSection(
            title: copy("theme_studio.optimized_prompt_title", fallback: "优化后 prompt"),
            hint: copy("theme_studio.optimized_prompt_hint", fallback: "优化后的 prompt 会用于主题预览和应用，你可以继续手动编辑。"),
            textView: themeOptimizedPromptView,
            storedText: themeOptimizedPrompt,
            minHeight: 96
        )

        let previewRow = NSStackView(views: [
            makePetBubblePreviewCard(
                title: copy("theme_studio.bubble_preview_title", fallback: "桌宠气泡预览"),
                bubbleText: themeBubblePreviewText,
                note: copy("theme_studio.bubble_preview_note", fallback: "主题生成必须覆盖桌宠 transient/status bubble。")
            ),
            makeThemeChromePreviewCard(),
        ])
        previewRow.orientation = .horizontal
        previewRow.spacing = 16
        previewRow.distribution = .fillEqually

        view.addArrangedSubview(
            makeInfoCard(
                title: copy("theme_studio.applied_summary_title", fallback: "当前已应用主题"),
                lines: [appliedThemeSummary]
            )
        )
        view.addArrangedSubview(rawPromptSection)
        view.addArrangedSubview(optimizedPromptSection)
        view.addArrangedSubview(
            makeInfoCard(
                title: copy("theme_studio.draft_title", fallback: "样式草稿"),
                lines: [draftThemeSummary]
            )
        )
        view.addArrangedSubview(previewRow)
        view.addArrangedSubview(makeThemeActionBar())
        return view
    }

    private func buildAvatarTabView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 14

        let summaryRow = NSStackView(views: [
            makeInfoCard(
                title: copy("avatar_studio.applied_summary_title", fallback: "当前已应用形象"),
                lines: [currentAvatarSummaryText()]
            ),
            makeInfoCard(
                title: copy("avatar_studio.draft_title", fallback: "当前草稿"),
                lines: [avatarDraftSummary]
            ),
        ])
        summaryRow.orientation = .horizontal
        summaryRow.spacing = 16
        summaryRow.distribution = .fillEqually

        let promptSection = makePromptSection(
            title: copy("common.prompt_label", fallback: "prompt"),
            hint: copy("avatar_studio.prompt_hint", fallback: "描述你想生成的形象、动作和动画关键词。"),
            textView: avatarPromptView,
            storedText: avatarPrompt,
            minHeight: 96
        )

        let listCard = AvatarPanelTheme.makeCard()
        let detailCard = AvatarPanelTheme.makeCard()
        listCard.translatesAutoresizingMaskIntoConstraints = false
        detailCard.translatesAutoresizingMaskIntoConstraints = false
        buildAvatarListCard(in: listCard)
        buildAvatarDetailCard(in: detailCard)

        let previews = NSStackView(views: [listCard, detailCard])
        previews.orientation = .horizontal
        previews.spacing = 16
        previews.distribution = .fillEqually
        previews.heightAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true

        view.addArrangedSubview(summaryRow)
        view.addArrangedSubview(promptSection)
        view.addArrangedSubview(previews)
        view.addArrangedSubview(makeActionBar(includeAddCustom: true))
        return view
    }

    private func buildSpeechTabView() -> NSView {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 14

        let promptSection = makePromptSection(
            title: copy("common.prompt_label", fallback: "prompt"),
            hint: copy("speech_studio.prompt_hint", fallback: "描述你想要的角色话术、情绪和回应方式。"),
            textView: speechPromptView,
            storedText: speechPrompt,
            minHeight: 104
        )

        let previewRow = NSStackView(views: [
            makeInfoCard(
                title: copy("speech_studio.text_preview_title", fallback: "文本预览"),
                lines: [draftSpeechSummary]
            ),
            makePetBubblePreviewCard(
                title: copy("speech_studio.bubble_preview_title", fallback: "桌宠对话气泡预览"),
                bubbleText: speechBubblePreviewText,
                note: copy("speech_studio.bubble_preview_note", fallback: "这里展示真实的桌宠气泡弹出预览。")
            ),
        ])
        previewRow.orientation = .horizontal
        previewRow.spacing = 16
        previewRow.distribution = .fillEqually

        view.addArrangedSubview(
            makeInfoCard(
                title: copy("speech_studio.applied_summary_title", fallback: "当前已应用话术"),
                lines: [appliedSpeechSummary]
            )
        )
        view.addArrangedSubview(promptSection)
        view.addArrangedSubview(previewRow)
        view.addArrangedSubview(makeActionBar(includeAddCustom: false))
        return view
    }

    private func makePromptSection(
        title: String,
        hint: String,
        textView: NSTextView,
        storedText: String,
        minHeight: CGFloat
    ) -> NSView {
        textView.string = storedText

        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let titleLabel = AvatarPanelTheme.makeLabel(title, color: AvatarPanelTheme.accent)
        let hintLabel = AvatarPanelTheme.makeLabel(hint, color: AvatarPanelTheme.muted, font: AvatarPanelTheme.smallFont)
        let scrollView = makeTextScrollView(textView: textView, minHeight: minHeight)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(hintLabel)
        stack.addArrangedSubview(scrollView)

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
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        return scrollView
    }

    private func makeInfoCard(title: String, lines: [String]) -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(title, color: AvatarPanelTheme.accent))
        for line in lines {
            stack.addArrangedSubview(AvatarPanelTheme.makeLabel(line, color: AvatarPanelTheme.text))
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makePetBubblePreviewCard(title: String, bubbleText: String, note: String) -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let bubbleLabel = NSTextField(labelWithString: bubbleText)
        bubbleLabel.translatesAutoresizingMaskIntoConstraints = false
        ThemedComponents.styleStatusChip(bubbleLabel, theme: ThemeManager.shared.currentTheme)

        let chipFrame = NSView()
        chipFrame.translatesAutoresizingMaskIntoConstraints = false
        chipFrame.addSubview(bubbleLabel)

        let petImageView = NSImageView()
        petImageView.translatesAutoresizingMaskIntoConstraints = false
        petImageView.imageScaling = .scaleProportionallyUpOrDown
        petImageView.image = currentAvatarSummary().flatMap { NSImage(contentsOf: $0.previewURL) }

        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(title, color: AvatarPanelTheme.accent))
        stack.addArrangedSubview(AvatarPanelTheme.makeLabel(note, color: AvatarPanelTheme.muted, font: AvatarPanelTheme.smallFont))
        stack.addArrangedSubview(chipFrame)
        stack.addArrangedSubview(petImageView)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            bubbleLabel.topAnchor.constraint(equalTo: chipFrame.topAnchor, constant: 8),
            bubbleLabel.leadingAnchor.constraint(equalTo: chipFrame.leadingAnchor, constant: 12),
            bubbleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chipFrame.trailingAnchor, constant: -12),
            bubbleLabel.bottomAnchor.constraint(equalTo: chipFrame.bottomAnchor, constant: -8),
            petImageView.heightAnchor.constraint(equalToConstant: 132),
        ])
        return card
    }

    private func makeThemeChromePreviewCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let title = AvatarPanelTheme.makeLabel(
            copy("theme_studio.chrome_preview_title", fallback: "右键菜单与表单预览"),
            color: AvatarPanelTheme.accent
        )
        let hint = AvatarPanelTheme.makeLabel(
            copy("theme_studio.chrome_preview_hint", fallback: "主题会统一覆盖右键弹出栏、配置输入框和主要按钮。"),
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )

        let menuFrame = AvatarPanelTheme.makeCard()
        let menuStack = NSStackView()
        menuStack.orientation = .vertical
        menuStack.spacing = 6
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        menuFrame.addSubview(menuStack)
        menuStack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("theme_studio.chrome_preview_change_avatar", fallback: "更换形象"), color: AvatarPanelTheme.text))
        menuStack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("theme_studio.chrome_preview_model_config", fallback: "模型配置"), color: AvatarPanelTheme.text))
        menuStack.addArrangedSubview(AvatarPanelTheme.makeLabel(copy("theme_studio.chrome_preview_generate_image", fallback: "生成图像"), color: AvatarPanelTheme.text))

        let sampleField = NSTextField(string: copy("theme_studio.chrome_preview_sample_prompt", fallback: "prompt: cozy terminal pixel vibe"))
        sampleField.isEditable = false
        AvatarPanelTheme.styleEditableTextField(sampleField)

        let primaryButton = NSButton(title: copy("theme_studio.preview_button", fallback: "预览效果"), target: nil, action: nil)
        let secondaryButton = NSButton(title: copy("theme_studio.apply_button", fallback: "应用主题"), target: nil, action: nil)
        AvatarPanelTheme.stylePrimaryButton(primaryButton)
        AvatarPanelTheme.styleSecondaryButton(secondaryButton)

        let buttonRow = NSStackView(views: [primaryButton, secondaryButton, NSView()])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(hint)
        stack.addArrangedSubview(menuFrame)
        stack.addArrangedSubview(sampleField)
        stack.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            menuStack.topAnchor.constraint(equalTo: menuFrame.topAnchor, constant: 12),
            menuStack.leadingAnchor.constraint(equalTo: menuFrame.leadingAnchor, constant: 12),
            menuStack.trailingAnchor.constraint(equalTo: menuFrame.trailingAnchor, constant: -12),
            menuStack.bottomAnchor.constraint(equalTo: menuFrame.bottomAnchor, constant: -12),
            primaryButton.widthAnchor.constraint(equalToConstant: 110),
            secondaryButton.widthAnchor.constraint(equalToConstant: 88),
        ])
        return card
    }

    private func makeThemeActionBar() -> NSView {
        let optimizeButton = NSButton(title: copy("theme_studio.optimize_button", fallback: "优化 prompt"), target: self, action: #selector(handleOptimizeThemePrompt))
        let reoptimizeButton = NSButton(title: copy("theme_studio.reoptimize_button", fallback: "重新优化"), target: self, action: #selector(handleReoptimizeThemePrompt))
        let previewButton = NSButton(title: copy("theme_studio.preview_button", fallback: "预览效果"), target: self, action: #selector(handlePreviewTheme))
        let applyButton = NSButton(title: copy("theme_studio.apply_button", fallback: "应用主题"), target: self, action: #selector(handleApplyTheme))
        AvatarPanelTheme.styleSecondaryButton(optimizeButton)
        AvatarPanelTheme.styleSecondaryButton(reoptimizeButton)
        AvatarPanelTheme.styleSecondaryButton(previewButton)
        AvatarPanelTheme.stylePrimaryButton(applyButton)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.addArrangedSubview(NSView())
        stack.addArrangedSubview(optimizeButton)
        stack.addArrangedSubview(reoptimizeButton)
        stack.addArrangedSubview(previewButton)
        stack.addArrangedSubview(applyButton)

        optimizeButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        reoptimizeButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        previewButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        applyButton.widthAnchor.constraint(equalToConstant: 88).isActive = true
        return stack
    }

    private func makeActionBar(includeAddCustom: Bool) -> NSView {
        let generateButton = NSButton(title: TextCatalog.shared.text(.commonPreviewButton), target: self, action: #selector(handleGeneratePreview))
        let regenerateButton = NSButton(title: TextCatalog.shared.text(.commonRegenerateButton), target: self, action: #selector(handleRegeneratePreview))
        let applyButton = NSButton(title: TextCatalog.shared.text(.commonApplyButton), target: self, action: #selector(handleApply))
        AvatarPanelTheme.styleSecondaryButton(generateButton)
        AvatarPanelTheme.styleSecondaryButton(regenerateButton)
        AvatarPanelTheme.stylePrimaryButton(applyButton)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.addArrangedSubview(NSView())

        if includeAddCustom {
            let addCustomButton = NSButton(title: copy("avatar_studio.add_custom_button", fallback: "新增自定义形象"), target: self, action: #selector(handleAddCustom))
            AvatarPanelTheme.styleSecondaryButton(addCustomButton)
            addCustomButton.widthAnchor.constraint(equalToConstant: 160).isActive = true
            stack.addArrangedSubview(addCustomButton)
        }

        stack.addArrangedSubview(generateButton)
        stack.addArrangedSubview(regenerateButton)
        stack.addArrangedSubview(applyButton)

        generateButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        regenerateButton.widthAnchor.constraint(equalToConstant: 110).isActive = true
        applyButton.widthAnchor.constraint(equalToConstant: 88).isActive = true
        return stack
    }

    private func buildAvatarListCard(in card: NSView) {
        let title = AvatarPanelTheme.makeLabel(copy("avatar_studio.list_title", fallback: "形象列表"), color: AvatarPanelTheme.accent)
        title.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(title)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        AvatarPanelTheme.styleScrollView(scrollView)
        card.addSubview(scrollView)

        tableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AvatarName"))
        column.width = 280
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = AvatarPanelTheme.input
        tableView.usesAlternatingRowBackgroundColors = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        restoreSelection()
    }

    private func buildAvatarDetailCard(in card: NSView) {
        previewImageView = NSImageView()
        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        nameLabel = AvatarPanelTheme.makeTitleLabel("")
        styleLabel = AvatarPanelTheme.makeLabel("", color: AvatarPanelTheme.muted)
        traitsLabel = AvatarPanelTheme.makeLabel("")

        let title = AvatarPanelTheme.makeLabel(copy("avatar_studio.detail_title", fallback: "预览与说明"), color: AvatarPanelTheme.accent)
        title.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(title)

        let imageFrame = NSView()
        imageFrame.translatesAutoresizingMaskIntoConstraints = false
        AvatarPanelTheme.styleImageFrame(imageFrame)
        card.addSubview(imageFrame)

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        imageFrame.addSubview(previewImageView)

        let infoStack = NSStackView(views: [nameLabel, styleLabel, traitsLabel])
        infoStack.orientation = .vertical
        infoStack.spacing = 8
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(infoStack)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            imageFrame.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            imageFrame.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            imageFrame.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            imageFrame.heightAnchor.constraint(equalToConstant: 190),
            previewImageView.centerXAnchor.constraint(equalTo: imageFrame.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: imageFrame.centerYAnchor),
            previewImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 180),
            previewImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 180),
            infoStack.topAnchor.constraint(equalTo: imageFrame.bottomAnchor, constant: 16),
            infoStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            infoStack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -16),
        ])

        updateAvatarDetailPanel()
    }

    private func updateAvatarDetailPanel() {
        guard let avatar = currentAvatarSummary() else {
            nameLabel.stringValue = copy("avatar_studio.no_selection_title", fallback: "未选择形象")
            styleLabel.stringValue = ""
            traitsLabel.stringValue = ""
            previewImageView.image = nil
            return
        }

        nameLabel.stringValue = avatar.name
        let styleValue = avatar.style.isEmpty ? copy("avatar_studio.missing_style", fallback: "未标注") : avatar.style
        styleLabel.stringValue = formatCopy("avatar_studio.style_format", fallback: "风格：%@", styleValue)
        let toneText = avatar.tone.isEmpty ? "" : formatCopy("avatar_studio.tone_format", fallback: "\n语气：%@", avatar.tone)
        traitsLabel.stringValue = avatar.traits.isEmpty
            ? copy("avatar_studio.no_persona", fallback: "这个形象还没有 persona 摘要。")
            : formatCopy("avatar_studio.traits_format", fallback: "特质：%@%@", avatar.traits, toneText)
        previewImageView.image = NSImage(contentsOf: avatar.previewURL)
    }

    private func restoreSelection() {
        if let selectedAvatarID, let row = avatars.firstIndex(where: { $0.id == selectedAvatarID }) {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else if !avatars.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            selectedAvatarID = avatars[0].id
        }
    }

    private func currentAvatarSummary() -> AvatarSummary? {
        if let selectedAvatarID {
            return avatars.first(where: { $0.id == selectedAvatarID })
        }
        return avatars.first
    }

    private func currentAvatarSummaryText() -> String {
        guard let avatar = currentAvatarSummary() else {
            return copy("avatar_studio.empty_summary", fallback: "暂无已应用形象。")
        }

        let styleValue = avatar.style.isEmpty ? copy("avatar_studio.missing_style_summary", fallback: "未标注风格") : avatar.style
        return "\(avatar.name) / \(styleValue)"
    }

    private func updateTabStyles() {
        for (tab, button) in tabButtons {
            let isSelected = tab == selectedTab
            AvatarPanelTheme.styleButton(
                button,
                backgroundColor: isSelected ? AvatarPanelTheme.accent : AvatarPanelTheme.accentDark,
                foregroundColor: isSelected ? AvatarPanelTheme.background : AvatarPanelTheme.text
            )
        }
    }

    private func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureTextViews()
            self?.buildUI()
        }
    }

    private func invalidateThemePreview() {
        pendingThemePack = nil
        lastPreviewedThemePrompt = nil
    }

    private func renderOptimizedThemePrompt(regenerated: Bool) throws {
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
        themeOptimizedPromptView.string = optimized
        invalidateThemePreview()
        statusLabel.stringValue = regenerated
            ? copy("theme_studio.reoptimized_status", fallback: "prompt 已重新优化。")
            : copy("theme_studio.optimized_status", fallback: "prompt 优化完成。")
        statusLabel.textColor = AvatarPanelTheme.accent
    }

    private func renderThemePreview(regenerated: Bool) throws {
        let prompt = normalizedPrompt(
            themeOptimizedPrompt,
            fallback: ""
        )
        guard !prompt.isEmpty else {
            statusLabel.stringValue = copy("theme_studio.preview_requires_optimized_status", fallback: "请先优化 prompt，再预览效果。")
            statusLabel.textColor = AvatarPanelTheme.muted
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
            draftThemeSummary = formatCopy("theme_studio.draft_format", fallback: "草稿 %d：%@", previewRevision, prompt)
        }

        themeBubblePreviewText = regenerated
            ? copy("theme_studio.bubble_regenerated", fallback: "新的像素气泡已生成，试试这版菜单边框。")
            : copy("theme_studio.bubble_default", fallback: "待命中，点击我可展开菜单。")
        statusLabel.stringValue = regenerated
            ? copy("theme_studio.preview_regenerated_status", fallback: "主题草稿已重新生成。")
            : copy("theme_studio.preview_generated_status", fallback: "主题草稿已生成。")
        statusLabel.textColor = AvatarPanelTheme.accent
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
    }

    private func renderAvatarPreview(regenerated: Bool) {
        let prompt = normalizedPrompt(
            avatarPrompt,
            fallback: copy("avatar_studio.fallback_prompt", fallback: "保留当前形象，但增加 idle / working / alert 三组动作")
        )
        previewRevision += 1
        avatarDraftSummary = formatCopy("avatar_studio.draft_format", fallback: "草稿 %d：%@ / %@", previewRevision, currentAvatarSummaryText(), prompt)
        statusLabel.stringValue = regenerated
            ? copy("avatar_studio.preview_regenerated_status", fallback: "形象动画草稿已重新生成。")
            : copy("avatar_studio.preview_generated_status", fallback: "形象动画草稿已生成。")
        statusLabel.textColor = AvatarPanelTheme.accent
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
    }

    private func normalizedPrompt(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    @objc private func handleTabSelection(_ sender: NSButton) {
        guard let tab = StudioTab.allCases.first(where: { $0.title == sender.title }) else {
            return
        }

        selectedTab = tab
        renderSelectedTab()
    }

    @objc private func handleGeneratePreview() {
        switch selectedTab {
        case .theme:
            return
        case .avatar:
            renderAvatarPreview(regenerated: false)
        case .speech:
            do {
                try renderSpeechPreview(regenerated: false)
            } catch {
                showGenerationError(error)
                return
            }
        }
        renderSelectedTab()
    }

    @objc private func handleRegeneratePreview() {
        switch selectedTab {
        case .theme:
            return
        case .avatar:
            renderAvatarPreview(regenerated: true)
        case .speech:
            do {
                try renderSpeechPreview(regenerated: true)
            } catch {
                showGenerationError(error)
                return
            }
        }
        renderSelectedTab()
    }

    @objc private func handleApply() {
        switch selectedTab {
        case .theme:
            return
        case .avatar:
            guard let avatarID = selectedAvatarID else {
                return
            }

            didFinish = true
            onChoose(avatarID)
            close()
        case .speech:
            if let speechDraftApplier {
                guard let pendingSpeechDraft else {
                    statusLabel.stringValue = copy("avatar_studio.status_ready", fallback: "先生成预览，确认满意后再应用。")
                    statusLabel.textColor = AvatarPanelTheme.muted
                    return
                }

                do {
                    try speechDraftApplier(pendingSpeechDraft)
                    appliedSpeechSummary = draftSpeechSummary
                    self.pendingSpeechDraft = nil
                    statusLabel.stringValue = copy("speech_studio.apply_status", fallback: "话术草稿已应用。")
                    statusLabel.textColor = AvatarPanelTheme.text
                    renderSelectedTab()
                } catch {
                    showGenerationError(error)
                }
            } else {
                appliedSpeechSummary = draftSpeechSummary
                statusLabel.stringValue = copy("speech_studio.apply_status", fallback: "话术草稿已应用。")
                statusLabel.textColor = AvatarPanelTheme.text
                renderSelectedTab()
            }
        }
    }

    @objc private func handleOptimizeThemePrompt() {
        do {
            try renderOptimizedThemePrompt(regenerated: false)
            renderSelectedTab()
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handleReoptimizeThemePrompt() {
        do {
            try renderOptimizedThemePrompt(regenerated: true)
            renderSelectedTab()
        } catch {
            showGenerationError(error)
        }
    }

    @objc private func handlePreviewTheme() {
        do {
            try renderThemePreview(regenerated: false)
            renderSelectedTab()
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
            return
        }

        if let themeDraftApplier {
            do {
                try themeDraftApplier(pendingThemePack)
                appliedThemeSummary = draftThemeSummary
                invalidateThemePreview()
                statusLabel.stringValue = copy("theme_studio.apply_status", fallback: "主题草稿已应用。")
                statusLabel.textColor = AvatarPanelTheme.text
                renderSelectedTab()
            } catch {
                showGenerationError(error)
            }
        } else {
            appliedThemeSummary = draftThemeSummary
            invalidateThemePreview()
            statusLabel.stringValue = copy("theme_studio.apply_status", fallback: "主题草稿已应用。")
            statusLabel.textColor = AvatarPanelTheme.text
            renderSelectedTab()
        }
    }

    @objc private func handleAddCustom() {
        didFinish = true
        onAddCustom()
        close()
    }

    @objc private func handleCancel() {
        didFinish = true
        onClose()
        close()
    }
}
