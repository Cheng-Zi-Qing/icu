import AppKit

func testReminderCardRendersCompleteSnoozeAndSkipActions() throws {
    _ = try makeInstalledThemeManager()
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")
    view.showReminderCard(payload)

    let completeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.complete")
    let snoozeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.snooze")
    let skipButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.skip")

    let content = try requireReminderCard(in: view).content
    try expect(content != nil, "the card should keep what it shows")
    try expect(completeButton.title == content?.completeTitle, "complete button shows the picked quip")
    try expect(snoozeButton.title == content?.snoozeTitle, "snooze button shows the picked quip")
    try expect(skipButton.title == content?.skipTitle, "skip is a visible 我就不-style button")
    try expect(ReminderQuips.lookAway.lines.contains(content?.title ?? ""), "a 20 second break picks a look-away line")
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

func testReminderCardEnablesAndDispatchesActionsWhenCallbackProvided() throws {
    _ = try makeInstalledThemeManager()
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")
    var receivedOutcomes: [HealthReminderOutcome] = []

    view.showReminderCard(payload) { outcome in
        receivedOutcomes.append(outcome)
    }

    let completeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.complete")
    let snoozeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.snooze")
    let skipButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.skip")

    try expect(completeButton.isEnabled, "complete action should enable when callback is provided")
    try expect(snoozeButton.isEnabled, "snooze action should enable when callback is provided")
    try expect(skipButton.isEnabled, "skip action should enable when callback is provided")

    completeButton.performClick(nil)
    snoozeButton.performClick(nil)
    skipButton.performClick(nil)

    try expect(
        receivedOutcomes == [.completed, .snoozed, .skipped],
        "reminder card should forward each button tap to the matching outcome callback"
    )
}

func testReminderCardButtonsWinHitTestingOverTransparentPetPixels() throws {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")

    view.showReminderCard(payload) { _ in }
    view.layoutSubtreeIfNeeded()

    let snoozeButton = try requireButton(in: view, identifier: "desktopPet.reminderCard.snooze")
    let pointInsideButtonNearTrailingEdge = NSPoint(
        x: snoozeButton.frame.maxX - 4,
        y: snoozeButton.frame.midY
    )
    let hitPoint = view.convert(pointInsideButtonNearTrailingEdge, from: snoozeButton.superview)
    let hitView = view.hitTest(hitPoint)

    let actualDescription = hitView.map { "\($0.identifier?.rawValue ?? String(describing: type(of: $0)))" } ?? "nil"
    try expect(
        hitView === snoozeButton,
        "reminder buttons should stay clickable even above transparent pet pixels (got \(actualDescription))"
    )
}

func testReminderCardBodyWinsHitTestingOverTransparentPetPixels() throws {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let view = DesktopPetView(
        frame: NSRect(x: 0, y: 0, width: 128, height: 128),
        assetLocator: PetAssetLocator(appPaths: appPaths),
        petID: "missing_pet"
    )
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "看看远处，护护眼。")

    view.showReminderCard(payload) { _ in }
    view.layoutSubtreeIfNeeded()

    let reminderCard = try requireView(in: view, identifier: "desktopPet.reminderCard")
    // 卡片里标题那一块（不是按钮）
    let pointInsideTitle = NSPoint(x: 40, y: 14)
    let hitPoint = view.convert(pointInsideTitle, from: reminderCard)
    let hitView = view.hitTest(hitPoint)

    try expect(
        hitView === reminderCard,
        "reminder body clicks should stay on the reminder card instead of falling through to the transparent desktop"
    )
}

func testReminderCardAcceptsFirstMouseWhenWindowIsInactive() throws {
    let reminderCard = ReminderCardView(frame: NSRect(x: 0, y: 0, width: 120, height: 108))

    try expect(
        reminderCard.acceptsFirstMouse(for: nil),
        "reminder card should accept the first click so the desktop prompt works while the app is inactive"
    )
}

