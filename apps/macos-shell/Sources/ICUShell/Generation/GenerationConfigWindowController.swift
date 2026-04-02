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
}

struct GenerationCapabilityFormViews {
    let providerPopup: NSPopUpButton
    let baseURLField: NSTextField
    let modelField: NSTextField
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

final class GenerationConfigWindowController: NSWindowController, NSWindowDelegate {
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private enum Layout {
        static let windowSize = NSSize(width: 804, height: 520)
        static let contentInset: CGFloat = 12
        static let rootSpacing: CGFloat = 8
        static let bodySpacing: CGFloat = 12
        static let headerSpacing: CGFloat = 1
        static let headerBottomSpacing: CGFloat = 2
        static let railWidth: CGFloat = 148
        static let railSpacing: CGFloat = 8
        static let cardInset: CGFloat = 12
        static let workbenchSpacing: CGFloat = 12
        static let modeSpacing: CGFloat = 8
        static let navigationButtonHeight: CGFloat = 34
        static let modeButtonHeight: CGFloat = 30
        static let saveButtonHeight: CGFloat = 34
        static let fieldRowSpacing: CGFloat = 10
        static let labelSpacing: CGFloat = 3
        static let fieldHeight: CGFloat = 42
        static let editorHeight: CGFloat = 112
        static let sectionSpacing: CGFloat = 12
    }

    private let settingsStore: GenerationSettingsStore
    private let themeManager: ThemeManager
    private let generationCoordinator: GenerationCoordinator
    private let onClose: () -> Void

    private(set) var formState: GenerationSettings
    let statusLabel = AvatarPanelTheme.makeLabel(TextCatalog.shared.text(.generationConfigStatusText), color: AvatarPanelTheme.muted)

    private var capabilityForms: [GenerationCapabilityKind: GenerationCapabilityFormViews] = [:]
    private var themeObserver: NSObjectProtocol?
    private var didFinish = false
    private var selectedCapability: GenerationCapabilityKind = .textDescription
    private var expandedAdvancedSections: [GenerationCapabilityKind: Bool] =
        Dictionary(uniqueKeysWithValues: GenerationCapabilityKind.allCases.map { ($0, false) })

