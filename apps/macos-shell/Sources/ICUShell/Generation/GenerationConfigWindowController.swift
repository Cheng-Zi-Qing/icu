import AppKit
import Foundation

extension GenerationCapabilityKind {
    var title: String {
        switch self {
        case .textDescription:
            return TextCatalog.shared.text(.generationConfigTextDescriptionTabTitle)
        case .animationAvatar:
            return TextCatalog.shared.text(.generationConfigAnimationAvatarTabTitle)
        case .codeGeneration:
            return TextCatalog.shared.text(.generationConfigCodeGenerationTabTitle)
        }
    }

    var detailDescription: String {
        switch self {
        case .textDescription:
            return TextCatalog.shared.text(.generationConfigTextDescriptionDetail)
        case .animationAvatar:
            return TextCatalog.shared.text(.generationConfigAnimationAvatarDetail)
        case .codeGeneration:
            return TextCatalog.shared.text(.generationConfigCodeGenerationDetail)
        }
    }

    var workbenchIdentifierStem: String {
        switch self {
        case .textDescription:
            return "TextDescription"
        case .animationAvatar:
            return "AnimationAvatar"
        case .codeGeneration:
            return "CodeGeneration"
        }
    }
}

extension GenerationProvider {
    static let workbenchOrder: [GenerationProvider] = [
        .openAI,
        .anthropic,
        .ollama,
        .huggingFace,
        .openAICompatible,
    ]

    var displayTitle: String {
        switch self {
        case .openAI:
            return TextCatalog.shared.text(.generationConfigProviderOpenAITitle)
        case .anthropic:
            return TextCatalog.shared.text(.generationConfigProviderAnthropicTitle)
        case .ollama:
            return TextCatalog.shared.text(.generationConfigProviderOllamaTitle)
        case .huggingFace:
            return TextCatalog.shared.text(.generationConfigProviderHuggingFaceTitle)
        case .openAICompatible:
            return TextCatalog.shared.text(.generationConfigProviderOpenAICompatibleTitle)
        }
    }

    var defaultHelperCopy: String {
        switch self {
        case .openAI:
            return TextCatalog.shared.text(.generationConfigProviderDefaultOpenAIHelper)
        case .anthropic:
            return TextCatalog.shared.text(.generationConfigProviderDefaultAnthropicHelper)
        case .ollama:
            return TextCatalog.shared.text(.generationConfigProviderDefaultOllamaHelper)
        case .huggingFace:
            return TextCatalog.shared.text(.generationConfigProviderDefaultHuggingFaceHelper)
        case .openAICompatible:
            return TextCatalog.shared.text(.generationConfigProviderDefaultOpenAICompatibleHelper)
        }
    }
}

private struct ProviderDefaultFormViews {
    let apiKeyField: NSTextField
    let baseURLField: NSTextField
    let headersTextView: NSTextView
    let authTextView: NSTextView
}

struct GenerationCapabilityFormViews {
    let providerPopup: NSPopUpButton
    let presetPopup: NSPopUpButton
    let modelField: NSTextField
    let apiKeyField: NSTextField
    let baseURLField: NSTextField
    let headersTextView: NSTextView
    let authTextView: NSTextView
    let optionsTextView: NSTextView
}

enum GenerationConfigFormError: Error, LocalizedError {
    case invalidJSONObject(field: String)
    case invalidValue(field: String, key: String)

    var errorDescription: String? {
        switch self {
        case let .invalidJSONObject(field):
            return String(format: TextCatalog.shared.text(.errorInvalidJSONObject), field)
        case let .invalidValue(field, key):
            return String(format: TextCatalog.shared.text(.errorInvalidJSONValue), field, key)
        }
    }
}

final class GenerationConfigWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate {
    static var makeConnectionTester: () -> GenerationConnectionTesting = { GenerationHTTPClient() }

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private struct VisibleProviderDefaultDraft {
        let apiKey: String
        let baseURL: String
        let headers: String
        let auth: String
    }

    private struct VisibleCapabilityDraft {
        let providerRawValue: String
        let preset: String
        let model: String
        let apiKey: String
        let baseURL: String
        let headers: String
        let auth: String
        let options: String
    }

    private struct VisibleWorkbenchDrafts {
        let providerDefault: VisibleProviderDefaultDraft?
        let capabilities: [GenerationCapabilityKind: VisibleCapabilityDraft]
    }

    private enum StatusState {
        case neutral
        case success(String)
        case error(String)
    }

    private enum Layout {
        static let windowSize = NSSize(width: 860, height: 540)
        static let contentInset: CGFloat = 8
        static let rootSpacing: CGFloat = 8
        static let bodySpacing: CGFloat = 10
        static let headerSpacing: CGFloat = 1
        static let headerBottomSpacing: CGFloat = 2
        static let railWidth: CGFloat = 148
        static let railSpacing: CGFloat = 8
        static let cardInset: CGFloat = 8
        static let workbenchSpacing: CGFloat = 10
        static let buttonSpacing: CGFloat = 8
        static let navigationButtonHeight: CGFloat = 34
        static let saveButtonHeight: CGFloat = 34
        static let fieldRowSpacing: CGFloat = 12
        static let labelSpacing: CGFloat = 4
        static let fieldHeight: CGFloat = 42
        static let editorHeight: CGFloat = 136
        static let sectionSpacing: CGFloat = 12
    }

    private let settingsStore: GenerationSettingsStore
    private let themeManager: ThemeManager
    private let connectionTester: GenerationConnectionTesting
    private let onClose: () -> Void

    private(set) var formState: GenerationSettings
    let statusLabel = AvatarPanelTheme.makeLabel(TextCatalog.shared.text(.generationConfigStatusText), color: AvatarPanelTheme.muted)

