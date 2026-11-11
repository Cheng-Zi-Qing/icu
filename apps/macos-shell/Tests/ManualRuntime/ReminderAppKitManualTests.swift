import AppKit

/// 屏幕中央的提醒卡：三个按钮各报各的结果
@MainActor
func testReminderStageShowsThePlayfulCopyAndDispatchesEachButton() throws {
    _ = try makeInstalledThemeManager()
    let content = ReminderCardContent(
        payload: ReminderPresentationPayload(id: UUID(), type: .hydration, text: "喝口水，慢慢来。"),
        cups: CupProgress(done: 3, goal: 6)
    )
    var asked: [TimeInterval] = []
    let stage = ReminderStageView(content: content) { elapsed in
        asked.append(elapsed)
        return nil
    }
    stage.layoutSubtreeIfNeeded()
    var outcomes: [HealthReminderOutcome] = []
    stage.onAction = { outcomes.append($0) }

    let complete = try requireButton(in: stage, identifier: "reminderStage.complete")
    let snooze = try requireButton(in: stage, identifier: "reminderStage.snooze")
    let skip = try requireButton(in: stage, identifier: "reminderStage.skip")
    try expect(ReminderQuips.hydration.done.contains(complete.title ?? ""), "water is confirmed with a drinking quip (got \(complete.title ?? "nil"))")
    try expect(snooze.title == content.snoozeTitle && skip.title == content.skipTitle, "later and nope come from the content")
    for button in [complete, snooze, skip] {
        try expect(stage.bounds.contains(button.frame) && button.frame.width >= 100, "buttons sit inside the card and are easy to hit (got \(button.frame))")
    }
    try expect(complete.frame.width > snooze.frame.width, "the main button is the biggest")
    try expect(stage.accessibilityLabel()?.contains("第 4/6 杯") == true, "reads out which cup this is")
    try expect(stage.acceptsFirstMouse(for: nil), "works with one click while another app is in front")

    complete.performClick(nil)
    snooze.performClick(nil)
    skip.performClick(nil)
    try expect(outcomes == [.completed, .snoozed, .skipped], "each button reports its outcome (got \(outcomes))")

    // 水豚的动作跟着时间走
    _ = stage.bitmapImageRepForCachingDisplay(in: stage.bounds).map { stage.cacheDisplay(in: stage.bounds, to: $0) }
    stage.advance(by: 0.5)
    _ = stage.bitmapImageRepForCachingDisplay(in: stage.bounds).map { stage.cacheDisplay(in: stage.bounds, to: $0) }
    try expect(asked.first == 0 && asked.last == 0.5, "the pet frame follows the time on screen (got \(asked))")
}

/// 提醒卡摆在屏幕正中，比桌宠头顶那张小卡大得多，不抢键盘焦点
@MainActor
func testReminderStagePresenterCentersABigCardWithoutStealingFocus() throws {
    _ = try makeInstalledThemeManager()
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 860)
    let presenter = ReminderStagePresenter(visibleFrame: { visible }, unansweredTimeout: 0)
    defer { presenter.dismiss() }
    let content = ReminderCardContent(payload: ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 20), cups: nil)
    var outcomes: [HealthReminderOutcome] = []
    presenter.show(content: content, petImage: { _ in nil }) { outcomes.append($0) }

    let panel = try requireValue(presenter.panel, "the card is in its own panel")
    try expect(presenter.isShowing && panel.isVisible, "on screen")
    try expect(!panel.canBecomeKey, "typing stays in the app you were using")
    try expect(panel.level.rawValue >= NSWindow.Level.statusBar.rawValue, "above every normal window")
    try expect(panel.frame.size == ReminderStageView.preferredSize && panel.frame.width >= 400, "a big card (got \(panel.frame.size))")
    let settled = waitForCondition(timeout: 1) { abs(panel.frame.midX - visible.midX) <= 1 && abs(panel.frame.midY - visible.midY) < 90 }
    try expect(settled, "settles in the middle of the screen (got \(panel.frame))")

    try requireButton(in: try requireValue(presenter.stageView, "stage view"), identifier: "reminderStage.complete").performClick(nil)
    try expect(outcomes == [.completed] && !presenter.isShowing, "a click reports once and puts the card away")
}

