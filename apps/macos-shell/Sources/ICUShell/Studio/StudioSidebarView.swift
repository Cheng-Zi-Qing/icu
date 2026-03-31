import AppKit

final class StudioSidebarView: NSView {
    private let onSelect: (StudioLaunchTarget) -> Void
    private var buttons: [StudioLaunchTarget: NSButton] = [:]
    private(set) var selectedTarget: StudioLaunchTarget

    init(
        initialTarget: StudioLaunchTarget = .theme,
        onSelect: @escaping (StudioLaunchTarget) -> Void
    ) {
        self.selectedTarget = initialTarget
        self.onSelect = onSelect
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildUI()
        updateSelectionStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func select(_ target: StudioLaunchTarget, notify: Bool = false) {
        selectedTarget = target
        updateSelectionStyles()
        if notify {
            onSelect(target)
        }
    }

    private func buildUI() {
        let container = AvatarPanelTheme.makeCard()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let entries: [(StudioLaunchTarget, String)] = [
            (.theme, "主题风格"),
            (.avatarBrowse, "形象生成"),
            (.speech, "话术"),
        ]

        for (target, title) in entries {
            let button = NSButton(title: title, target: self, action: #selector(handleSelection(_:)))
            button.identifier = NSUserInterfaceItemIdentifier("studio.sidebar.\(target.rawValue)")
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 112).isActive = true
            buttons[target] = button
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -14),
        ])
    }

    private func updateSelectionStyles() {
        for (target, button) in buttons {
            if target == selectedTarget {
                AvatarPanelTheme.stylePrimaryButton(button)
            } else {
                AvatarPanelTheme.styleSecondaryButton(button)
            }
        }
    }

    @objc private func handleSelection(_ sender: NSButton) {
        guard
            let target = buttons.first(where: { $0.value === sender })?.key
        else {
            return
        }

        select(target, notify: true)
    }
}
