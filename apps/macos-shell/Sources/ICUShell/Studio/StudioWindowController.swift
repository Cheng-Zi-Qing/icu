import AppKit

enum StudioLaunchTarget: String {
    case theme
    case avatarBrowse
    case avatarCreate
    case speech
}

final class StudioWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    private let avatars: [AvatarSummary]
    private let currentAvatarID: String?
    private let onClose: () -> Void

    private let sidebarView: StudioSidebarView
    private let contentContainer = AvatarPanelTheme.makeCard()
    private let themeContentView: ThemeStudioContentView
    private let avatarContentView: NSView
    private let speechContentView: SpeechStudioContentView
    private var sectionViews: [StudioLaunchTarget: NSView] = [:]
    private var didFinish = false

    private(set) var selectedTarget: StudioLaunchTarget

    init(
        avatars: [AvatarSummary],
        currentAvatarID: String?,
        initialTarget: StudioLaunchTarget = .theme,
        themePromptOptimizer: ((String) throws -> String)? = nil,
        themeDraftGenerator: ((String) throws -> ThemePack)? = nil,
        themeDraftApplier: ((ThemePack) throws -> Void)? = nil,
        speechDraftGenerator: ((String) throws -> SpeechDraft)? = nil,
        speechDraftApplier: ((SpeechDraft) throws -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.avatars = avatars
        self.currentAvatarID = currentAvatarID
        self.selectedTarget = StudioWindowController.normalized(initialTarget)
        self.onClose = onClose

        let currentAvatar = avatars.first(where: { $0.id == currentAvatarID }) ?? avatars.first
        self.themeContentView = ThemeStudioContentView(
            currentAvatar: currentAvatar,
            themePromptOptimizer: themePromptOptimizer,
            themeDraftGenerator: themeDraftGenerator,
            themeDraftApplier: themeDraftApplier
        )
        self.speechContentView = SpeechStudioContentView(
            currentAvatar: currentAvatar,
            speechDraftGenerator: speechDraftGenerator,
            speechDraftApplier: speechDraftApplier
        )
        self.avatarContentView = StudioWindowController.makeAvatarPlaceholderView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        AvatarPanelTheme.styleWindow(window)

        let normalizedInitialTarget = StudioWindowController.normalized(initialTarget)
        var didSelectTarget: ((StudioLaunchTarget) -> Void)?
        self.sidebarView = StudioSidebarView(initialTarget: normalizedInitialTarget) { target in
            didSelectTarget?(target)
        }

        super.init(window: window)
        window.delegate = self

        themeContentView.setTextViewDelegate(self)
        speechContentView.setTextViewDelegate(self)

        didSelectTarget = { [weak self] target in
            self?.setSelectedTarget(target)
        }

        buildUI()
        setSelectedTarget(normalizedInitialTarget)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(target: StudioLaunchTarget? = nil) {
        if let target {
            setSelectedTarget(target)
        }

        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else {
            return
        }

        switch textView.identifier?.rawValue {
        case "themeRawPrompt", "themeOptimizedPrompt":
            themeContentView.handleTextDidChange(textView)
        case "speechPrompt":
            speechContentView.handleTextDidChange(textView)
        default:
            break
        }
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
        sectionViews.removeAll()

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        let root = NSStackView()
        root.orientation = .horizontal
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        sidebarView.widthAnchor.constraint(equalToConstant: 140).isActive = true
        root.addArrangedSubview(sidebarView)
        root.addArrangedSubview(contentContainer)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])

        mountSection(themeContentView, for: .theme)
        mountSection(avatarContentView, for: .avatarBrowse)
        mountSection(speechContentView, for: .speech)
    }

    private func mountSection(_ view: NSView, for target: StudioLaunchTarget) {
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 16),
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -16),
        ])

        view.isHidden = true
        sectionViews[target] = view
    }

    private func setSelectedTarget(_ target: StudioLaunchTarget) {
        let normalizedTarget = StudioWindowController.normalized(target)
        selectedTarget = normalizedTarget
        for (sectionTarget, view) in sectionViews {
            view.isHidden = sectionTarget != normalizedTarget
        }
        sidebarView.select(normalizedTarget)
    }

    private static func normalized(_ target: StudioLaunchTarget) -> StudioLaunchTarget {
        switch target {
        case .avatarCreate:
            return .avatarBrowse
        case .theme, .avatarBrowse, .speech:
            return target
        }
    }

    private static func makeAvatarPlaceholderView() -> NSView {
        let view = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let titleLabel = AvatarPanelTheme.makeTitleLabel("当前分区：形象生成")
        let subtitleLabel = AvatarPanelTheme.makeLabel(
            "形象生成内容会在后续任务迁入独立 content view。",
            color: AvatarPanelTheme.muted
        )
        subtitleLabel.maximumNumberOfLines = 2

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        return view
    }
}
