import AppKit

final class ReminderCardView: NSView {
    private let messageLabel = NSTextField(labelWithString: "")
    private let completeButton = NSButton(title: "", target: nil, action: nil)
    private let snoozeButton = NSButton(title: "", target: nil, action: nil)
    private let skipButton = NSButton(title: "", target: nil, action: nil)
    var onAction: ((HealthReminderOutcome) -> Void)? {
        didSet {
            updateActionAvailability()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func configure(
        with payload: ReminderPresentationPayload,
        onAction: ((HealthReminderOutcome) -> Void)? = nil
    ) {
        messageLabel.stringValue = payload.text
        completeButton.title = DesktopPetCopy.reminderCompleteActionTitle()
        snoozeButton.title = DesktopPetCopy.reminderSnoozeActionTitle()
        skipButton.title = DesktopPetCopy.reminderSkipActionTitle()
        self.onAction = onAction
    }

    func applyTheme(_ theme: ThemeDefinition) {
        wantsLayer = true
        layer?.backgroundColor = ThemedComponents.color(
            theme.tokens.colors.overlayHex,
            fallback: .windowBackgroundColor
        ).withAlphaComponent(0.98).cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor).cgColor

        messageLabel.textColor = ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        messageLabel.font = ThemedComponents.statusFont(theme)

        let buttonTextColor = ThemedComponents.color(theme.tokens.colors.textPrimaryHex, fallback: .labelColor)
        let buttonFillColor = ThemedComponents.color(theme.tokens.colors.inputBackgroundHex, fallback: .controlBackgroundColor)
        let buttonBorderColor = ThemedComponents.color(theme.tokens.colors.borderHex, fallback: .separatorColor)
        for button in [completeButton, snoozeButton, skipButton] {
            button.contentTintColor = buttonTextColor
            button.wantsLayer = true
            button.isBordered = false
            button.layer?.backgroundColor = buttonFillColor.withAlphaComponent(0.5).cgColor
            button.layer?.borderWidth = 1
            button.layer?.borderColor = buttonBorderColor.cgColor
            button.layer?.cornerRadius = 6
            button.alphaValue = button.isEnabled ? 1 : 0.65
        }
    }

    private func setup() {
        wantsLayer = true

        messageLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.message")
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        completeButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.complete")
        completeButton.target = self
        completeButton.action = #selector(handleCompleteAction)
        completeButton.translatesAutoresizingMaskIntoConstraints = false

        snoozeButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.snooze")
        snoozeButton.target = self
        snoozeButton.action = #selector(handleSnoozeAction)
        snoozeButton.translatesAutoresizingMaskIntoConstraints = false

        skipButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.skip")
        skipButton.target = self
        skipButton.action = #selector(handleSkipAction)
        skipButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(messageLabel)
        addSubview(completeButton)
        addSubview(snoozeButton)
        addSubview(skipButton)

        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            completeButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            completeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            completeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            snoozeButton.topAnchor.constraint(equalTo: completeButton.bottomAnchor, constant: 6),
            snoozeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            snoozeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            skipButton.topAnchor.constraint(equalTo: snoozeButton.bottomAnchor, constant: 6),
            skipButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            skipButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        updateActionAvailability()
    }

    private func updateActionAvailability() {
        let isEnabled = onAction != nil
        for button in [completeButton, snoozeButton, skipButton] {
            button.isEnabled = isEnabled
            button.alphaValue = isEnabled ? 1 : 0.65
        }
    }

    func interactiveHitView(at point: NSPoint) -> NSView? {
        for button in [completeButton, snoozeButton, skipButton] {
            let buttonPoint = convert(point, to: button)
            if button.bounds.contains(buttonPoint) {
                return button
            }
        }

        return bounds.contains(point) ? self : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        interactiveHitView(at: point)
    }

    override func mouseDown(with event: NSEvent) {
        // Swallow card-body clicks so they do not fall back into window dragging.
    }

    override func mouseDragged(with event: NSEvent) {
        // Keep drag gestures inside the reminder card from moving the desktop pet.
    }

    @objc private func handleCompleteAction() {
        onAction?(.completed)
    }

    @objc private func handleSnoozeAction() {
        onAction?(.snoozed)
    }

    @objc private func handleSkipAction() {
        onAction?(.skipped)
    }
}