@MainActor
func testReminderCompleteAndSkipLogExpectedOutcomes() throws {
    let harness = try makeHealthFlowHarness()
    defer { harness.controller.close() }

    let completePayload = ReminderPresentationPayload(
        id: UUID(uuidString: "aaaaaaaa-1111-1111-1111-111111111111")!,
        type: .eyeCare,
        text: "看看远处，护护眼。"
    )
    let skipPayload = ReminderPresentationPayload(
        id: UUID(uuidString: "bbbbbbbb-2222-2222-2222-222222222222")!,
        type: .eyeCare,
        text: "起来活动一下。"
    )

    harness.controller.presentReminder(payload: completePayload)
    try requireButton(in: harness.window.contentView!, identifier: "desktopPet.reminderCard.complete").performClick(nil)

    harness.controller.presentReminder(payload: skipPayload)
    try requireButton(in: harness.window.contentView!, identifier: "desktopPet.reminderCard.skip").performClick(nil)

    let summary = try harness.store.daySummary(for: harness.probe.now)
    try expect(summary.eyeReminder.shown == 2, "manual reminder presentations should record shown events")
    try expect(summary.eyeReminder.completed == 1, "complete action should persist a completed outcome")
    try expect(summary.eyeReminder.skipped == 1, "skip action should persist a skipped outcome")
    try expect(summary.eyeReminder.snoozed == 0, "complete and skip should not increment snoozed counts")
}

@MainActor
func testReminderPresentationExpandsWindowAndKeepsCardAbovePetCanvas() throws {
    let harness = try makeHealthFlowHarness()
    defer { harness.controller.close() }

    let payload = ReminderPresentationPayload(
        id: UUID(uuidString: "dddddddd-4444-4444-4444-444444444444")!,
        type: .eyeCare,
        text: "看看远处，护护眼。"
    )

    harness.controller.presentReminder(payload: payload)

    let contentView = try requireWindowContentView(of: harness.controller)
    let reminderCard = try requireView(in: contentView, identifier: "desktopPet.reminderCard")

    try expect(
        harness.window.frame.height > DesktopPetView.compactContentSize.height,
        "presenting a reminder should expand the window so the prompt does not stack on top of the pet"
    )
    try expect(
        reminderCard.frame.minY >= DesktopPetView.compactContentSize.height,
        "expanded reminder layout should place the card above the 128pt pet canvas instead of covering it (got card \(reminderCard.frame), window \(harness.window.frame), content \(contentView.bounds))"
    )
}

@MainActor
func testWorkStateBubbleExpandsWindowAndKeepsBubbleAbovePetCanvas() throws {
    let harness = try makeHealthFlowHarness()
    defer { harness.controller.close() }

    harness.window.actionHandler?(.startWork)
    harness.window.contentView?.layoutSubtreeIfNeeded()

    let contentView = try requireWindowContentView(of: harness.controller)
    let bubbleContainer = try requireView(in: contentView, identifier: "desktopPet.transientBubbleContainer")

    try expect(
        harness.window.frame.height > DesktopPetView.compactContentSize.height,
        "showing the work-state prompt should expand the window instead of drawing over the pet"
    )
    try expect(
        !bubbleContainer.isHidden,
        "work-state prompt should keep the transient bubble visible"
    )
    try expect(
        bubbleContainer.frame.minY >= DesktopPetView.compactContentSize.height,
        "expanded work-state prompt should sit above the 128pt pet canvas instead of covering it"
    )
}

