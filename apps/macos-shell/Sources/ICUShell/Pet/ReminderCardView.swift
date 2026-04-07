import AppKit

final class ReminderCardView: NSView {
    private let messageLabel = NSTextField(labelWithString: "")
    private let completeButton = NSButton(title: "", target: nil, action: nil)
    private let snoozeButton = NSButton(title: "", target: nil, action: nil)
    private let skipButton = NSButton(title: "", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with payload: ReminderPresentationPayload) {
        messageLabel.stringValue = payload.text
        completeButton.title = DesktopPetCopy.reminderCompleteActionTitle()
        snoozeButton.title = DesktopPetCopy.reminderSnoozeActionTitle()
        skipButton.title = DesktopPetCopy.reminderSkipActionTitle()
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
    }

    private func setup() {
        wantsLayer = true

        messageLabel.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.message")
        messageLabel.alignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 2
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        completeButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.complete")
        completeButton.bezelStyle = .rounded
        completeButton.translatesAutoresizingMaskIntoConstraints = false

        snoozeButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.snooze")
        snoozeButton.bezelStyle = .rounded
        snoozeButton.translatesAutoresizingMaskIntoConstraints = false

        skipButton.identifier = NSUserInterfaceItemIdentifier("desktopPet.reminderCard.skip")
        skipButton.bezelStyle = .rounded
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
    }
}
