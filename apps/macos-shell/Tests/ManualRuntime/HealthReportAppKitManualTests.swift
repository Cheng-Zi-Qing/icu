import AppKit

func testReminderCardRendersCompleteSnoozeAndSkipActions() throws {
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")
    view.showReminderCard(payload)

    let completeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.complete")
    let snoozeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.snooze")
    let skipButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.skip")

    try expect(
        completeButton.title == DesktopPetCopy.reminderCompleteActionTitle(),
        "reminder card should render the complete action title"
    )
    try expect(
        snoozeButton.title == DesktopPetCopy.reminderSnoozeActionTitle(),
        "reminder card should render the snooze action title"
    )
    try expect(
        skipButton.title == DesktopPetCopy.reminderSkipActionTitle(),
        "reminder card should render the skip action title"
    )
    try expect(!completeButton.isEnabled, "reminder complete action should stay disabled until callbacks are wired")
    try expect(!snoozeButton.isEnabled, "reminder snooze action should stay disabled until callbacks are wired")
    try expect(!skipButton.isEnabled, "reminder skip action should stay disabled until callbacks are wired")
}

func testReminderCardRelayoutsAfterBoundsChange() throws {
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")
    view.showReminderCard(payload)
    view.layoutSubtreeIfNeeded()

    let initialCard = try requireView(in: view, identifier: "desktopPet.reminderCard")
    let initialFrame = initialCard.frame

    view.setFrameSize(NSSize(width: 200, height: 180))
    view.layoutSubtreeIfNeeded()

    let resizedCard = try requireView(in: view, identifier: "desktopPet.reminderCard")
    try expect(initialFrame != resizedCard.frame, "reminder card frame should update when desktop pet bounds change")
}

func testReminderCardTooltipPersistsAcrossThemeChanges() throws {
    let manager = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    _ = manager
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")
    view.showReminderCard(payload)

    try expect(view.toolTip == payload.text, "test setup should set tooltip to reminder text")
    try ThemeManager.shared.apply(makeAppKitTestThemePack(id: "reminder_tooltip_refresh"))
    try expect(view.toolTip == payload.text, "theme changes should not reset reminder tooltip back to status text")
}

private func requireButton(in root: NSView, identifier: String) throws -> NSButton {
    if let button = allSubviews(in: root)
        .compactMap({ $0 as? NSButton })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return button
    }

    throw TestFailure(message: "expected button '\(identifier)' to exist")
}

private func requireView(in root: NSView, identifier: String) throws -> NSView {
    if let view = allSubviews(in: root).first(where: { $0.identifier?.rawValue == identifier }) {
        return view
    }

    throw TestFailure(message: "expected view '\(identifier)' to exist")
}
