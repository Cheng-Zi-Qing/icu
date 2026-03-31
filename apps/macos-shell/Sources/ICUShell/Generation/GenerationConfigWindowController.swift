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

final class GenerationConfigWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private struct CapabilityPanelState {
        var draft: GenerationCapabilityConfig
        var isExpanded: Bool
        var connectionStatus: ConnectionStatus
        var authToken: String
    }

    private struct CapabilityPanelViews {
        let toggleButton: NSButton
        let headerStatusLabel: NSTextField
        let contentContainer: NSView
        let providerPopUp: NSPopUpButton
        let modelField: NSTextField
        let baseURLField: NSTextField
        let authField: NSTextField
        let connectionButton: NSButton
        let connectionStatusLabel: NSTextField
    }

    private enum ConnectionStatus: Equatable {
        case idle
        case testing
        case success
        case failure(String)

        var text: String? {
            switch self {
            case .idle:
                return nil
            case .testing:
                return TextCatalog.shared.text(.generationConfigConnectionTestingStatus)
            case .success:
                return TextCatalog.shared.text(.generationConfigConnectionSuccessStatus)
            case let .failure(reason):
                return String(
                    format: TextCatalog.shared.text(.generationConfigConnectionFailureStatus),
                    reason
                )
            }
        }

        var color: NSColor {
            switch self {
            case .idle, .testing:
                return AvatarPanelTheme.muted
            case .success:
                return AvatarPanelTheme.accent
            case .failure:
                return AvatarPanelTheme.danger
            }
        }
    }

    private enum Layout {
        static let windowSize = NSSize(width: 804, height: 520)
        static let contentInset: CGFloat = 12
        static let rootSpacing: CGFloat = 10
        static let cardInset: CGFloat = 10
        static let fieldRowSpacing: CGFloat = 10
        static let labelSpacing: CGFloat = 4
        static let fieldHeight: CGFloat = 42
        static let buttonHeight: CGFloat = 32
        static let panelSpacing: CGFloat = 10
        static let panelContentSpacing: CGFloat = 10
    }

    private let settingsStore: GenerationSettingsStore
    private let themeManager: ThemeManager
    private let generationCoordinator: GenerationCoordinator
    private let onClose: () -> Void

    private(set) var formState: GenerationSettings

    private var panelStates: [GenerationCapabilityKind: CapabilityPanelState]
    private var panelViews: [GenerationCapabilityKind: CapabilityPanelViews] = [:]
    private var panelRequestIDs: [GenerationCapabilityKind: UUID] = [:]
    private var themeObserver: NSObjectProtocol?
    private var didCloseWindow = false

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
        self.panelStates = GenerationConfigWindowController.makePanelStates(from: self.formState)

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
        finishIfNeeded()
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else {
            return
        }

        updateState(from: field)
    }

    private func buildUI() {
        guard
            let window,
            let contentView = window.contentView
        else {
            return
        }

        AvatarPanelTheme.styleWindow(window)
        panelViews.removeAll()
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = Layout.rootSpacing
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        root.addArrangedSubview(buildHeader())
        root.addArrangedSubview(buildAccordionCard())
        root.addArrangedSubview(buildFooter())

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.contentInset),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.contentInset),
        ])
    }

    private func buildHeader() -> NSView {
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
        header.spacing = 2
        return header
    }

    private func buildAccordionCard() -> NSView {
        let card = AvatarPanelTheme.makeCard()
        card.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        AvatarPanelTheme.styleScrollView(scrollView)

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = Layout.panelSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)

        for kind in GenerationCapabilityKind.allCases {
            stack.addArrangedSubview(buildPanel(for: kind))
        }

        scrollView.documentView = documentView
        card.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: card.topAnchor, constant: Layout.cardInset),
            scrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Layout.cardInset),
            scrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Layout.cardInset),
            scrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Layout.cardInset),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        return card
    }

    private func buildPanel(for kind: GenerationCapabilityKind) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let toggleButton = NSButton(title: kind.title, target: self, action: #selector(handlePanelToggle(_:)))
        toggleButton.identifier = NSUserInterfaceItemIdentifier(toggleIdentifier(for: kind))
        toggleButton.alignment = .left
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.heightAnchor.constraint(equalToConstant: Layout.buttonHeight).isActive = true
        AvatarPanelTheme.styleSecondaryButton(toggleButton)

        let headerStatusLabel = AvatarPanelTheme.makeLabel(
            "",
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        headerStatusLabel.identifier = NSUserInterfaceItemIdentifier(headerStatusIdentifier(for: kind))

        let headerSpacer = NSView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let header = NSStackView(views: [toggleButton, headerSpacer, headerStatusLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        let contentCard = AvatarPanelTheme.makeCard()
        contentCard.identifier = NSUserInterfaceItemIdentifier(contentIdentifier(for: kind))
        contentCard.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = Layout.panelContentSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentCard.addSubview(contentStack)

        let descriptionLabel = AvatarPanelTheme.makeLabel(
            kind.detailDescription,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 0

        let providerPopUp = makeProviderPopUp(for: kind)
        let modelField = makeTextField(
            placeholder: TextCatalog.shared.text(.generationConfigModelPlaceholder),
            identifier: modelIdentifier(for: kind)
        )
        let baseURLField = makeTextField(
            placeholder: TextCatalog.shared.text(.generationConfigBaseURLPlaceholder),
            identifier: baseURLIdentifier(for: kind)
        )
        let authField = makeTextField(
            placeholder: TextCatalog.shared.text(.generationConfigAuthPlaceholder),
            identifier: authIdentifier(for: kind)
        )

        let connectionButton = NSButton(
            title: TextCatalog.shared.text(.generationConfigTestConnectionButton),
            target: self,
            action: #selector(handleConnectionTest(_:))
        )
        connectionButton.identifier = NSUserInterfaceItemIdentifier(connectionButtonIdentifier(for: kind))
        connectionButton.translatesAutoresizingMaskIntoConstraints = false
        connectionButton.heightAnchor.constraint(equalToConstant: Layout.buttonHeight).isActive = true
        AvatarPanelTheme.styleSecondaryButton(connectionButton)

        let connectionStatusLabel = AvatarPanelTheme.makeLabel(
            "",
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        connectionStatusLabel.identifier = NSUserInterfaceItemIdentifier(connectionStatusIdentifier(for: kind))
        connectionStatusLabel.lineBreakMode = .byWordWrapping
        connectionStatusLabel.maximumNumberOfLines = 0

        let connectionButtonSpacer = NSView()
        connectionButtonSpacer.translatesAutoresizingMaskIntoConstraints = false
        connectionButtonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let connectionRow = NSStackView(views: [connectionButtonSpacer, connectionButton])
        connectionRow.orientation = .horizontal
        connectionRow.alignment = .centerY
        connectionRow.spacing = 8

        contentStack.addArrangedSubview(descriptionLabel)
        contentStack.addArrangedSubview(makeFieldRow(label: TextCatalog.shared.text(.generationConfigProviderLabel), control: providerPopUp))
        contentStack.addArrangedSubview(makeFieldRow(label: TextCatalog.shared.text(.generationConfigModelLabel), control: modelField))
        contentStack.addArrangedSubview(makeFieldRow(label: TextCatalog.shared.text(.generationConfigBaseURLLabel), control: baseURLField))
        contentStack.addArrangedSubview(makeFieldRow(label: TextCatalog.shared.text(.generationConfigAuthLabel), control: authField))
        contentStack.addArrangedSubview(connectionRow)
        contentStack.addArrangedSubview(connectionStatusLabel)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentCard.topAnchor, constant: Layout.cardInset),
            contentStack.leadingAnchor.constraint(equalTo: contentCard.leadingAnchor, constant: Layout.cardInset),
            contentStack.trailingAnchor.constraint(equalTo: contentCard.trailingAnchor, constant: -Layout.cardInset),
            contentStack.bottomAnchor.constraint(equalTo: contentCard.bottomAnchor, constant: -Layout.cardInset),
        ])

        container.addArrangedSubview(header)
        container.addArrangedSubview(contentCard)

        panelViews[kind] = CapabilityPanelViews(
            toggleButton: toggleButton,
            headerStatusLabel: headerStatusLabel,
            contentContainer: contentCard,
            providerPopUp: providerPopUp,
            modelField: modelField,
            baseURLField: baseURLField,
            authField: authField,
            connectionButton: connectionButton,
            connectionStatusLabel: connectionStatusLabel
        )
        applyPanelStateToViews(for: kind)
        return container
    }

    private func buildFooter() -> NSView {
        let footer = NSStackView()
        footer.identifier = NSUserInterfaceItemIdentifier(footerIdentifier)
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let cancelButton = NSButton(
            title: TextCatalog.shared.text(.commonCancelButton),
            target: self,
            action: #selector(handleCancel)
        )
        AvatarPanelTheme.styleSecondaryButton(cancelButton)

        let saveButton = NSButton(
            title: TextCatalog.shared.text(.commonSaveButton),
            target: self,
            action: #selector(handleSave)
        )
        AvatarPanelTheme.stylePrimaryButton(saveButton)

        footer.addArrangedSubview(spacer)
        footer.addArrangedSubview(cancelButton)
        footer.addArrangedSubview(saveButton)
        return footer
    }

    private func makeFieldRow(label: String, control: NSView) -> NSView {
        let titleLabel = AvatarPanelTheme.makeLabel(
            label,
            color: AvatarPanelTheme.muted,
            font: AvatarPanelTheme.smallFont
        )
        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .vertical
        row.spacing = Layout.labelSpacing
        return row
    }

    private func makeTextField(placeholder: String, identifier: String) -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        field.identifier = NSUserInterfaceItemIdentifier(identifier)
        field.delegate = self
        AvatarPanelTheme.styleEditableTextField(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        return field
    }

    private func makeProviderPopUp(for kind: GenerationCapabilityKind) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.identifier = NSUserInterfaceItemIdentifier(providerIdentifier(for: kind))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: Layout.fieldHeight).isActive = true
        button.font = AvatarPanelTheme.bodyFont
        button.target = self
        button.action = #selector(handleProviderSelection(_:))
        button.removeAllItems()
        button.addItems(withTitles: kind.allowedProviders.map(\.rawValue))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    private func applyPanelStateToViews(for kind: GenerationCapabilityKind) {
        guard
            let state = panelStates[kind],
            let views = panelViews[kind]
        else {
            return
        }

        views.toggleButton.title = kind.title
        views.headerStatusLabel.stringValue = state.draft.isConfigured
            ? TextCatalog.shared.text(.generationConfigConfiguredStatus)
            : TextCatalog.shared.text(.generationConfigUnconfiguredStatus)
        views.headerStatusLabel.textColor = state.draft.isConfigured ? AvatarPanelTheme.accent : AvatarPanelTheme.muted

        views.contentContainer.isHidden = !state.isExpanded

        views.providerPopUp.selectItem(withTitle: state.draft.provider.rawValue)
        views.modelField.stringValue = state.draft.model
        views.baseURLField.stringValue = state.draft.baseURL
        views.authField.stringValue = state.authToken

        if let statusText = state.connectionStatus.text {
            views.connectionStatusLabel.isHidden = false
            views.connectionStatusLabel.stringValue = statusText
            views.connectionStatusLabel.textColor = state.connectionStatus.color
        } else {
            views.connectionStatusLabel.isHidden = true
            views.connectionStatusLabel.stringValue = ""
        }
    }

    private func syncAllPanelStatesFromControls() {
        for kind in GenerationCapabilityKind.allCases {
            syncPanelStateFromControls(for: kind)
        }
    }

    private func syncPanelStateFromControls(for kind: GenerationCapabilityKind) {
        guard
            var state = panelStates[kind],
            let views = panelViews[kind]
        else {
            return
        }

        let selectedProvider = GenerationCapabilityProvider(rawValue: views.providerPopUp.titleOfSelectedItem ?? "")
            ?? state.draft.provider

        state.draft = GenerationCapabilityConfig(
            provider: selectedProvider,
            baseURL: views.baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            model: views.modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            auth: GenerationCapabilityConfig.authDictionary(
                for: selectedProvider,
                token: views.authField.stringValue
            ),
            options: state.draft.options
        )
        state.authToken = views.authField.stringValue
        panelStates[kind] = state
        applyPanelStateToViews(for: kind)
    }

    private func resetConnectionStatus(for kind: GenerationCapabilityKind) {
        guard var state = panelStates[kind] else {
            return
        }
        state.connectionStatus = .idle
        panelStates[kind] = state
        applyPanelStateToViews(for: kind)
    }

    private func updateState(from field: NSTextField) {
        guard let identifier = field.identifier?.rawValue else {
            return
        }

        let components = identifier.split(separator: ".")
        guard components.count == 3, components[0] == "generationConfig" else {
            return
        }

        guard let kind = GenerationCapabilityKind(rawValue: String(components[2])) else {
            return
        }

        syncPanelStateFromControls(for: kind)
        resetConnectionStatus(for: kind)
    }

    private func persistDraftState() throws -> GenerationSettings {
        syncAllPanelStatesFromControls()
        let updatedSettings = formState.applyingVisibleDrafts(
            textDescription: makeVisibleDraft(for: .textDescription),
            animationAvatar: makeVisibleDraft(for: .animationAvatar),
            codeGeneration: makeVisibleDraft(for: .codeGeneration)
        )
        try settingsStore.save(updatedSettings)
        formState = updatedSettings
        return updatedSettings
    }

    private func makeVisibleDraft(for kind: GenerationCapabilityKind) -> GenerationCapabilityVisibleDraft {
        let state = panelStates[kind] ?? CapabilityPanelState(
            draft: config(for: kind, in: formState),
            isExpanded: kind == .textDescription,
            connectionStatus: .idle,
            authToken: config(for: kind, in: formState).visibleAuthToken
        )

        return GenerationCapabilityVisibleDraft(
            provider: state.draft.provider,
            baseURL: state.draft.baseURL,
            model: state.draft.model,
            authToken: state.authToken
        )
    }

    private func config(for kind: GenerationCapabilityKind, in settings: GenerationSettings) -> GenerationCapabilityConfig {
        switch kind {
        case .textDescription:
            return settings.textDescription
        case .animationAvatar:
            return settings.animationAvatar
        case .codeGeneration:
            return settings.codeGeneration
        }
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

            self.syncAllPanelStatesFromControls()
            self.buildUI()
        }
    }

    private func finishIfNeeded() {
        guard !didCloseWindow else {
            return
        }
        didCloseWindow = true
        onClose()
    }

    private func closeWindow() {
        window?.close()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window ?? NSWindow())
    }

    private func applyConnectionResult(
        _ result: Result<Void, Error>,
        for kind: GenerationCapabilityKind
    ) {
        guard var state = panelStates[kind] else {
            return
        }

        switch result {
        case .success:
            state.connectionStatus = .success
        case let .failure(error):
            state.connectionStatus = .failure(error.localizedDescription)
        }

        panelStates[kind] = state
        applyPanelStateToViews(for: kind)
    }

    @objc private func handlePanelToggle(_ sender: NSButton) {
        guard
            let rawValue = sender.identifier?.rawValue.replacingOccurrences(of: "generationConfig.toggle.", with: ""),
            let kind = GenerationCapabilityKind(rawValue: rawValue),
            var state = panelStates[kind]
        else {
            return
        }

        syncPanelStateFromControls(for: kind)
        state = panelStates[kind] ?? state
        state.isExpanded.toggle()
        panelStates[kind] = state
        applyPanelStateToViews(for: kind)
    }

    @objc private func handleProviderSelection(_ sender: NSPopUpButton) {
        guard
            let identifier = sender.identifier?.rawValue,
            let kind = GenerationCapabilityKind(rawValue: identifier.replacingOccurrences(of: "generationConfig.provider.", with: ""))
        else {
            return
        }

        syncPanelStateFromControls(for: kind)
        resetConnectionStatus(for: kind)
    }

    @objc private func handleConnectionTest(_ sender: NSButton) {
        guard
            let rawValue = sender.identifier?.rawValue.replacingOccurrences(of: "generationConfig.connectionButton.", with: ""),
            let kind = GenerationCapabilityKind(rawValue: rawValue),
            var state = panelStates[kind]
        else {
            return
        }

        syncPanelStateFromControls(for: kind)
        state = panelStates[kind] ?? state
        state.connectionStatus = .testing
        panelStates[kind] = state
        applyPanelStateToViews(for: kind)

        let capabilityDraft = state.draft
        let requestID = UUID()
        panelRequestIDs[kind] = requestID

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<Void, Error>
            do {
                guard let self else {
                    return
                }
                try self.generationCoordinator.testConnection(capabilityDraft)
                result = .success(())
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.panelRequestIDs[kind] == requestID
                else {
                    return
                }

                self.applyConnectionResult(result, for: kind)
            }
        }
    }

    @objc private func handleCancel() {
        panelStates = Self.makePanelStates(from: formState)
        panelRequestIDs.removeAll()
        closeWindow()
    }

    @objc private func handleSave() {
        do {
            _ = try persistDraftState()
            closeWindow()
        } catch {
            showError(error)
        }
    }

    private static func makePanelStates(from settings: GenerationSettings) -> [GenerationCapabilityKind: CapabilityPanelState] {
        Dictionary(
            uniqueKeysWithValues: GenerationCapabilityKind.allCases.map { kind in
                let draft: GenerationCapabilityConfig
                let isExpanded = kind == .textDescription

                switch kind {
                case .textDescription:
                    draft = settings.textDescription
                case .animationAvatar:
                    draft = settings.animationAvatar
                case .codeGeneration:
                    draft = settings.codeGeneration
                }

                return (
                    kind,
                    CapabilityPanelState(
                        draft: draft,
                        isExpanded: isExpanded,
                        connectionStatus: .idle,
                        authToken: draft.visibleAuthToken
                    )
                )
            }
        )
    }

    private func toggleIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.toggle.\(kind.rawValue)"
    }

    private func headerStatusIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.headerStatus.\(kind.rawValue)"
    }

    private func contentIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.content.\(kind.rawValue)"
    }

    private func providerIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.provider.\(kind.rawValue)"
    }

    private func modelIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.model.\(kind.rawValue)"
    }

    private func baseURLIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.baseURL.\(kind.rawValue)"
    }

    private func authIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.auth.\(kind.rawValue)"
    }

    private func connectionButtonIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.connectionButton.\(kind.rawValue)"
    }

    private func connectionStatusIdentifier(for kind: GenerationCapabilityKind) -> String {
        "generationConfig.connectionStatus.\(kind.rawValue)"
    }

    private var footerIdentifier: String {
        "generationConfig.footer"
    }
}