@MainActor
func testReminderStageGivesUpAsSkippedWhenNobodyAnswers() throws {
    _ = try makeInstalledThemeManager()
    let presenter = ReminderStagePresenter(visibleFrame: { CGRect(x: 0, y: 0, width: 1440, height: 860) }, unansweredTimeout: 0.05)
    defer { presenter.dismiss() }
    let content = ReminderCardContent(payload: ReminderPresentationPayload(id: UUID(), type: .hydration, text: "x"), cups: nil)
    var outcomes: [HealthReminderOutcome] = []
    presenter.show(content: content, petImage: { _ in nil }) { outcomes.append($0) }
    try expect(waitForCondition(timeout: 1) { outcomes == [.skipped] }, "an unanswered card counts as skipped (got \(outcomes))")
    try expect(!presenter.isShowing, "and goes away")

    presenter.show(content: content, petImage: { _ in nil }) { outcomes.append($0) }
    presenter.dismiss()
    _ = waitForCondition(timeout: 0.15) { false }
    try expect(outcomes == [.skipped], "a card that was put away reports nothing later (got \(outcomes))")
}

/// 护眼全屏休息：每块屏幕盖一层，倒计时走完算完成
@MainActor
func testEyeRestCoversEveryScreenCountsDownAndCompletesOnce() throws {
    _ = try makeInstalledThemeManager()
    let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)]
    let rest = EyeRestOverlayController(screenFrames: { screens }, now: { 0 })
    defer { rest.cancel() }
    let content = ReminderCardContent(payload: ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 20), cups: nil)
    var outcomes: [HealthReminderOutcome] = []
    rest.start(content: content, petImage: { _ in nil }) { outcomes.append($0) }

    try expect(rest.isActive && rest.windows.map(\.frame) == screens, "one cover per screen (got \(rest.windows.map(\.frame)))")
    try expect(rest.windows.allSatisfy { $0.level.rawValue >= NSWindow.Level.screenSaver.rawValue && $0.canBecomeKey }, "above everything, and takes the keyboard")
    let view = try requireValue(rest.overlayViews.first, "overlay view")
    try expect(view.clockText == "还剩 20 秒" && view.litSegments == ReminderCardContent.progressSegments, "starts full (got \(view.clockText))")
    _ = try requireButton(in: view, identifier: "eyeRest.endEarly")

    rest.advance(by: 6)
    try expect(view.clockText == "还剩 14 秒" && view.litSegments == 14, "ticks down (got \(view.clockText), \(view.litSegments))")
    try expect(view.accessibilityLabel()?.contains("还剩 14 秒") == true, "read out too")
    rest.advance(by: 14)
    rest.advance(by: 1)
    try expect(outcomes == [.completed] && !rest.isActive && rest.windows.isEmpty, "finishing completes exactly once and uncovers the screens (got \(outcomes))")
}

