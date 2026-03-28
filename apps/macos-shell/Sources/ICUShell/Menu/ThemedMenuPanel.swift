import AppKit

struct ThemedMenuPanelItem: Equatable {
    enum Tone: Equatable {
        case standard
        case destructive
    }

    var id: String
    var title: String
    var tone: Tone = .standard
}

struct ThemedMenuPanelSection: Equatable {
    var items: [ThemedMenuPanelItem]
}

final class ThemedMenuPanel: NSView {
    private enum Layout {
        static let panelWidth: CGFloat = 172
        static let outerPadding: CGFloat = 10
        static let rootSpacing: CGFloat = 4
        static let sectionRowSpacing: CGFloat = 3
        static let rowHeight: CGFloat = 26
        static let separatorHeight: CGFloat = 1
    }

    private let sections: [ThemedMenuPanelSection]
    private let onSelect: (String) -> Void
    private let rootStack = NSStackView()

    init(
        sections: [ThemedMenuPanelSection],
        onSelect: @escaping (String) -> Void
    ) {
        self.sections = sections
        self.onSelect = onSelect
        let size = Self.preferredSize(for: sections)
        super.init(frame: NSRect(origin: .zero, size: size))
        translatesAutoresizingMaskIntoConstraints = false
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func preferredSize(for sections: [ThemedMenuPanelSection]) -> NSSize {
        let rowCount = sections.reduce(0) { $0 + $1.items.count }
        let separatorCount = max(sections.count - 1, 0)
        let internalRowGapCount = sections.reduce(0) { partialResult, section in
            partialResult + max(section.items.count - 1, 0)
        }
        let arrangedSubviewGapCount = separatorCount * 2
        let height =
            (Layout.outerPadding * 2) +
            (CGFloat(rowCount) * Layout.rowHeight) +
            (CGFloat(internalRowGapCount) * Layout.sectionRowSpacing) +
            (CGFloat(arrangedSubviewGapCount) * Layout.rootSpacing) +
            (CGFloat(separatorCount) * Layout.separatorHeight)
        return NSSize(width: Layout.panelWidth, height: height)
    }

    private func buildUI() {
        let theme = ThemeManager.shared.currentTheme

        wantsLayer = true
        layer?.backgroundColor = ThemedComponents.color(theme.tokens.colors.menuBackgroundHex, fallback: .controlBackgroundColor).cgColor
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor

        rootStack.orientation = .vertical
        rootStack.spacing = Layout.rootSpacing
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        for (sectionIndex, section) in sections.enumerated() {
            let sectionStack = NSStackView()
            sectionStack.orientation = .vertical
            sectionStack.spacing = Layout.sectionRowSpacing

            for item in section.items {
                let button = MenuRowButton(item: item)
                button.target = self
                button.action = #selector(handleSelect(_:))
                button.translatesAutoresizingMaskIntoConstraints = false
                button.heightAnchor.constraint(equalToConstant: Layout.rowHeight).isActive = true
                applyTheme(theme, to: button, item: item)
                sectionStack.addArrangedSubview(button)
            }

            rootStack.addArrangedSubview(sectionStack)

            if sectionIndex < sections.count - 1 {
                rootStack.addArrangedSubview(makeSeparator(theme: theme))
            }
        }

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.outerPadding),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.outerPadding),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.outerPadding),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.outerPadding),
            widthAnchor.constraint(equalToConstant: Self.preferredSize(for: sections).width),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.preferredSize(for: sections).height),
        ])
    }

    private func applyTheme(_ theme: ThemeDefinition, to button: MenuRowButton, item: ThemedMenuPanelItem) {
        button.font = ThemedComponents.menuItemFont(theme)
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.alignment = .left
        button.contentTintColor = item.tone == .destructive
            ? ThemedComponents.labelColor(theme: theme, tone: .danger)
            : ThemedComponents.labelColor(theme: theme, tone: .primary)
        button.hoverColor = ThemedComponents.color(
            theme.components.menuRow.hoverBackgroundHex,
            fallback: ThemedComponents.color(theme.tokens.colors.cardBackgroundHex, fallback: .selectedContentBackgroundColor)
        )
        button.layer?.cornerRadius = 6
    }

    private func makeSeparator(theme: ThemeDefinition) -> NSView {
        let separator = NSView()
        separator.identifier = NSUserInterfaceItemIdentifier("menu-separator")
        separator.wantsLayer = true
        separator.layer?.backgroundColor = ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: Layout.separatorHeight).isActive = true
        return separator
    }

    @objc private func handleSelect(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else {
            return
        }

        onSelect(id)
    }
}

private final class MenuRowButton: NSButton {
    let item: ThemedMenuPanelItem
    var hoverColor: NSColor = .clear
    private var trackingAreaRef: NSTrackingArea?

    init(item: ThemedMenuPanelItem) {
        self.item = item
        super.init(frame: .zero)
        title = item.title
        identifier = NSUserInterfaceItemIdentifier(item.id)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = hoverColor.cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