@MainActor
func testReminderSnoozeSchedulesFreshFollowUpAndLogsOutcomes() throws {
    let harness = try makeHealthFlowHarness()
    defer { harness.controller.close() }

    let originalPayload = ReminderPresentationPayload(
        id: UUID(uuidString: "cccccccc-3333-3333-3333-333333333333")!,
        type: .eyeCare,
        text: "看看远处，护护眼。"
    )

    harness.controller.presentReminder(payload: originalPayload)
    try requireButton(in: harness.window.contentView!, identifier: "desktopPet.reminderCard.snooze").performClick(nil)

    let receivedFollowUp = waitForCondition(timeout: 0.6) {
        harness.probe.deliveredReminderPayloads.count == 1
    }
    try expect(receivedFollowUp, "snooze action should request a follow-up reminder")

    guard let followUpPayload = harness.probe.deliveredReminderPayloads.first else {
        throw TestFailure(message: "expected snooze follow-up payload to exist")
    }

    try expect(followUpPayload.id != originalPayload.id, "snooze follow-up should use a fresh reminder id")

    harness.probe.now = harness.probe.now.addingTimeInterval(300)
    try requireButton(in: harness.window.contentView!, identifier: "desktopPet.reminderCard.complete").performClick(nil)

    let summary = try harness.store.daySummary(for: harness.probe.now)
    try expect(summary.eyeReminder.shown == 2, "original reminder and follow-up should both count as shown")
    try expect(summary.eyeReminder.snoozed == 1, "snooze action should persist the snoozed outcome once")
    try expect(summary.eyeReminder.completed == 1, "follow-up completion should persist separately from the snooze")
}

func testReminderCardFitsInsideThePetWindowWidth() throws {
    _ = try makeInstalledThemeManager()
    let view = DesktopPetView(frame: NSRect(origin: .zero, size: DesktopPetView.reminderExpandedContentSize))
    view.showReminderCard(ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x"))
    view.layoutSubtreeIfNeeded()

    let card = try requireView(in: view, identifier: "desktopPet.reminderCard")
    try expect(card.frame.minX >= 0 && card.frame.maxX <= view.bounds.width, "the card should not be clipped by the 128pt window (got \(card.frame))")
    try expect(card.frame.maxY <= view.bounds.height, "the card should fit under the window top (got \(card.frame))")
    for identifier in ["complete", "snooze", "skip"] {
        let button = try requireButton(in: view, identifier: "desktopPet.reminderCard.\(identifier)")
        try expect(card.bounds.contains(button.frame), "\(identifier) button should sit inside the card (got \(button.frame))")
    }
}

func testHydrationReminderCardShowsWhichCupThisIs() throws {
    _ = try makeInstalledThemeManager()
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    let payload = ReminderPresentationPayload(id: UUID(), type: .hydration, text: "喝口水，慢慢来。")
    view.showReminderCard(payload, cups: CupProgress(done: 3, goal: 6)) { _ in }

    let card = try requireReminderCard(in: view)
    try expect(ReminderQuips.hydration.lines.contains(card.content?.title ?? ""), "water card picks a water line (got \(String(describing: card.content?.title)))")
    try expect(card.detailText == "第 4/6 杯", "water card should say which cup this is (got \(card.detailText))")
    let complete = try requireButton(in: view, identifier: "desktopPet.reminderCard.complete")
    try expect(ReminderQuips.hydration.done.contains(complete.title ?? ""), "water is confirmed with a drinking quip")
    try expect(card.remainingSegments == 0, "water cards have no countdown bar")
}

func testEyeReminderCardCountsDownAndCompletesOnce() throws {
    _ = try makeInstalledThemeManager()
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128))
    var outcomes: [HealthReminderOutcome] = []
    let payload = ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 20)
    view.showReminderCard(payload) { outcomes.append($0) }

    let card = try requireReminderCard(in: view)
    try expect(card.detailText == "还剩 20 秒" && card.remainingSegments == 10, "starts full (got \(card.detailText))")
    card.advanceCountdown(by: 6)
    try expect(card.detailText == "还剩 14 秒" && card.remainingSegments == 7, "ticks down (got \(card.detailText), \(card.remainingSegments))")
    card.advanceCountdown(by: 14)
    card.advanceCountdown(by: 1)
    try expect(outcomes == [.completed], "finishing the countdown completes the reminder exactly once (got \(outcomes))")
}

