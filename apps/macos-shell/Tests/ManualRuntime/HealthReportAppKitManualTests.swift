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

func testReminderCardEnablesAndDispatchesActionsWhenCallbackProvided() throws {
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
    let messageLabel = try requireView(in: view, identifier: "desktopPet.reminderCard.message")
    let pointInsideMessageLabel = NSPoint(x: messageLabel.frame.midX, y: messageLabel.frame.midY)
    let hitPoint = view.convert(pointInsideMessageLabel, from: messageLabel.superview)
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

func testHealthReportWindowSwitchesBetweenTodayAndWeekModes() throws {
    _ = try makeInstalledThemeManager()
    let controller = HealthReportWindowController(
        todaySummary: makeFixtureTodaySummary(),
        weekSummary: makeFixtureWeekSummary()
    )

    controller.showWindow(nil)

    let contentView = try requireWindowContentView(of: controller)
    _ = try requireLabel(in: contentView, stringValue: "今日")
    let segmentedControl = try requireSegmentedControl(in: contentView, identifier: "healthReport.modeControl")
    segmentedControl.setSelected(true, forSegment: 1)
    controller.handleModeChange(segmentedControl)

    _ = try requireLabel(in: contentView, stringValue: "本周")
    _ = try requireLabelContaining(in: contentView, text: "趋势")
}

func testHealthReportWindowUsesCompactFrame() throws {
    _ = try makeInstalledThemeManager()
    let controller = HealthReportWindowController(
        todaySummary: makeFixtureTodaySummary(),
        weekSummary: makeFixtureWeekSummary()
    )

    controller.showWindow(nil)

    guard let window = controller.window else {
        throw TestFailure(message: "expected health report window to exist")
    }

    try expect(window.frame.width <= 360, "health report window should stay compact enough for laptop screens")
    try expect(window.frame.height <= 320, "health report window should stay short enough for laptop screens")
}

func testHealthReportWindowUsesTodayAccumulationTitle() throws {
    _ = try makeInstalledThemeManager()
    let controller = HealthReportWindowController(
        todaySummary: makeFixtureTodaySummary(),
        weekSummary: makeFixtureWeekSummary()
    )

    controller.showWindow(nil)

    let contentView = try requireWindowContentView(of: controller)
    _ = try requireLabel(in: contentView, stringValue: "今日累计")
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
        "expanded reminder layout should place the card above the 128pt pet canvas instead of covering it"
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

@MainActor
func testStopWorkPresentsHealthReportWhenMeaningfulDataExists() throws {
    let harness = try makeHealthFlowHarness()
    defer { harness.controller.close() }

    harness.window.actionHandler?(.startWork)
    harness.probe.now = harness.probe.now.addingTimeInterval(600)
    harness.window.actionHandler?(.stopWork)

    try expect(harness.probe.presentedReports.count == 1, "stop work should auto-present the health report when activity exists")

    guard let report = harness.probe.presentedReports.first else {
        throw TestFailure(message: "expected an auto-presented report payload")
    }

    try expect(report.today.workDuration == 600, "auto-presented report should include the settled daily work duration")
    try expect(report.week.workDuration == 600, "auto-presented week report should include the same session in weekly totals")
}

private func makeFixtureTodaySummary() -> HealthDaySummary {
    HealthDaySummary(
        date: Date(timeIntervalSince1970: 1_744_000_000),
        eyeReminder: HealthReminderCounts(shown: 3, completed: 2, snoozed: 1, skipped: 0),
        workDuration: 5_400,
        focusCount: 2,
        focusDuration: 2_700,
        breakCount: 1
    )
}

private func makeFixtureWeekSummary() -> HealthWeekSummary {
    let firstDay = makeFixtureTodaySummary()
    let secondDay = HealthDaySummary(
        date: firstDay.date.addingTimeInterval(86_400),
        eyeReminder: HealthReminderCounts(shown: 2, completed: 1, snoozed: 0, skipped: 1),
        workDuration: 1_800,
        focusCount: 1,
        focusDuration: 900,
        breakCount: 1
    )
    let emptyDays = (2..<7).map { offset in
        HealthDaySummary(
            date: firstDay.date.addingTimeInterval(TimeInterval(offset * 86_400)),
            eyeReminder: .empty,
            workDuration: 0,
            focusCount: 0,
            focusDuration: 0,
            breakCount: 0
        )
    }

    return HealthWeekSummary(
        weekStartDate: firstDay.date,
        weekEndExclusiveDate: firstDay.date.addingTimeInterval(7 * 86_400),
        eyeReminder: HealthReminderCounts(shown: 5, completed: 3, snoozed: 1, skipped: 1),
        eyeReminderCompletionRate: 0.6,
        workDuration: 7_200,
        focusCount: 3,
        focusDuration: 3_600,
        breakCount: 2,
        days: [firstDay, secondDay] + emptyDays
    )
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

private func requireWindowContentView(of controller: NSWindowController) throws -> NSView {
    if let contentView = controller.window?.contentView {
        return contentView
    }

    throw TestFailure(message: "expected window content view to exist")
}

private func requireSegmentedControl(in root: NSView, identifier: String) throws -> NSSegmentedControl {
    if let control = allSubviews(in: root)
        .compactMap({ $0 as? NSSegmentedControl })
        .first(where: { $0.identifier?.rawValue == identifier }) {
        return control
    }

    throw TestFailure(message: "expected segmented control '\(identifier)' to exist")
}

private func requireLabelContaining(in root: NSView, text: String) throws -> NSTextField {
    if let label = allSubviews(in: root)
        .compactMap({ $0 as? NSTextField })
        .first(where: { $0.stringValue.contains(text) }) {
        return label
    }

    throw TestFailure(message: "expected label containing '\(text)' to exist")
}

private struct PresentedHealthReport {
    let today: HealthDaySummary
    let week: HealthWeekSummary
}

private final class HealthFlowTestProbe {
    var now = Date(timeIntervalSince1970: 1_744_100_000)
    var deliveredReminderPayloads: [ReminderPresentationPayload] = []
    var presentedReports: [PresentedHealthReport] = []
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
        healthReportPresenter: { today, week in
            probe.presentedReports.append(PresentedHealthReport(today: today, week: week))
        },
        assetLocator: assetLocator,
        petID: "missing_pet",
        onChangeAvatarRequested: {},
        onOpenGenerationConfigRequested: {},
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