@MainActor
func testEyeRestEndedEarlyReportsSkippedOrCompletedByHowMuchWasDone() throws {
    _ = try makeInstalledThemeManager()
    let content = ReminderCardContent(payload: ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 20), cups: nil)
    let rest = EyeRestOverlayController(screenFrames: { [CGRect(x: 0, y: 0, width: 800, height: 600)] }, now: { 0 })
    defer { rest.cancel() }
    var outcomes: [HealthReminderOutcome] = []

    rest.start(content: content, petImage: { _ in nil }) { outcomes.append($0) }
    rest.advance(by: 4)
    try requireButton(in: try requireValue(rest.overlayViews.first, "overlay"), identifier: "eyeRest.endEarly").performClick(nil)
    try expect(outcomes == [.skipped] && !rest.isActive, "leaving after 4 of 20 seconds is a skip (got \(outcomes))")

    rest.start(content: content, petImage: { _ in nil }) { outcomes.append($0) }
    rest.advance(by: 12)
    try requireValue(rest.overlayViews.first, "overlay").cancelOperation(nil)
    try expect(outcomes == [.skipped, .completed], "Esc after 12 of 20 seconds still counts (got \(outcomes))")

    rest.start(content: content, petImage: { _ in nil }) { outcomes.append($0) }
    rest.cancel()
    rest.advance(by: 30)
    try expect(outcomes.count == 2 && !rest.isActive, "a cancelled rest reports nothing")
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

    // 护眼：点「开始休息」先全屏挡住屏幕，歇完才记完成
    harness.controller.presentReminder(payload: completePayload)
    try expect(harness.petView.scene == .remind(.eyeCare), "the pet looks away along with the card")
    try harness.stageButton("complete").performClick(nil)
    try expect(!harness.controller.reminderStage.isShowing && harness.controller.eyeRest.isActive, "start hands over to the full-screen rest")
    let duringRest = try harness.store.daySummary(for: harness.probe.now)
    try expect(duringRest.eyeReminder.completed == 0, "nothing is recorded until the rest is over")
    harness.controller.eyeRest.advance(by: completePayload.restSeconds)
    try expect(!harness.controller.eyeRest.isActive && harness.petView.scene == nil, "the screen comes back and the pet settles")

    harness.controller.presentReminder(payload: skipPayload)
    try harness.stageButton("skip").performClick(nil)
    try expect(!harness.controller.eyeRest.isActive, "skipping never covers the screen")

    let summary = try harness.store.daySummary(for: harness.probe.now)
    try expect(summary.eyeReminder.shown == 2, "manual reminder presentations should record shown events")
    try expect(summary.eyeReminder.completed == 1, "complete action should persist a completed outcome")
    try expect(summary.eyeReminder.skipped == 1, "skip action should persist a skipped outcome")
    try expect(summary.eyeReminder.snoozed == 0, "complete and skip should not increment snoozed counts")
}

@MainActor
func testReminderShowsInTheMiddleOfTheScreenAndLeavesThePetWindowAlone() throws {
    let harness = try makeHealthFlowHarness()
    defer { harness.controller.close() }

    let payload = ReminderPresentationPayload(
        id: UUID(uuidString: "dddddddd-4444-4444-4444-444444444444")!,
        type: .hydration,
        text: "喝口水，慢慢来。"
    )
    harness.controller.presentReminder(payload: payload)

    try expect(harness.controller.reminderStage.isShowing, "the reminder is a card of its own")
    try expect(
        harness.petView.currentOverlayLayoutMode != .card && harness.window.frame.height < DesktopPetView.cardExpandedContentSize.height,
        "no card hangs over the pet any more, so its window does not grow for one (got \(harness.window.frame.size))"
    )
    try expect(harness.petView.scene == .remind(.hydration), "the pet drinks along")
    try harness.stageButton("complete").performClick(nil)
    try expect(!harness.controller.reminderStage.isShowing && !harness.controller.eyeRest.isActive, "water is confirmed right on the card")
    try expect(harness.petView.scene == nil, "and the pet goes back to idling")
    let afterCup = try harness.store.daySummary(for: harness.probe.now)
    try expect(afterCup.hydrationReminder.completed == 1, "one cup recorded")

    harness.controller.presentReminder(payload: ReminderPresentationPayload(id: UUID(), type: .hydration, text: "x"))
    harness.controller.close()
    try expect(!harness.controller.reminderStage.isShowing, "closing the pet takes the card with it")
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
    try harness.stageButton("snooze").performClick(nil)

    let receivedFollowUp = waitForCondition(timeout: 0.6) {
        harness.probe.deliveredReminderPayloads.count == 1
    }
    try expect(receivedFollowUp, "snooze action should request a follow-up reminder")

    guard let followUpPayload = harness.probe.deliveredReminderPayloads.first else {
        throw TestFailure(message: "expected snooze follow-up payload to exist")
    }

    try expect(followUpPayload.id != originalPayload.id, "snooze follow-up should use a fresh reminder id")

    harness.probe.now = harness.probe.now.addingTimeInterval(300)
    try harness.stageButton("complete").performClick(nil)
    harness.controller.eyeRest.advance(by: followUpPayload.restSeconds)

    let summary = try harness.store.daySummary(for: harness.probe.now)
    try expect(summary.eyeReminder.shown == 2, "original reminder and follow-up should both count as shown")
    try expect(summary.eyeReminder.snoozed == 1, "snooze action should persist the snoozed outcome once")
    try expect(summary.eyeReminder.completed == 1, "follow-up completion should persist separately from the snooze")
}