/// 每句俏皮话放进卡片都不会被截掉：标题行、按钮、「我就不」、还有最长的说明
func testReminderQuipsFitTheirSlotsOnTheCard() throws {
    let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    PixelFont.register(assetsDirectory: repoRoot.appendingPathComponent("assets"))
    try expect(PixelFont.isAvailable, "measure with the real pixel font (repo root \(repoRoot.path))")
    let font = PixelFont.font()
    func width(_ text: String) -> CGFloat { PixelPaint.textSize(text, font: font).width }
    let cardWidth: CGFloat = DesktopPetView.reminderExpandedContentSize.width - 4
    let titleRoom = cardWidth - 8 * 2 - PixelPaint.iconSize(.eye).width - 4
    let pools = [ReminderQuips.hydration, ReminderQuips.lookAway, ReminderQuips.standUp]
    for line in pools.flatMap(\.lines) {
        try expect(width(line) <= titleRoom, "'\(line)' is \(width(line))pt, title room is \(titleRoom)pt")
    }
    let buttonRoom = ((cardWidth - 16 - 4) / 2) - 8
    for title in pools.flatMap(\.done) + ReminderQuips.later {
        try expect(width(title) <= buttonRoom, "button '\(title)' is \(width(title))pt, room is \(buttonRoom)pt")
    }
    let skipRoom: CGFloat = 44
    let detailRoom = cardWidth - 6 - skipRoom - 8
    for title in ReminderQuips.nope {
        try expect(width(title) <= skipRoom, "skip '\(title)' is \(width(title))pt")
    }
    for detail in ["还剩 20 秒", "还剩 4:59", "第 14/14 杯", "超额 3 杯", "小口慢慢喝"] {
        try expect(width(detail) <= detailRoom, "detail '\(detail)' is \(width(detail))pt, room is \(detailRoom)pt")
    }
}

private func requireReminderCard(in root: NSView) throws -> ReminderCardView {
    guard let card = allSubviews(in: root).compactMap({ $0 as? ReminderCardView }).first else {
        throw TestFailure(message: "expected a reminder card")
    }
    return card
}

private func requireButton(in root: NSView, identifier: String) throws -> PixelButton {
    if let button = allSubviews(in: root)
        .compactMap({ $0 as? PixelButton })
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

private func requireWindowContentView(of controller: NSWindowController) throws -> NSView {
    if let contentView = controller.window?.contentView {
        return contentView
    }

    throw TestFailure(message: "expected window content view to exist")
}

private func requireLabelContaining(in root: NSView, text: String) throws -> NSTextField {
    if let label = allSubviews(in: root)
        .compactMap({ $0 as? NSTextField })
        .first(where: { $0.stringValue.contains(text) }) {
        return label
    }

    throw TestFailure(message: "expected label containing '\(text)' to exist")
}

private final class HealthFlowTestProbe {
    var now = Date(timeIntervalSince1970: 1_744_100_000)
    var deliveredReminderPayloads: [ReminderPresentationPayload] = []
}

private struct HealthFlowHarness {
    let controller: DesktopPetWindowController
    let window: DesktopPetWindow
    let store: HealthMetricsStore
    let probe: HealthFlowTestProbe
}

@MainActor
private func makeHealthFlowHarness() throws -> HealthFlowHarness {
    _ = try makeInstalledThemeManager()
    let appPaths = try makeTemporaryAppPaths()
    let stateStore = try StateStore(paths: appPaths)
    let workSessionController = try WorkSessionController(store: stateStore)
    let healthStore = try HealthMetricsStore(appPaths: appPaths)
    let healthTracker = HealthSessionTracker(store: healthStore)
    let probe = HealthFlowTestProbe()
    let assetLocator = PetAssetLocator(appPaths: appPaths)

    var controller: DesktopPetWindowController?
    let scheduler = ReminderScheduler(
        eyeInterval: 999,
        snoozeInterval: 0.05,
        onReminder: { payload in
            probe.deliveredReminderPayloads.append(payload)
            controller?.presentReminder(payload: payload)
        }
    )

    let createdController = DesktopPetWindowController(
        workSessionController: workSessionController,
        reminderScheduler: scheduler,
        healthTracker: healthTracker,
        assetLocator: assetLocator,
        petID: "missing_pet",
        onQuitRequested: {},
        nowProvider: { probe.now }
    )
    controller = createdController

    guard let window = createdController.window as? DesktopPetWindow else {
        throw TestFailure(message: "expected desktop pet window to exist")
    }

    return HealthFlowHarness(
        controller: createdController,
        window: window,
        store: healthStore,
        probe: probe
    )
}
