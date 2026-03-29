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
    let providerField: NSTextField
    let baseURLField: NSTextField
    let modelField: NSTextField
    let authField: NSTextField
    let optionsField: NSTextField
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
    private enum Layout {
        static let windowSize = NSSize(width: 804, height: 520)
        static let contentInset: CGFloat = 16
        static let rootSpacing: CGFloat = 8
        static let contentSpacing: CGFloat = 8
        static let tabSpacing: CGFloat = 8
        static let tabHeight: CGFloat = 30
        static let fieldRowSpacing: CGFloat = 10
        static let labelSpacing: CGFloat = 5
        static let fieldHeight: CGFloat = 42
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
        statusLabel.stringValue = TextCatalog.shared.text(.generationConfigStatusText)

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = Layout.rootSpacing
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        let titleLabel = AvatarPanelTheme.makeTitleLabel(TextCatalog.shared.text(.generationConfigWindowTitle))
        let subtitleLabel = AvatarPanelTheme.makeLabel(
            TextCatalog.shared.text(.generationConfigWindowSubtitle),
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        let header = NSStackView(views: [titleLabel, subtitleLabel])
        header.orientation = .vertical
        header.spacing = 2

        statusLabel.font = AvatarPanelTheme.smallFont
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentHuggingPriority(.required, for: .vertical)

        root.addArrangedSubview(header)
        root.addArrangedSubview(buildTabBar())
        root.addArrangedSubview(buildDetailContainer())
        root.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.contentInset),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.contentInset),
        ])
    }

    private func buildTabBar() -> NSView {
        let tabs = NSStackView()
        tabs.orientation = .horizontal
        tabs.spacing = Layout.tabSpacing

        for capability in GenerationCapabilityKind.allCases {
            let button = NSButton(title: capability.title, target: self, action: #selector(handleCapabilitySelection(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(capability.rawValue)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: Layout.tabHeight).isActive = true

            if capability == selectedCapability {
                AvatarPanelTheme.stylePrimaryButton(button)
            } else {
                AvatarPanelTheme.styleSecondaryButton(button)
            }

            tabs.addArrangedSubview(button)
        }

        return tabs
    }

    private func buildDetailContainer() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let detailView = buildCapabilityDetail(for: selectedCapability)
        detailView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(detailView)
        scrollView.documentView = documentView
        card.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.contentInset),
            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.contentInset),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.contentInset),
            scrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.contentInset),
            detailView.topAnchor.constraint(equalTo: documentView.topAnchor),
            detailView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            detailView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            detailView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            detailView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        return card
    }

    private func buildCapabilityDetail(for kind: GenerationCapabilityKind) -> NSView {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = Layout.contentSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let titleLabel = AvatarPanelTheme.makeTitleLabel(kind.title)
        let descriptionLabel = AvatarPanelTheme.makeLabel(
            kind.detailDescription,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        let detailHeader = NSStackView(views: [titleLabel, descriptionLabel])
        detailHeader.orientation = .vertical
        detailHeader.spacing = 2

        let basicLabel = AvatarPanelTheme.makeLabel(TextCatalog.shared.text(.generationConfigBasicSectionTitle), color: AvatarPanelTheme.accent)

        let providerField = makeField(placeholder: TextCatalog.shared.text(.generationConfigProviderPlaceholder))
        let modelField = makeField(placeholder: TextCatalog.shared.text(.generationConfigModelPlaceholder))
        let baseURLField = makeField(placeholder: TextCatalog.shared.text(.generationConfigBaseURLPlaceholder))
        let authField = makeField(placeholder: TextCatalog.shared.text(.generationConfigAuthPlaceholder))
        let optionsField = makeField(placeholder: TextCatalog.shared.text(.generationConfigOptionsPlaceholder))

        capabilityForms[kind] = GenerationCapabilityFormViews(
            providerField: providerField,
            baseURLField: baseURLField,
            modelField: modelField,
            authField: authField,
            optionsField: optionsField
        )

        let basicStack = NSStackView(views: [
            makeFieldRow(label: TextCatalog.shared.text(.generationConfigProviderLabel), field: providerField),
            makeFieldRow(label: TextCatalog.shared.text(.generationConfigModelLabel), field: modelField),
            makeFieldRow(label: TextCatalog.shared.text(.generationConfigBaseURLLabel), field: baseURLField),
        ])
        basicStack.orientation = .vertical
        basicStack.spacing = Layout.fieldRowSpacing

        let advancedButton = NSButton(
            title: (expandedAdvancedSections[kind] ?? false)
                ? TextCatalog.shared.text(.generationConfigHideAdvancedButton)
                : TextCatalog.shared.text(.generationConfigShowAdvancedButton),
            target: self,
            action: #selector(handleAdvancedToggle(_:))
        )
        advancedButton.identifier = NSUserInterfaceItemIdentifier("advanced-\(kind.rawValue)")
        advancedButton.alignment = .left
        AvatarPanelTheme.styleSecondaryButton(advancedButton)
        advancedButton.translatesAutoresizingMaskIntoConstraints = false
        advancedButton.heightAnchor.constraint(equalToConstant: Layout.tabHeight).isActive = true

        stack.addArrangedSubview(detailHeader)
        stack.addArrangedSubview(basicLabel)
        stack.addArrangedSubview(basicStack)
        stack.addArrangedSubview(advancedButton)

        if expandedAdvancedSections[kind] ?? false {
            let advancedLabel = AvatarPanelTheme.makeLabel(TextCatalog.shared.text(.generationConfigAdvancedSectionTitle), color: AvatarPanelTheme.accent)
            let advancedStack = NSStackView(views: [
                makeFieldRow(label: TextCatalog.shared.text(.generationConfigAuthLabel), field: authField),
                makeFieldRow(label: TextCatalog.shared.text(.generationConfigOptionsLabel), field: optionsField),
            ])
            advancedStack.orientation = .vertical
            advancedStack.spacing = Layout.fieldRowSpacing

            stack.addArrangedSubview(advancedLabel)
            stack.addArrangedSubview(advancedStack)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        return contentView
    }

    private func makeFieldRow(label: String, field: NSTextField) -> NSView {
        let titleLabel = AvatarPanelTheme.makeLabel(label, color: AvatarPanelTheme.muted, font: AvatarPanelTheme.smallFont)
        let row = NSStackView(views: [titleLabel, field])
        row.orientation = .vertical
        row.spacing = Layout.labelSpacing
        return row
    }

    private func makeField(placeholder: String) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        AvatarPanelTheme.styleEditableTextField(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return field
    }

    private func loadFormStateIntoFields() {
        load(config(for: selectedCapability), into: selectedCapability)
    }

    private func load(_ config: GenerationCapabilityConfig, into kind: GenerationCapabilityKind) {
        guard let form = capabilityForms[kind] else {
            return
        }

        form.providerField.stringValue = config.provider.rawValue
        form.baseURLField.stringValue = config.baseURL
        form.modelField.stringValue = config.model
        form.authField.stringValue = makeJSONObjectString(config.auth)
        form.optionsField.stringValue = makeJSONObjectString(config.options)
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

        let provider = GenerationCapabilityProvider(
            rawValue: form.providerField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? current.provider

        return GenerationCapabilityConfig(
            provider: provider,
            baseURL: form.baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            model: form.modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            auth: try parseStringDictionary(from: form.authField.stringValue),
            options: try parseDoubleDictionary(from: form.optionsField.stringValue)
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

    @objc private func handleAdvancedToggle(_ sender: NSButton) {
        guard
            let rawIdentifier = sender.identifier?.rawValue,
            let capability = GenerationCapabilityKind(rawValue: rawIdentifier.replacingOccurrences(of: "advanced-", with: ""))
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

        expandedAdvancedSections[capability] = !(expandedAdvancedSections[capability] ?? false)
        buildUI()
        loadFormStateIntoFields()
    }
}