/// 每句俏皮话放进屏幕中央的提醒卡都不会被截掉：两倍大的标题、三个按钮、说明和小字；中英文都量
func testReminderQuipsFitTheirSlotsOnTheCard() throws {
    let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    PixelFont.register(assetsDirectory: repoRoot.appendingPathComponent("assets"))
    try expect(PixelFont.isAvailable, "measure with the real pixel font (repo root \(repoRoot.path))")
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    func width(_ text: String, scale: Int = 1) -> CGFloat { PixelPaint.textSize(text, font: PixelFont.font(scale: scale)).width }
    // 右边一栏：从 184 到卡片右边留白 16
    let column = ReminderStageView.preferredSize.width - 16 - 184
    let titleRoom = column - PixelPaint.iconSize(.eye).width - 8
    let halfButton = (column - 8) / 2 - 8

    for language in [AppLanguage.chinese, .english] {
        TextCatalog.installShared(try TextCatalog.live(appPaths: nil, repoRootURL: repoRoot, language: language))
        let pools = [ReminderQuips.hydration, ReminderQuips.lookAway, ReminderQuips.standUp]
        try expect(!ReminderQuips.lookAway.start.isEmpty && !ReminderQuips.standUp.start.isEmpty, "eye care has start-rest buttons (\(language))")
        for line in pools.flatMap(\.lines) {
            try expect(width(line, scale: 2) <= titleRoom, "'\(line)' is \(width(line, scale: 2))pt, title room is \(titleRoom)pt")
        }
        for title in pools.flatMap({ $0.done + $0.start }) {
            try expect(width(title) <= column - 8, "main button '\(title)' is \(width(title))pt")
        }
        for title in ReminderQuips.later + ReminderQuips.nope {
            try expect(width(title) <= halfButton, "button '\(title)' is \(width(title))pt, room is \(halfButton)pt")
        }
        let payloads = [
            ReminderPresentationPayload(id: UUID(), type: .hydration, text: "x"),
            ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 20),
            ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 300),
        ]
        for payload in payloads {
            let content = ReminderCardContent(payload: payload, cups: CupProgress(done: 13, goal: 14))
            for text in [content.summary, content.hint] {
                try expect(width(text) <= column, "'\(text)' is \(width(text))pt, column is \(column)pt")
            }
        }
        // 今日报告评分那一块：右边一行说明的地方有限
        for grade in ["great", "good", "okay", "tired"] {
            let caption = TextCatalog.shared.text("report.score_caption_\(grade)")
            try expect(width(caption) <= 182, "score caption '\(caption)' is \(width(caption))pt")
        }
    }
}

private func requireValue<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw TestFailure(message: "expected \(message)") }
    return value
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

    var petView: DesktopPetView { window.contentView as! DesktopPetView }

    /// 屏幕中央那张提醒卡上的按钮
    @MainActor
    func stageButton(_ name: String) throws -> PixelButton {
        try requireButton(in: try requireValue(controller.reminderStage.stageView, "a reminder card on screen"), identifier: "reminderStage.\(name)")
    }
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