    init(
        settingsStore: GenerationSettingsStore,
        themeManager: ThemeManager,
        generationCoordinator: GenerationCoordinator,
        onClose: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.themeManager = themeManager
        self.generationCoordinator = generationCoordinator
        self.onClose = onClose
        self.formState = (try? settingsStore.load()) ?? .default

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
        guard
            let window,
            let contentView = window.contentView
        else {
            return
        }

        _ = generationCoordinator
        _ = themeManager

        AvatarPanelTheme.styleWindow(window)
        contentView.subviews.forEach { $0.removeFromSuperview() }
        capabilityForms.removeAll()
        statusLabel.textColor = AvatarPanelTheme.muted
        if statusLabel.stringValue.isEmpty {
            statusLabel.stringValue = TextCatalog.shared.text(.generationConfigStatusText)
        }

        let root = NSStackView()
        root.orientation = .vertical
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

        let body = NSStackView(views: [buildCapabilityRail(), buildWorkbench()])
        body.orientation = .horizontal
        body.alignment = .top
        body.spacing = Layout.bodySpacing
        body.distribution = .fill

        statusLabel.font = AvatarPanelTheme.smallFont
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentHuggingPriority(.required, for: .vertical)

        root.addArrangedSubview(header)
        root.addArrangedSubview(body)
        root.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.contentInset),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.contentInset),
        ])
    }

    private func buildCapabilityRail() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.widthAnchor.constraint(equalToConstant: Layout.railWidth).isActive = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = Layout.railSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        for capability in GenerationCapabilityKind.allCases {
            let button = NSButton(title: capability.title, target: self, action: #selector(handleCapabilitySelection(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(capability.rawValue)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: Layout.navigationButtonHeight).isActive = true
            button.lineBreakMode = .byTruncatingTail

            if capability == selectedCapability {
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

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = Layout.workbenchSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        stack.addArrangedSubview(buildEditorModeBar())
        stack.addArrangedSubview(buildWorkbenchContent())
        stack.addArrangedSubview(buildSaveButton())

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInset),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInset),
        ])

        return card
    }

    private func buildEditorModeBar() -> NSView {
        let showingAdvanced = expandedAdvancedSections[selectedCapability] ?? false
        let basicButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigBasicButton),
            target: self,
            action: #selector(handleEditorModeSelection(_:))
        )
        basicButton.identifier = NSUserInterfaceItemIdentifier("generationConfigModeBasic")

        let advancedButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigAdvancedButton),
            target: self,
            action: #selector(handleEditorModeSelection(_:))
        )
        advancedButton.identifier = NSUserInterfaceItemIdentifier("generationConfigModeAdvanced")

        [basicButton, advancedButton].forEach { button in
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: Layout.modeButtonHeight).isActive = true
        }

        if showingAdvanced {
            AvatarPanelTheme.styleSecondaryButton(basicButton)
            AvatarPanelTheme.stylePrimaryButton(advancedButton)
        } else {
            AvatarPanelTheme.stylePrimaryButton(basicButton)
            AvatarPanelTheme.styleSecondaryButton(advancedButton)
        }

        let row = NSStackView(views: [basicButton, advancedButton, NSView()])
        row.orientation = .horizontal
        row.spacing = Layout.modeSpacing
        return row
    }

    private func buildWorkbenchContent() -> NSView {
        let scrollView = NSScrollView()
        AvatarPanelTheme.styleScrollView(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let detailView = buildCapabilityDetail(for: selectedCapability)
        detailView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(detailView)
        scrollView.documentView = documentView
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

        NSLayoutConstraint.activate([
            detailView.topAnchor.constraint(equalTo: documentView.topAnchor),
            detailView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            detailView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            detailView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            detailView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        return scrollView
    }

    private func buildCapabilityDetail(for kind: GenerationCapabilityKind) -> NSView {
        let contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let providerPopup = makeProviderPopup()
        let modelField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigModelPlaceholder),
            identifier: "generationConfigModelField"
        )
        let baseURLField = makeField(
            placeholder: TextCatalog.shared.text(.generationConfigBaseURLPlaceholder),
            identifier: "generationConfigBaseURLField"
        )
        let authTextView = makeEditorTextView(identifier: "generationConfigAuthEditor")
        let optionsTextView = makeEditorTextView(identifier: "generationConfigOptionsEditor")

        capabilityForms[kind] = GenerationCapabilityFormViews(
            providerPopup: providerPopup,
            baseURLField: baseURLField,
            modelField: modelField,
            authTextView: authTextView,
            optionsTextView: optionsTextView
        )

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = Layout.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let titleLabel = AvatarPanelTheme.makeLabel(kind.title, color: AvatarPanelTheme.accent, font: AvatarPanelTheme.smallFont)
        let descriptionLabel = AvatarPanelTheme.makeLabel(
            kind.detailDescription,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0
        let header = NSStackView(views: [titleLabel, descriptionLabel])
        header.orientation = .vertical
        header.spacing = Layout.headerSpacing

        let coreFields = NSStackView(views: [
            makeFieldRow(label: TextCatalog.shared.text(.generationConfigProviderLabel), control: providerPopup),
            makeFieldRow(label: TextCatalog.shared.text(.generationConfigModelLabel), control: modelField),
            makeFieldRow(label: TextCatalog.shared.text(.generationConfigBaseURLLabel), control: baseURLField),
        ])
        coreFields.orientation = .vertical
        coreFields.spacing = Layout.fieldRowSpacing

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(coreFields)

        if expandedAdvancedSections[kind] ?? false {
            let advancedFields = NSStackView(views: [
                makeEditorRow(label: TextCatalog.shared.text(.generationConfigAuthLabel), textView: authTextView),
                makeEditorRow(label: TextCatalog.shared.text(.generationConfigOptionsLabel), textView: optionsTextView),
            ])
            advancedFields.orientation = .vertical
            advancedFields.spacing = Layout.fieldRowSpacing
            stack.addArrangedSubview(advancedFields)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        return contentView
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
        row.spacing = Layout.modeSpacing
        return row
    }

    private func makeFieldRow(label: String, control: NSView) -> NSView {
        let titleLabel = AvatarPanelTheme.makeLabel(label, color: AvatarPanelTheme.muted, font: AvatarPanelTheme.smallFont)
        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .vertical
        row.spacing = Layout.labelSpacing
        return row
    }

    private func makeEditorRow(label: String, textView: NSTextView) -> NSView {
        makeFieldRow(label: label, control: makeEditorScrollView(for: textView))
    }

    private func makeProviderPopup() -> NSPopUpButton {
        let popup = NSPopUpButton()
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.identifier = NSUserInterfaceItemIdentifier("generationConfigProviderPopup")
        popup.font = AvatarPanelTheme.bodyFont
        popup.addItems(withTitles: [
            GenerationCapabilityProvider.ollama.rawValue,
            GenerationCapabilityProvider.huggingFace.rawValue,
            GenerationCapabilityProvider.openAICompatible.rawValue,
        ])
        popup.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return popup
    }

    private func makeField(placeholder: String, identifier: String) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        field.identifier = NSUserInterfaceItemIdentifier(identifier)
        AvatarPanelTheme.styleEditableTextField(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return field
    }

    private func makeEditorTextView(identifier: String) -> NSTextView {
        let textView = NSTextView()
        AvatarPanelTheme.styleTextView(textView)
        textView.identifier = NSUserInterfaceItemIdentifier(identifier)
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

    private func loadFormStateIntoFields() {
        load(config(for: selectedCapability), into: selectedCapability)
    }

    private func load(_ config: GenerationCapabilityConfig, into kind: GenerationCapabilityKind) {
        guard let form = capabilityForms[kind] else {
            return
        }

        form.providerPopup.selectItem(withTitle: config.provider.rawValue)
        form.baseURLField.stringValue = config.baseURL
        form.modelField.stringValue = config.model
        form.authTextView.string = makeJSONObjectString(config.auth)
        form.optionsTextView.string = makeJSONObjectString(config.options)
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

    private func persistFormState() throws {
        try syncDraftFromVisibleFields()
        try settingsStore.save(formState)
    }

    private func syncDraftFromVisibleFields() throws {
        formState = GenerationSettings(
            activeThemeID: formState.activeThemeID,
            textDescription: try updatedConfig(for: .textDescription, current: formState.textDescription),
            animationAvatar: try updatedConfig(for: .animationAvatar, current: formState.animationAvatar),
            codeGeneration: try updatedConfig(for: .codeGeneration, current: formState.codeGeneration)
        )
    }

    private func updatedConfig(
        for kind: GenerationCapabilityKind,
        current: GenerationCapabilityConfig
    ) throws -> GenerationCapabilityConfig {
        guard let form = capabilityForms[kind] else {
            return current
        }

        let selectedProviderTitle = form.providerPopup.titleOfSelectedItem?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let provider = GenerationCapabilityProvider(rawValue: selectedProviderTitle) ?? current.provider

        return GenerationCapabilityConfig(
            provider: provider,
            baseURL: form.baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            model: form.modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            auth: try parseStringDictionary(from: form.authTextView.string),
            options: try parseDoubleDictionary(from: form.optionsTextView.string)
        )
    }

    private func parseStringDictionary(from text: String) throws -> [String: String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw GenerationConfigFormError.invalidJSONObject(field: TextCatalog.shared.text(.generationConfigAuthLabel))
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw GenerationConfigFormError.invalidJSONObject(field: TextCatalog.shared.text(.generationConfigAuthLabel))
        }

        var parsed: [String: String] = [:]
        for (key, value) in dictionary {
            guard let stringValue = value as? String else {
                throw GenerationConfigFormError.invalidValue(field: TextCatalog.shared.text(.generationConfigAuthLabel), key: key)
            }
            parsed[key] = stringValue
        }
        return parsed
    }

    private func parseDoubleDictionary(from text: String) throws -> [String: Double] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        guard let data = trimmed.data(using: .utf8) else {
            throw GenerationConfigFormError.invalidJSONObject(field: TextCatalog.shared.text(.generationConfigOptionsLabel))
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw GenerationConfigFormError.invalidJSONObject(field: TextCatalog.shared.text(.generationConfigOptionsLabel))
        }

        var parsed: [String: Double] = [:]
        for (key, value) in dictionary {
            guard let number = value as? NSNumber else {
                throw GenerationConfigFormError.invalidValue(field: TextCatalog.shared.text(.generationConfigOptionsLabel), key: key)
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

    private func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            try? self.syncDraftFromVisibleFields()
            self.buildUI()
            self.loadFormStateIntoFields()
        }
    }

    @objc private func handleCapabilitySelection(_ sender: NSButton) {
        guard
            let rawValue = sender.identifier?.rawValue,
            let capability = GenerationCapabilityKind(rawValue: rawValue),
            capability != selectedCapability
        else {
            return
        }

        do {
            try syncDraftFromVisibleFields()
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = AvatarPanelTheme.danger
            return
        }

        selectedCapability = capability
        buildUI()
        loadFormStateIntoFields()
    }

    @objc private func handleEditorModeSelection(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue else {
            return
        }

        do {
            try syncDraftFromVisibleFields()
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = AvatarPanelTheme.danger
            return
        }

        expandedAdvancedSections[selectedCapability] = (identifier == "generationConfigModeAdvanced")
        buildUI()
        loadFormStateIntoFields()
    }

    @objc private func handleSave() {
        do {
            try persistFormState()
            statusLabel.stringValue = TextCatalog.shared.text(.generationConfigSaveSuccessStatus)
            statusLabel.textColor = AvatarPanelTheme.accent
        } catch {
            statusLabel.stringValue = error.localizedDescription
            statusLabel.textColor = AvatarPanelTheme.danger
        }
    }
}