    private var providerDefaultForm: ProviderDefaultFormViews?
    private var capabilityForms: [GenerationCapabilityKind: GenerationCapabilityFormViews] = [:]
    private var themeObserver: NSObjectProtocol?
    private var didFinish = false
    private var selectedProvider: GenerationProvider = .openAI
    private var expandedProviderAdvanced = false
    private var expandedCapabilityAdvancedSections: [GenerationCapabilityKind: Bool] =
        Dictionary(uniqueKeysWithValues: GenerationCapabilityKind.allCases.map { ($0, false) })
    private var statusState: StatusState = .neutral

    init(
        settingsStore: GenerationSettingsStore,
        themeManager: ThemeManager,
        onClose: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.themeManager = themeManager
        self.connectionTester = Self.makeConnectionTester()
        self.onClose = onClose
        self.formState = Self.normalizeForWorkbench((try? settingsStore.load()) ?? .default)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        AvatarPanelTheme.styleWindow(window)
        super.init(window: window)
        window.delegate = self

        buildUI()
        loadFormStateIntoFields()
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
        guard let window, let contentView = window.contentView else {
            return
        }

        AvatarPanelTheme.styleWindow(window)
        contentView.subviews.forEach { $0.removeFromSuperview() }
        providerDefaultForm = nil
        capabilityForms.removeAll()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .width
        root.spacing = Layout.rootSpacing
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let titleLabel = AvatarPanelTheme.makeLabel(
            TextCatalog.shared.text(.generationConfigWindowTitle),
            color: AvatarPanelTheme.accent,
            font: AvatarPanelTheme.bodyFont
        )
        let subtitleLabel = AvatarPanelTheme.makeLabel(
            TextCatalog.shared.text(.generationConfigWindowSubtitle),
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        let header = NSStackView(views: [titleLabel, subtitleLabel])
        header.orientation = .vertical
        header.spacing = Layout.headerSpacing
        header.setCustomSpacing(Layout.headerBottomSpacing, after: subtitleLabel)

        let body = NSStackView(views: [buildProviderRail(), buildWorkbench()])
        body.orientation = .horizontal
        body.alignment = .top
        body.spacing = Layout.bodySpacing
        body.distribution = .fill
        body.setContentHuggingPriority(.defaultLow, for: .horizontal)
        body.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusLabel.font = AvatarPanelTheme.smallFont
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentHuggingPriority(.required, for: .vertical)
        applyStatusState()

        root.addArrangedSubview(header)
        root.addArrangedSubview(body)
        root.addArrangedSubview(statusLabel)
        body.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.contentInset),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.contentInset),
        ])
    }

    private func buildProviderRail() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: Layout.railWidth).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = Layout.railSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for provider in GenerationProvider.workbenchOrder {
            let button = NSButton(title: provider.displayTitle, target: self, action: #selector(handleProviderSelection(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(provider.rawValue)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: Layout.navigationButtonHeight).isActive = true
            button.lineBreakMode = .byTruncatingTail

            if provider == selectedProvider {
                AvatarPanelTheme.stylePrimaryButton(button)
            } else {
                AvatarPanelTheme.styleSecondaryButton(button)
            }

            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(NSView())

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInset),
        ])

        return card
    }

    private func buildWorkbench() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.setContentHuggingPriority(.defaultLow, for: .horizontal)
        card.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Layout.workbenchSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let workbenchContent = buildWorkbenchContent()
        let saveButtonRow = buildSaveButton()

        stack.addArrangedSubview(workbenchContent)
        stack.addArrangedSubview(saveButtonRow)

        workbenchContent.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        saveButtonRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInset),
        ])

        return card
    }

    private func buildWorkbenchContent() -> NSView {
        let scrollView = NSScrollView()
        AvatarPanelTheme.styleScrollView(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Layout.workbenchSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        let providerCard = buildProviderDefaultCard()
        stack.addArrangedSubview(providerCard)
        providerCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        for capability in GenerationCapabilityKind.allCases {
            let card = buildCapabilityCard(for: capability)
            stack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        return scrollView
    }

    private func buildProviderDefaultCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false

        let config = providerDefault(for: selectedProvider)
        let apiKeyField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigAPIKeyPlaceholder),
            identifier: "generationConfigProviderDefaultAPIKeyField"
        )
        let baseURLField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigBaseURLPlaceholder),
            identifier: "generationConfigProviderDefaultBaseURLField"
        )
        let headersTextView = makeEditorTextView(identifier: "generationConfigProviderDefaultHeadersEditor")
        let authTextView = makeEditorTextView(identifier: "generationConfigProviderDefaultAuthEditor")

        providerDefaultForm = ProviderDefaultFormViews(
            apiKeyField: apiKeyField,
            baseURLField: baseURLField,
            headersTextView: headersTextView,
            authTextView: authTextView
        )

        let titleLabel = AvatarPanelTheme.makeLabel(
            TextCatalog.shared.text(.generationConfigDefaultConfigTitle),
            color: AvatarPanelTheme.accent,
            font: AvatarPanelTheme.smallFont
        )
        let providerLabel = AvatarPanelTheme.makeLabel(
            selectedProvider.displayTitle,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        let helperLabel = AvatarPanelTheme.makeLabel(
            selectedProvider.defaultHelperCopy,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        helperLabel.maximumNumberOfLines = 0
        helperLabel.lineBreakMode = .byWordWrapping

        let header = NSStackView(views: [titleLabel, providerLabel, helperLabel])
        header.orientation = .vertical
        header.spacing = Layout.headerSpacing

        let actionRow = NSStackView()
        actionRow.orientation = .horizontal
        actionRow.spacing = Layout.buttonSpacing

        let advancedButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigAdvancedParamsButton),
            target: self,
            action: #selector(handleProviderDefaultAdvancedToggle(_:))
        )
        advancedButton.identifier = NSUserInterfaceItemIdentifier("generationConfigProviderDefaultAdvancedButton")
        styleSecondaryActionButton(advancedButton, selected: expandedProviderAdvanced)

        let testConnectionButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigTestConnectionButton),
            target: self,
            action: #selector(handleTestConnection(_:))
        )
        testConnectionButton.identifier = NSUserInterfaceItemIdentifier("generationConfigProviderDefaultTestConnectionButton")
        styleSecondaryActionButton(testConnectionButton, selected: false)

        actionRow.addArrangedSubview(advancedButton)
        actionRow.addArrangedSubview(NSView())
        actionRow.addArrangedSubview(testConnectionButton)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Layout.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        addFullWidthArrangedSubview(header, to: stack)

        let apiKeyRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigAPIKeyLabel), control: apiKeyField)
        addFullWidthArrangedSubview(apiKeyRow, to: stack)

        let baseURLRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigBaseURLLabel), control: baseURLField)
        addFullWidthArrangedSubview(baseURLRow, to: stack)

        addFullWidthArrangedSubview(actionRow, to: stack)

        if expandedProviderAdvanced {
            let headersRow = makeEditorRow(label: TextCatalog.shared.text(.generationConfigHeadersLabel), textView: headersTextView)
            addFullWidthArrangedSubview(headersRow, to: stack)

            let authRow = makeEditorRow(label: TextCatalog.shared.text(.generationConfigAuthLabel), textView: authTextView)
            addFullWidthArrangedSubview(authRow, to: stack)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInset),
        ])

        apiKeyField.stringValue = config.apiKey
        baseURLField.stringValue = config.baseURL
        headersTextView.string = makeJSONObjectString(config.headers)
        authTextView.string = makeJSONObjectString(config.auth)

        return card
    }

    private func buildCapabilityCard(for kind: GenerationCapabilityKind) -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false

        let config = config(for: kind)
        let providerPopup = makeProviderPopup(for: kind)
        let presetPopup = makePresetPopup(for: kind, config: config)
        let modelField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigModelPlaceholder),
            identifier: capabilityIdentifier(kind, suffix: "ModelField")
        )
        let apiKeyField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigAPIKeyPlaceholder),
            identifier: capabilityIdentifier(kind, suffix: "APIKeyField")
        )
        let baseURLField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigBaseURLPlaceholder),
            identifier: capabilityIdentifier(kind, suffix: "BaseURLField")
        )
        let headersTextView = makeEditorTextView(identifier: capabilityIdentifier(kind, suffix: "HeadersEditor"))
        let authTextView = makeEditorTextView(identifier: capabilityIdentifier(kind, suffix: "AuthEditor"))
        let optionsTextView = makeEditorTextView(identifier: capabilityIdentifier(kind, suffix: "OptionsEditor"))

        capabilityForms[kind] = GenerationCapabilityFormViews(
            providerPopup: providerPopup,
            presetPopup: presetPopup,
            modelField: modelField,
            apiKeyField: apiKeyField,
            baseURLField: baseURLField,
            headersTextView: headersTextView,
            authTextView: authTextView,
            optionsTextView: optionsTextView
        )

        let titleLabel = AvatarPanelTheme.makeLabel(kind.title, color: AvatarPanelTheme.accent, font: AvatarPanelTheme.smallFont)
        let descriptionLabel = AvatarPanelTheme.makeLabel(
            kind.detailDescription,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        descriptionLabel.maximumNumberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        let stateLabel = AvatarPanelTheme.makeLabel(
            capabilityStateText(for: config),
            color: config.customized ? AvatarPanelTheme.accent : AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        let header = NSStackView(views: [titleLabel, descriptionLabel, stateLabel])
        header.orientation = .vertical
        header.spacing = Layout.headerSpacing

        let customizeButton = NSButton(
            title: config.customized ? TextCatalog.shared.text(.generationConfigRestoreDefaultButton) : TextCatalog.shared.text(.generationConfigCustomizeButton),
            target: self,
            action: #selector(handleCapabilityCustomizeToggle(_:))
        )
        customizeButton.identifier = NSUserInterfaceItemIdentifier(capabilityIdentifier(kind, suffix: "CustomizeButton"))
        if config.customized {
            AvatarPanelTheme.styleSecondaryButton(customizeButton)
        } else {
            AvatarPanelTheme.stylePrimaryButton(customizeButton)
        }

        let advancedButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigAdvancedParamsButton),
            target: self,
            action: #selector(handleCapabilityAdvancedToggle(_:))
        )
        advancedButton.identifier = NSUserInterfaceItemIdentifier(capabilityIdentifier(kind, suffix: "AdvancedButton"))
        styleSecondaryActionButton(advancedButton, selected: expandedCapabilityAdvancedSections[kind] ?? false)
        advancedButton.isEnabled = config.customized
        advancedButton.alphaValue = config.customized ? 1 : 0.6

        let actionRow = NSStackView(views: [customizeButton, advancedButton, NSView()])
        actionRow.orientation = .horizontal
        actionRow.spacing = Layout.buttonSpacing

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Layout.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        addFullWidthArrangedSubview(header, to: stack)

        let providerRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigProviderLabel), control: providerPopup)
        addFullWidthArrangedSubview(providerRow, to: stack)

        let presetRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigPresetLabel), control: presetPopup)
        addFullWidthArrangedSubview(presetRow, to: stack)

        let modelRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigCustomModelLabel), control: modelField)
        addFullWidthArrangedSubview(modelRow, to: stack)

        addFullWidthArrangedSubview(actionRow, to: stack)

        if config.customized {
            let apiKeyRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigAPIKeyLabel), control: apiKeyField)
            addFullWidthArrangedSubview(apiKeyRow, to: stack)

            let baseURLRow = makeFieldRow(label: TextCatalog.shared.text(.generationConfigBaseURLLabel), control: baseURLField)
            addFullWidthArrangedSubview(baseURLRow, to: stack)
        }

        if expandedCapabilityAdvancedSections[kind] ?? false {
            let headersRow = makeEditorRow(label: TextCatalog.shared.text(.generationConfigHeadersLabel), textView: headersTextView)
            addFullWidthArrangedSubview(headersRow, to: stack)

            let authRow = makeEditorRow(label: TextCatalog.shared.text(.generationConfigAuthLabel), textView: authTextView)
            addFullWidthArrangedSubview(authRow, to: stack)

            let optionsRow = makeEditorRow(label: TextCatalog.shared.text(.generationConfigOptionsLabel), textView: optionsTextView)
            addFullWidthArrangedSubview(optionsRow, to: stack)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInset),
        ])

        load(config, into: kind)
        return card
    }

    private func buildSaveButton() -> NSView {
        let saveButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigSaveButton),
            target: self,
            action: #selector(handleSave)
        )
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.heightAnchor.constraint(equalToConstant: Layout.saveButtonHeight).isActive = true
        AvatarPanelTheme.stylePrimaryButton(saveButton)

        let row = NSStackView(views: [NSView(), saveButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Layout.buttonSpacing
        return row
    }

    private func makeFieldRow(label: String, control: NSView) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = AvatarPanelTheme.makeLabel(label, color: AvatarPanelTheme.muted, font: AvatarPanelTheme.smallFont)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        container.addSubview(titleLabel)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.labelSpacing),
            control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func addFullWidthArrangedSubview(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func makeEditorRow(label: String, textView: NSTextView) -> NSView {
        makeFieldRow(label: label, control: makeEditorScrollView(for: textView))
    }

    private func makeProviderPopup(for kind: GenerationCapabilityKind) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.identifier = NSUserInterfaceItemIdentifier(capabilityIdentifier(kind, suffix: "ProviderPopup"))
        popup.font = AvatarPanelTheme.bodyFont
        popup.target = self
        popup.action = #selector(handleCapabilityProviderChange(_:))
        popup.menu = NSMenu()
        popup.removeAllItems()
        for provider in kind.allowedProviders {
            let item = NSMenuItem(title: provider.displayTitle, action: nil, keyEquivalent: "")
            item.representedObject = provider.rawValue
            popup.menu?.addItem(item)
        }
        popup.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return popup
    }

    private func makePresetPopup(for kind: GenerationCapabilityKind, config: GenerationCapabilityConfig) -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.identifier = NSUserInterfaceItemIdentifier(capabilityIdentifier(kind, suffix: "PresetPopup"))
        popup.font = AvatarPanelTheme.bodyFont
        popup.target = self
        popup.action = #selector(handlePresetSelection(_:))
        popup.menu = NSMenu()
        popup.removeAllItems()

        let recommendedProvider = recommendedPresetProvider(for: kind, config: config)
        for preset in presetOptions(
            for: kind,
            provider: recommendedProvider,
            currentPreset: config.preset,
            currentModel: config.model
        ) {
            let item = NSMenuItem(title: preset, action: nil, keyEquivalent: "")
            item.representedObject = preset
            popup.menu?.addItem(item)
        }

        popup.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return popup
    }

    private func makeField(placeholder: String, identifier: String) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        field.identifier = NSUserInterfaceItemIdentifier(identifier)
        field.delegate = self
        AvatarPanelTheme.styleEditableTextField(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return field
    }

    private func makeEditorTextView(identifier: String) -> NSTextView {
        let textView = NSTextView()
        AvatarPanelTheme.styleTextView(textView)
        textView.identifier = NSUserInterfaceItemIdentifier(identifier)
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: Layout.editorHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        return textView
    }

    private func makeEditorScrollView(for textView: NSTextView) -> NSScrollView {
        let scrollView = NSScrollView()
        AvatarPanelTheme.styleScrollView(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.editorHeight).isActive = true
        return scrollView
    }

    private func styleSecondaryActionButton(_ button: NSButton, selected: Bool) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: Layout.navigationButtonHeight).isActive = true
        if selected {
            AvatarPanelTheme.stylePrimaryButton(button)
        } else {
            AvatarPanelTheme.styleSecondaryButton(button)
        }
    }

    private func loadFormStateIntoFields() {
        loadProviderDefault(for: selectedProvider)
        for capability in GenerationCapabilityKind.allCases {
            load(config(for: capability), into: capability)
        }
    }

    private func loadProviderDefault(for provider: GenerationProvider) {
        guard let form = providerDefaultForm else {
            return
        }
        let config = providerDefault(for: provider)
        form.apiKeyField.stringValue = config.apiKey
        form.baseURLField.stringValue = config.baseURL
        form.headersTextView.string = makeJSONObjectString(config.headers)
        form.authTextView.string = makeJSONObjectString(config.auth)
    }

    private func load(_ config: GenerationCapabilityConfig, into kind: GenerationCapabilityKind) {
        guard let form = capabilityForms[kind] else {
            return
        }

        selectItem(in: form.providerPopup, rawValue: config.provider.rawValue)
        selectItem(in: form.presetPopup, rawValue: config.preset.isEmpty ? config.model : config.preset)
        form.modelField.stringValue = config.model

        let resolvedProviderDefault = formState.providerDefaults[config.provider]
        let customSeed = config.custom ?? GenerationCapabilityCustomTransport(
            apiKey: resolvedProviderDefault?.apiKey ?? config.auth["api_key"] ?? "",
            baseURL: resolvedProviderDefault?.baseURL ?? config.baseURL,
            headers: resolvedProviderDefault?.headers ?? config.headers,
            auth: resolvedProviderDefault?.auth ?? config.auth
        )
        form.apiKeyField.stringValue = customSeed.apiKey
        form.baseURLField.stringValue = customSeed.baseURL
        form.headersTextView.string = makeJSONObjectString(config.customized ? customSeed.headers : resolvedProviderDefault?.headers ?? config.headers)
        form.authTextView.string = makeJSONObjectString(config.customized ? customSeed.auth : resolvedProviderDefault?.auth ?? config.auth)
        form.optionsTextView.string = makeJSONObjectString(config.options)
    }

    private static func normalizeForWorkbench(_ settings: GenerationSettings) -> GenerationSettings {
        var providerDefaults = settings.providerDefaults
        let seededCapabilities = [settings.textDescription, settings.animationAvatar, settings.codeGeneration]

        for capability in seededCapabilities {
            guard providerDefaults[capability.provider] == nil else {
                continue
            }

            let seed = capability.custom ?? GenerationCapabilityCustomTransport(
                apiKey: capability.auth["api_key"] ?? "",
                baseURL: capability.baseURL,
                headers: capability.headers,
                auth: capability.auth
            )
            let hasSeedTransport = !seed.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !seed.apiKey.isEmpty
                || !seed.headers.isEmpty
                || !seed.auth.isEmpty
            if hasSeedTransport {
                providerDefaults[capability.provider] = GenerationProviderDefaultConfig(
                    apiKey: seed.apiKey,
                    baseURL: seed.baseURL,
                    headers: seed.headers,
                    auth: seed.auth
                )
            }
        }

        return GenerationSettings(
            activeThemeID: settings.activeThemeID,
            providerDefaults: providerDefaults,
            textDescription: collapseCapabilityForWorkbench(settings.textDescription, providerDefaults: providerDefaults),
            animationAvatar: collapseCapabilityForWorkbench(settings.animationAvatar, providerDefaults: providerDefaults),
            codeGeneration: collapseCapabilityForWorkbench(settings.codeGeneration, providerDefaults: providerDefaults)
        )
    }

    private static func collapseCapabilityForWorkbench(
        _ capability: GenerationCapabilityConfig,
        providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    ) -> GenerationCapabilityConfig {
        let providerDefault = providerDefaults[capability.provider]
        let transport = capability.custom ?? GenerationCapabilityCustomTransport(
            apiKey: capability.auth["api_key"] ?? "",
            baseURL: capability.baseURL,
            headers: capability.headers,
            auth: capability.auth
        )
        let preset = capability.preset.isEmpty ? capability.model : capability.preset

        if let providerDefault,
           transport.baseURL == providerDefault.baseURL,
           transport.headers == providerDefault.headers,
           transport.resolvedAuth == providerDefault.resolvedAuth {
            return GenerationCapabilityConfig(
                provider: capability.provider,
                preset: preset,
                model: capability.model,
                customized: false,
                custom: nil,
                headers: providerDefault.headers,
                baseURL: providerDefault.baseURL,
                auth: providerDefault.resolvedAuth,
                options: capability.options
            )
        }

        return capability.resolvedProviderConfig(providerDefault: providerDefault)
    }

    private func captureVisibleDrafts() -> VisibleWorkbenchDrafts {
        var capabilityDrafts: [GenerationCapabilityKind: VisibleCapabilityDraft] = [:]
        for capability in GenerationCapabilityKind.allCases {
            if let draft = captureVisibleDraft(for: capability) {
                capabilityDrafts[capability] = draft
            }
        }

        return VisibleWorkbenchDrafts(
            providerDefault: captureProviderDefaultDraft(),
            capabilities: capabilityDrafts
        )
    }

    private func captureProviderDefaultDraft() -> VisibleProviderDefaultDraft? {
        guard let form = providerDefaultForm else {
            return nil
        }
        return VisibleProviderDefaultDraft(
            apiKey: form.apiKeyField.stringValue,
            baseURL: form.baseURLField.stringValue,
            headers: form.headersTextView.string,
            auth: form.authTextView.string
        )
    }

    private func captureVisibleDraft(for kind: GenerationCapabilityKind) -> VisibleCapabilityDraft? {
        guard let form = capabilityForms[kind] else {
            return nil
        }
        return VisibleCapabilityDraft(
            providerRawValue: selectedRawValue(from: form.providerPopup) ?? config(for: kind).provider.rawValue,
            preset: selectedRawValue(from: form.presetPopup) ?? config(for: kind).preset,
            model: form.modelField.stringValue,
            apiKey: form.apiKeyField.stringValue,
            baseURL: form.baseURLField.stringValue,
            headers: form.headersTextView.string,
            auth: form.authTextView.string,
            options: form.optionsTextView.string
        )
    }

    private func applyVisibleDrafts(_ drafts: VisibleWorkbenchDrafts) {
        if let providerDraft = drafts.providerDefault, let form = providerDefaultForm {
            form.apiKeyField.stringValue = providerDraft.apiKey
            form.baseURLField.stringValue = providerDraft.baseURL
            form.headersTextView.string = providerDraft.headers
            form.authTextView.string = providerDraft.auth
        }

        for (kind, draft) in drafts.capabilities {
            guard let form = capabilityForms[kind] else {
                continue
            }
            selectItem(in: form.providerPopup, rawValue: draft.providerRawValue)
            selectItem(in: form.presetPopup, rawValue: draft.preset)
            form.modelField.stringValue = draft.model
            form.apiKeyField.stringValue = draft.apiKey
            form.baseURLField.stringValue = draft.baseURL
            form.headersTextView.string = draft.headers
            form.authTextView.string = draft.auth
            form.optionsTextView.string = draft.options
        }
    }

    private func applyStatusState() {
        switch statusState {
        case .neutral:
            statusLabel.stringValue = TextCatalog.shared.text(.generationConfigStatusText)
            statusLabel.textColor = AvatarPanelTheme.muted
        case let .success(message):
            statusLabel.stringValue = message
            statusLabel.textColor = AvatarPanelTheme.accent
        case let .error(message):
            statusLabel.stringValue = message
            statusLabel.textColor = AvatarPanelTheme.danger
        }
    }

    private func setNeutralStatus() {
        statusState = .neutral
        applyStatusState()
    }

    private func setSuccessStatus(_ message: String) {
        statusState = .success(message)
        applyStatusState()
    }

    private func setErrorStatus(_ message: String) {
        statusState = .error(message)
        applyStatusState()
    }

    private func providerDefault(for provider: GenerationProvider) -> GenerationProviderDefaultConfig {
        formState.providerDefaults[provider] ?? GenerationProviderDefaultConfig()
    }

    private func config(for kind: GenerationCapabilityKind) -> GenerationCapabilityConfig {
        switch kind {
        case .textDescription:
            return formState.textDescription
        case .animationAvatar:
            return formState.animationAvatar
        case .codeGeneration:
            return formState.codeGeneration
        }
    }

    private func setConfig(_ config: GenerationCapabilityConfig, for kind: GenerationCapabilityKind) {
        switch kind {
        case .textDescription:
            formState.textDescription = config
        case .animationAvatar:
            formState.animationAvatar = config
        case .codeGeneration:
            formState.codeGeneration = config
        }
    }

    private func persistFormState() throws {
        try syncDraftFromVisibleFields()
        try settingsStore.save(formState)
    }

    private func syncDraftFromVisibleFields() throws {
        var providerDefaults = formState.providerDefaults
        providerDefaults = try updatedProviderDefaults(from: providerDefaults)

        formState = GenerationSettings(
            activeThemeID: formState.activeThemeID,
            providerDefaults: providerDefaults,
            textDescription: try updatedConfig(
                for: .textDescription,
                current: formState.textDescription,
                providerDefaults: providerDefaults
            ),
            animationAvatar: try updatedConfig(
                for: .animationAvatar,
                current: formState.animationAvatar,
                providerDefaults: providerDefaults
            ),
            codeGeneration: try updatedConfig(
                for: .codeGeneration,
                current: formState.codeGeneration,
                providerDefaults: providerDefaults
            )
        )
    }

    private func updatedProviderDefaults(
        from currentProviderDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    ) throws -> [GenerationProvider: GenerationProviderDefaultConfig] {
        guard let form = providerDefaultForm else {
            return currentProviderDefaults
        }

        var nextProviderDefaults = currentProviderDefaults
        let updated = GenerationProviderDefaultConfig(
            apiKey: form.apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: form.baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            headers: try parseStringDictionary(
                from: form.headersTextView.string,
                field: TextCatalog.shared.text(.generationConfigHeadersLabel)
            ),
            auth: try parseStringDictionary(
                from: form.authTextView.string,
                field: TextCatalog.shared.text(.generationConfigAuthLabel)
            )
        )

        if isEmptyProviderDefault(updated) {
            nextProviderDefaults.removeValue(forKey: selectedProvider)
        } else {
            nextProviderDefaults[selectedProvider] = updated
        }
        return nextProviderDefaults
    }

    private func updatedConfig(
        for kind: GenerationCapabilityKind,
        current: GenerationCapabilityConfig,
        providerDefaults: [GenerationProvider: GenerationProviderDefaultConfig]
    ) throws -> GenerationCapabilityConfig {
        guard let form = capabilityForms[kind] else {
            return current
        }

        let providerRawValue = selectedRawValue(from: form.providerPopup) ?? current.provider.rawValue
        let provider = GenerationCapabilityProvider(rawValue: providerRawValue) ?? current.provider
        let preset = selectedRawValue(from: form.presetPopup)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? current.preset
        let model = trimmedModelValue(from: form.modelField.stringValue, fallbackPreset: preset, fallbackModel: current.model)
        // Non-customized cards preload hidden transport editors from provider defaults.
        // Ignore those seeded values until the card is actually in customized mode.
        let shouldReadCustomTransport = current.customized
        let apiKey = shouldReadCustomTransport
            ? form.apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let baseURL = shouldReadCustomTransport
            ? form.baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let headers = shouldReadCustomTransport
            ? try parseStringDictionary(
                from: form.headersTextView.string,
                field: TextCatalog.shared.text(.generationConfigHeadersLabel)
            )
            : [:]
        let auth = shouldReadCustomTransport
            ? try parseStringDictionary(
                from: form.authTextView.string,
                field: TextCatalog.shared.text(.generationConfigAuthLabel)
            )
            : [:]
        let options = try parseDoubleDictionary(
            from: form.optionsTextView.string,
            field: TextCatalog.shared.text(.generationConfigOptionsLabel)
        )

        let customized = shouldReadCustomTransport && (current.customized || !apiKey.isEmpty || !baseURL.isEmpty || !headers.isEmpty || !auth.isEmpty)
        let custom = customized
            ? GenerationCapabilityCustomTransport(
                apiKey: apiKey,
                baseURL: baseURL,
                headers: headers,
                auth: auth
            )
            : nil
        let providerDefault = providerDefaults[provider]
        let resolvedTransport = resolvedTransport(providerDefault: providerDefault, custom: custom)

        return GenerationCapabilityConfig(
            provider: provider,
            preset: preset.isEmpty ? model : preset,
            model: model,
            customized: customized,
            custom: custom,
            headers: customized ? resolvedTransport.headers : (providerDefault?.headers ?? [:]),
            baseURL: customized ? resolvedTransport.baseURL : (providerDefault?.baseURL ?? ""),
            auth: customized ? resolvedTransport.auth : (providerDefault?.resolvedAuth ?? [:]),
            options: options
        )
    }

    private func resolvedTransport(
        providerDefault: GenerationProviderDefaultConfig?,
        custom: GenerationCapabilityCustomTransport?
    ) -> (baseURL: String, auth: [String: String], headers: [String: String]) {
        guard let custom else {
            return (
                providerDefault?.baseURL ?? "",
                providerDefault?.resolvedAuth ?? [:],
                providerDefault?.headers ?? [:]
            )
        }
        return (custom.baseURL, custom.resolvedAuth, custom.headers)
    }

    private func trimmedModelValue(from rawValue: String, fallbackPreset: String, fallbackModel: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if !fallbackPreset.isEmpty {
            return fallbackPreset
        }
        return fallbackModel
    }

    private func parseStringDictionary(from text: String, field: String) throws -> [String: String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw GenerationConfigFormError.invalidJSONObject(field: field)
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw GenerationConfigFormError.invalidJSONObject(field: field)
        }
        guard let dictionary = object as? [String: Any] else {
            throw GenerationConfigFormError.invalidJSONObject(field: field)
        }

        var parsed: [String: String] = [:]
        for (key, value) in dictionary {
            guard let stringValue = value as? String else {
                throw GenerationConfigFormError.invalidValue(field: field, key: key)
            }
            parsed[key] = stringValue
        }
        return parsed
    }

    private func parseDoubleDictionary(from text: String, field: String) throws -> [String: Double] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw GenerationConfigFormError.invalidJSONObject(field: field)
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw GenerationConfigFormError.invalidJSONObject(field: field)
        }
        guard let dictionary = object as? [String: Any] else {
            throw GenerationConfigFormError.invalidJSONObject(field: field)
        }

        var parsed: [String: Double] = [:]
        for (key, value) in dictionary {
            guard let number = value as? NSNumber else {
                throw GenerationConfigFormError.invalidValue(field: field, key: key)
            }
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                throw GenerationConfigFormError.invalidValue(field: field, key: key)
            }
            parsed[key] = number.doubleValue
        }
        return parsed
    }

    private func makeJSONObjectString<T>(_ dictionary: [String: T]) -> String {
        guard !dictionary.isEmpty else {
            return ""
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
            let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return string
    }

    private func capabilityIdentifier(_ kind: GenerationCapabilityKind, suffix: String) -> String {
        "generationConfig\(kind.workbenchIdentifierStem)\(suffix)"
    }

    private func selectedRawValue(from popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private func selectItem(in popup: NSPopUpButton, rawValue: String) {
        if let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? String) == rawValue }) {
            popup.selectItem(at: index)
        } else if !rawValue.isEmpty {
            let item = NSMenuItem(title: rawValue, action: nil, keyEquivalent: "")
            item.representedObject = rawValue
            popup.menu?.insertItem(item, at: 0)
            popup.selectItem(at: 0)
        }
    }

    private func presetOptions(
        for kind: GenerationCapabilityKind,
        provider: GenerationProvider,
        currentPreset: String,
        currentModel: String
    ) -> [String] {
        let defaults: [String]
        switch (kind, provider) {
        case (.textDescription, .openAI):
            defaults = ["gpt-4.1-mini", "gpt-4.1"]
        case (.textDescription, .anthropic):
            defaults = ["claude-3-5-haiku-latest", "claude-3-7-sonnet-latest"]
        case (.textDescription, .ollama):
            defaults = ["qwen3:8b", "llama3.1:8b"]
        case (.textDescription, .openAICompatible):
            defaults = ["gpt-4.1-mini", "llama-3.3-70b-instruct"]
        case (.animationAvatar, .openAI):
            defaults = ["gpt-image-1"]
        case (.animationAvatar, .huggingFace):
            defaults = ["black-forest-labs/FLUX.1-schnell", "stabilityai/stable-diffusion-xl-base-1.0"]
        case (.animationAvatar, .openAICompatible):
            defaults = ["gpt-image-1", "flux-schnell"]
        case (.codeGeneration, .openAI):
            defaults = ["gpt-4.1-mini", "gpt-4.1"]
        case (.codeGeneration, .anthropic):
            defaults = ["claude-3-7-sonnet-latest", "claude-3-5-haiku-latest"]
        case (.codeGeneration, .ollama):
            defaults = ["qwen2.5-coder:7b", "deepseek-coder-v2:16b"]
        case (.codeGeneration, .openAICompatible):
            defaults = ["gpt-4.1-mini", "codestral-latest"]
        default:
            defaults = []
        }

        var options: [String] = []
        for candidate in [currentPreset, currentModel] + defaults {
            guard !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            if !options.contains(candidate) {
                options.append(candidate)
            }
        }
        return options
    }

    private func recommendedPresetProvider(
        for kind: GenerationCapabilityKind,
        config: GenerationCapabilityConfig
    ) -> GenerationProvider {
        if kind.allowedProviders.contains(selectedProvider) {
            return selectedProvider
        }
        return config.provider
    }

    private func capabilityStateText(for config: GenerationCapabilityConfig) -> String {
        if config.customized {
            return TextCatalog.shared.text(.generationConfigCustomizedState)
        }
        return TextCatalog.shared.text(.generationConfigUsingDefaultState)
    }

    private func isEmptyProviderDefault(_ config: GenerationProviderDefaultConfig) -> Bool {
        config.apiKey.isEmpty && config.baseURL.isEmpty && config.headers.isEmpty && config.auth.isEmpty
    }

    private func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            let visibleDrafts = self.captureVisibleDrafts()
            do {
                try self.syncDraftFromVisibleFields()
                self.buildUI()
                self.loadFormStateIntoFields()
            } catch {
                self.setErrorStatus(error.localizedDescription)
                self.buildUI()
                self.loadFormStateIntoFields()
                self.applyVisibleDrafts(visibleDrafts)
            }
        }
    }

    @objc private func handleProviderSelection(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue, let provider = GenerationProvider(rawValue: rawValue), provider != selectedProvider else {
            return
        }

        do {
            try syncDraftFromVisibleFields()
        } catch {
            setErrorStatus(error.localizedDescription)
            return
        }

        selectedProvider = provider
        buildUI()
        loadFormStateIntoFields()
    }

    @objc private func handleProviderDefaultAdvancedToggle(_ sender: NSButton) {
        do {
            try syncDraftFromVisibleFields()
        } catch {
            setErrorStatus(error.localizedDescription)
            return
        }

        expandedProviderAdvanced.toggle()
        buildUI()
        loadFormStateIntoFields()
    }

    @objc private func handleCapabilityProviderChange(_ sender: NSPopUpButton) {
        do {
            try syncDraftFromVisibleFields()
            buildUI()
            loadFormStateIntoFields()
            setNeutralStatus()
        } catch {
            setErrorStatus(error.localizedDescription)
        }
    }

    @objc private func handlePresetSelection(_ sender: NSPopUpButton) {
        guard
            let identifier = sender.identifier?.rawValue,
            let kind = capabilityKind(from: identifier),
            let form = capabilityForms[kind],
            let preset = selectedRawValue(from: sender)
        else {
            return
        }

        form.modelField.stringValue = preset
        setNeutralStatus()
    }

    @objc private func handleCapabilityCustomizeToggle(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue, let kind = capabilityKind(from: identifier) else {
            return
        }

        do {
            try syncDraftFromVisibleFields()
        } catch {
            setErrorStatus(error.localizedDescription)
            return
        }

        var config = config(for: kind)
        let providerDefault = formState.providerDefaults[config.provider]
        if config.customized {
            config.customized = false
            config.custom = nil
            config.baseURL = providerDefault?.baseURL ?? ""
            config.auth = providerDefault?.resolvedAuth ?? [:]
            config.headers = providerDefault?.headers ?? [:]
            expandedCapabilityAdvancedSections[kind] = false
        } else {
            let custom = GenerationCapabilityCustomTransport(
                apiKey: providerDefault?.apiKey ?? config.auth["api_key"] ?? "",
                baseURL: providerDefault?.baseURL ?? config.baseURL,
                headers: providerDefault?.headers ?? config.headers,
                auth: providerDefault?.auth ?? config.auth
            )
            config.customized = true
            config.custom = custom
            config.baseURL = custom.baseURL
            config.auth = custom.resolvedAuth
            config.headers = custom.headers
        }
        setConfig(config, for: kind)

        buildUI()
        loadFormStateIntoFields()
        setNeutralStatus()
    }

    @objc private func handleCapabilityAdvancedToggle(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue, let kind = capabilityKind(from: identifier) else {
            return
        }

        do {
            try syncDraftFromVisibleFields()
        } catch {
            setErrorStatus(error.localizedDescription)
            return
        }

        guard config(for: kind).customized else {
            setNeutralStatus()
            return
        }

        expandedCapabilityAdvancedSections[kind] = !(expandedCapabilityAdvancedSections[kind] ?? false)
        buildUI()
        loadFormStateIntoFields()
    }

    @objc private func handleTestConnection(_ sender: NSButton) {
        do {
            let providerDefaults = try updatedProviderDefaults(from: formState.providerDefaults)
            let defaults = providerDefaults[selectedProvider] ?? GenerationProviderDefaultConfig()
            try connectionTester.testConnection(provider: selectedProvider, defaults: defaults)
            let message = String(
                format: TextCatalog.shared.text(.generationConfigTestConnectionSuccessStatus),
                selectedProvider.displayTitle
            )
            setSuccessStatus(message)
        } catch {
            let message = String(
                format: TextCatalog.shared.text(.generationConfigTestConnectionFailureStatus),
                selectedProvider.displayTitle,
                error.localizedDescription
            )
            setErrorStatus(message)
        }
    }

    @objc private func handleSave() {
        do {
            try persistFormState()
            setSuccessStatus(TextCatalog.shared.text(.generationConfigSaveSuccessStatus))
        } catch {
            setErrorStatus(error.localizedDescription)
        }
    }

    private func capabilityKind(from identifier: String) -> GenerationCapabilityKind? {
        GenerationCapabilityKind.allCases.first { identifier.contains($0.workbenchIdentifierStem) }
    }

    func controlTextDidChange(_ obj: Notification) {
        setNeutralStatus()
    }

    func textDidChange(_ notification: Notification) {
        setNeutralStatus()
    }
}
