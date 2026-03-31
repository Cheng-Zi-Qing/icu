import AppKit

enum StudioLaunchTarget: String {
    case theme
    case avatarBrowse
    case avatarCreate
    case speech
}

final class StudioWindowController: NSWindowController, NSWindowDelegate {
    private let avatars: [AvatarSummary]
    private let currentAvatarID: String?
    private let onClose: () -> Void

    private let sidebarView: StudioSidebarView
    private let contentContainer = AvatarPanelTheme.makeCard()
    private var sectionViews: [StudioLaunchTarget: NSView] = [:]
    private var sectionTitleLabels: [StudioLaunchTarget: NSTextField] = [:]
    private var didFinish = false

    private(set) var selectedTarget: StudioLaunchTarget

    init(
        avatars: [AvatarSummary],
        currentAvatarID: String?,
        initialTarget: StudioLaunchTarget = .theme,
        onClose: @escaping () -> Void
    ) {
        self.avatars = avatars
        self.currentAvatarID = currentAvatarID
        self.selectedTarget = initialTarget
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        AvatarPanelTheme.styleWindow(window)

        var didSelectTarget: ((StudioLaunchTarget) -> Void)?
        self.sidebarView = StudioSidebarView(initialTarget: initialTarget) { target in
            didSelectTarget?(target)
        }

        super.init(window: window)
        window.delegate = self

        didSelectTarget = { [weak self] target in
            self?.setSelectedTarget(target)
        }
        buildUI()
        setSelectedTarget(initialTarget)

        // Keep the shell inputs referenced so future feature work can build from this contract.
        _ = avatars
        _ = currentAvatarID
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
        sectionTitleLabels.removeAll()

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

        mountSection(.theme, title: "主题风格")
        mountSection(.avatarBrowse, title: "形象生成")
        mountSection(.speech, title: "话术")
    }

    private func mountSection(_ target: StudioLaunchTarget, title: String) {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 16),
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -16),
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let titleLabel = AvatarPanelTheme.makeTitleLabel("当前分区：\(title)")
        let subtitleLabel = AvatarPanelTheme.makeLabel(
            "此分区在 Task 1 只提供稳定壳层，后续任务补齐完整流程。",
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

        sectionViews[target] = view
        sectionTitleLabels[target] = titleLabel
        view.isHidden = true
    }

    private func setSelectedTarget(_ target: StudioLaunchTarget) {
        let normalizedTarget = normalized(target)
        selectedTarget = normalizedTarget
        for (sectionTarget, view) in sectionViews {
            view.isHidden = sectionTarget != normalizedTarget
        }
        sidebarView.select(normalizedTarget)
    }

    private func normalized(_ target: StudioLaunchTarget) -> StudioLaunchTarget {
        switch target {
        case .avatarCreate:
            return .avatarBrowse
        case .theme, .avatarBrowse, .speech:
            return target
        }
    }
}
