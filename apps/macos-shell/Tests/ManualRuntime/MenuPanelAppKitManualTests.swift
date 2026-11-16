import AppKit

private let sampleSections = [
    ThemedMenuPanelSection(items: [
        ThemedMenuPanelItem(id: "start", title: "开始工作", tone: .primary),
    ]),
    ThemedMenuPanelSection(items: [
        ThemedMenuPanelItem(id: "settings", title: "设置…"),
    ]),
    ThemedMenuPanelSection(items: [
        ThemedMenuPanelItem(id: "hide", title: "隐藏桌宠"),
        ThemedMenuPanelItem(id: "quit", title: "退出", tone: .destructive),
    ]),
]

private let sampleSummary = MenuTodaySummary(
    day: HealthDaySummary(
        date: Date(), eyeReminder: HealthReminderCounts(shown: 5, completed: 5, snoozed: 0, skipped: 0),
        hydrationReminder: HealthReminderCounts(shown: 3, completed: 3, snoozed: 0, skipped: 0),
        workDuration: 3 * 3600 + 20 * 60, focusCount: 0, focusDuration: 0, breakCount: 0
    ),
    cupsGoal: 6
)

private let sampleFullDayReport = HealthDaySummary(
    date: Date(),
    eyeReminder: HealthReminderCounts(shown: 5, completed: 4, snoozed: 1, skipped: 0),
    hydrationReminder: HealthReminderCounts(shown: 4, completed: 3, snoozed: 0, skipped: 1),
    workDuration: 3 * 3600 + 20 * 60,
    focusCount: 2,
    focusDuration: 40 * 60,
    breakCount: 1
)

private func reportContent(_ day: HealthDaySummary, lifetime: HealthLifetimeSummary? = nil) -> TodayReportContent {
    TodayReportContent(day: day, lifetime: lifetime, cupsGoal: 6, workHours: 8, isOnDuty: false)
}

private let sampleEmptyDayReport = HealthDaySummary(
    date: Date(),
    eyeReminder: .empty,
    hydrationReminder: .empty,
    workDuration: 0,
    focusCount: 0,
    focusDuration: 0,
    breakCount: 0
)

func testThemedMenuPanelUsesCompactPreferredSize() throws {
    let plain = ThemedMenuPanel.preferredSize(for: sampleSections, hasSummary: false)
    try expect(plain == NSSize(width: 200, height: 152), "4 rows × 28 + 2 separators × 10 + padding 16 + shadow 4 (got \(plain))")

    let withSummary = ThemedMenuPanel.preferredSize(for: sampleSections, hasSummary: true)
    try expect(withSummary.height == plain.height + 56 + 10, "the today header adds its height plus one separator (got \(withSummary))")
}

func testThemedMenuPanelRendersRowsAndSeparatorsFromSections() throws {
    let panel = ThemedMenuPanel(sections: sampleSections, onSelect: { _ in })
    let rows = allSubviews(in: panel).compactMap { $0 as? PixelButton }
    let separators = allSubviews(in: panel).filter { $0.identifier?.rawValue == "menu-separator" }
    try expect(rows.count == 4, "one pixel row per menu action (got \(rows.count))")
    try expect(separators.count == 2, "a dotted separator between sections (got \(separators.count))")
    try expect(rows.first?.isFlat == false, "the primary action is a raised yellow button")
    try expect(rows.dropFirst().allSatisfy(\.isFlat), "other actions are flat rows")
    try expect(rows.last?.textColor == PixelPalette.danger, "quit is shown in red")
}

func testThemedMenuPanelShowsTodaySummaryHeader() throws {
    let panel = ThemedMenuPanel(sections: sampleSections, summary: sampleSummary, onSelect: { _ in })
    guard let header = allSubviews(in: panel).first(where: { $0.identifier?.rawValue == "menu-today" }) else {
        throw TestFailure(message: "menu should show the today header when a summary is given")
    }
    let label = header.accessibilityLabel() ?? ""
    try expect(label.contains("3/6 杯") && label.contains("5 次") && label.contains("3:20"), "header reads cups, eye breaks and work time (got \(label))")
    let separators = allSubviews(in: panel).filter { $0.identifier?.rawValue == "menu-separator" }
    try expect(separators.count == 3, "the header is separated from the actions (got \(separators.count))")
}

func testDesktopPetViewRightClickOpensMenuWhilePeekingAtEitherEdge() throws {
    _ = NSApplication.shared
    _ = try makeInstalledThemeManager()
    let repoRoot = inferredManualTestRepoRootURL()
    let view = DesktopPetView(
        frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize),
        assetLocator: PetAssetLocator(repoRootURL: repoRoot),
        petID: "capybara"
    )
    let window = DesktopPetWindow(
        contentRect: NSRect(origin: NSPoint(x: 400, y: 300), size: view.frame.size),
        styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    let controller = ContextMenuPanelController { _ in }
    window.contextMenuController = controller
    defer {
        controller.dismiss()
        window.contentView = nil
        window.close()
    }

    try expect(view.hasPeekPose, "load the real repo capybara edge/peek PNGs")
    var pointerEntries = 0
    var overlayChanges = 0
    var pokeReactions = 0
    view.onPointerEntered = { pointerEntries += 1 }
    view.onOverlayLayoutModeChanged = { _ in overlayChanges += 1 }
    view.onPokeReaction = { _, _ in pokeReactions += 1 }
    let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let cases: [(HorizontalDockEdge?, ShellWorkState)] = [(.right, .working), (.left, .breakState), (nil, .idle)]
    for (edge, state) in cases {
        let description = "edge=\(String(describing: edge)), state=\(state)"
        view.setWorkState(state)
        view.setFacingRight(edge == .left)
        view.setDockedToSide(edge != nil)
        view.setEdgePeek(edge != nil)
        window.menuModelProvider = { DesktopPetMenuModel(state: state) }
        guard let body = view.petBodyRect else {
            throw TestFailure(message: "real sprite should have body bounds (\(description))")
        }
        if let edge {
            let origin = EdgeDockLayout.hiddenOrigin(
                dockedOrigin: NSPoint(x: 400, y: visible.midY), edge: edge,
                bodyRect: body, visibleFrame: visible, peekWidth: 36
            )
            window.setFrameOrigin(origin)
            try expect(view.statusLabel.isHidden, "peeking hides the status chip (\(description))")
        } else {
            window.setFrameOrigin(NSPoint(x: visible.midX, y: visible.midY))
        }

        // Pick a visible, opaque pixel in the upper half of the actual displayed head.
        let points = stride(from: body.midY, to: body.maxY, by: 1).flatMap { y in
            stride(from: body.minX, to: body.maxX, by: 1).map { NSPoint(x: $0, y: y) }
        }
        guard let head = points.first(where: {
            view.isOpaquePetPixel(at: $0) && visible.contains(window.convertPoint(toScreen: $0))
        }), let hit = view.hitTest(head) else {
            throw TestFailure(message: "exposed head should hit an opaque repo PNG pixel (\(description))")
        }
        try expect(hit === view, "opaque head hits the pet view (\(description), point=\(head))")
        let transparent = NSPoint(x: view.petCanvasRect.minX + 1, y: view.petCanvasRect.maxY - 1)
        try expect(!view.isOpaquePetPixel(at: transparent) && view.hitTest(transparent) == nil,
                   "transparent padding still passes through (\(description))")
        let originalFrame = window.frame
        let originalPeekFrame = view.shownPeekFrame
        let popoversBefore = NSApp.windows.filter { NSStringFromClass(type(of: $0)).contains("Popover") }.count
        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown, location: view.convert(head, to: nil), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        ) else {
            throw TestFailure(message: "failed to create a real right-mouse event")
        }
        hit.rightMouseDown(with: event)

        try expect(controller.isPresented, "right-click on the hit head immediately opens the menu (\(description), point=\(head))")
        guard let panel = controller.currentPanel else {
            throw TestFailure(message: "head right-click should present the themed operation menu")
        }
        let titles = allSubviews(in: panel).compactMap { ($0 as? PixelButton)?.title }
        try expect(titles == DesktopPetMenuModel(state: state).items.map(\.title),
                   "menu contains the current work-state actions and settings (\(description), got \(titles))")
        try expect(window.frame == originalFrame && view.isPeeking == (edge != nil)
                   && view.isDockedToSide == (edge != nil) && view.shownPeekFrame == originalPeekFrame,
                   "right-click does not reveal or move the pet or change its peek frame (\(description))")
        try expect(pointerEntries == 0 && overlayChanges == 0 && pokeReactions == 0
                   && !view.isPressingPet && view.pokePressPoint == nil && !view.dragController.isDragging,
                   "right-click needs no hover, reveal, poke or left-button press (\(description))")
        try expect(NSApp.windows.filter { NSStringFromClass(type(of: $0)).contains("Popover") }.count == popoversBefore,
                   "right-click does not open a popover (\(description))")
        controller.dismiss()
    }
}

func testContextMenuPanelControllerDispatchesSelectedActionAndDismissesPanel() throws {
    _ = NSApplication.shared

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 240),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
    window.makeKeyAndOrderFront(nil)

    guard let contentView = window.contentView else {
        throw TestFailure(message: "window content view should exist")
    }

    var receivedActions: [DesktopPetMenuAction] = []
    let controller = ContextMenuPanelController { action in
        receivedActions.append(action)
    }

    guard let event = NSEvent.mouseEvent(
        with: .rightMouseDown,
        location: NSPoint(x: 80, y: 80),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    ) else {
        throw TestFailure(message: "failed to create right click event")
    }

    controller.present(
        from: DesktopPetMenuModel(state: .idle),
        event: event,
        in: contentView
    )

    guard let panel = controller.currentPanel else {
        throw TestFailure(message: "context menu controller should expose a panel after present")
    }

    try requirePixelButton(in: panel, title: "我要上班").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(receivedActions == [.startWork], "context menu controller should dispatch the selected menu action")
    try expect(controller.isPresented == false, "context menu controller should dismiss after selecting an action")
}

func testContextMenuPanelControllerPresentsTodayReportAboveThePetWindow() throws {
    _ = NSApplication.shared

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 240),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
    // 挪到屏幕中间：报告面板顶在窗口上面长高，靠边会被 FloatingPanelController 的 clamp 挪走
    if let visibleFrame = NSScreen.main?.visibleFrame {
        window.setFrameOrigin(NSPoint(x: visibleFrame.midX - 120, y: visibleFrame.midY - 120))
    }
    window.makeKeyAndOrderFront(nil)

    guard let contentView = window.contentView else {
        throw TestFailure(message: "window content view should exist")
    }

    var receivedActions: [DesktopPetMenuAction] = []
    let controller = ContextMenuPanelController { action in
        receivedActions.append(action)
    }
    controller.todayReportProvider = { reportContent(sampleFullDayReport) }
    // 桌宠在屏幕右下角：报告放到它左边
    let visible = NSScreen.main?.visibleFrame ?? .zero
    let pet = NSRect(x: visible.maxX - 140, y: visible.minY + 20, width: 120, height: 100)
    controller.petFrameProvider = { pet }

    guard let event = NSEvent.mouseEvent(
        with: .rightMouseDown,
        location: NSPoint(x: 120, y: 120),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    ) else {
        throw TestFailure(message: "failed to create right click event")
    }

    controller.present(
        from: DesktopPetMenuModel(state: .idle),
        event: event,
        in: contentView
    )

    guard let panel = controller.currentPanel else {
        throw TestFailure(message: "context menu controller should expose a panel after present")
    }

    try requirePixelButton(in: panel, title: "今日报告…").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(receivedActions.isEmpty, "the today report is handled by the controller, not dispatched as a menu action")
    try expect(controller.currentPanel == nil, "the menu panel is replaced by the report panel")

    // 关掉的面板窗口也会留在 NSApp.windows 里，按内容认出刚才弹出来的那个
    guard let panelWindow = reportPanelWindows().last else {
        throw TestFailure(message: "the today report should open a floating panel window with the report view")
    }

    let frame = panelWindow.frame
    try expect(abs(frame.maxX - (pet.minX - ReportPanelPlacement.gap)) < 0.5, "the report sits beside the pet, toward the screen center (got \(frame))")
    try expect(visible.contains(frame), "the report stays on screen (got \(frame))")
    try expect(
        frame.size == MenuTodayReportView.preferredSize(for: reportContent(sampleFullDayReport)),
        "the report panel is as big as the report view wants (got \(frame))"
    )
    try expect(!frame.intersects(pet), "the report does not cover the pet (got \(frame))")

    controller.dismiss()
    try expect(controller.isPresented == false, "dismiss should close the today report panel")
}

func testContextMenuPanelControllerSaysSoWhenTodayHasNoRecords() throws {
    _ = NSApplication.shared

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 240),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
    window.makeKeyAndOrderFront(nil)

    guard let contentView = window.contentView else {
        throw TestFailure(message: "window content view should exist")
    }

    // 读不到统计、和今天一条记录都没有，都算「没东西可看」
    for report: TodayReportContent? in [nil, reportContent(sampleEmptyDayReport)] {
        var emptyReportCalls = 0
        let controller = ContextMenuPanelController { _ in }
        controller.todayReportProvider = { report }
        controller.onEmptyReport = { emptyReportCalls += 1 }
        // 关掉的面板窗口也会留在 NSApp.windows 里，只能比前后数量
        let reportPanelsBefore = reportPanelWindows().count

        guard let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: NSPoint(x: 80, y: 80),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ) else {
            throw TestFailure(message: "failed to create right click event")
        }

        controller.present(from: DesktopPetMenuModel(state: .idle), event: event, in: contentView)
        guard let panel = controller.currentPanel else {
            throw TestFailure(message: "context menu controller should expose a panel after present")
        }

        try requirePixelButton(in: panel, title: "今日报告…").performClick(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        try expect(emptyReportCalls == 1, "a day without records should only make the pet say so (got \(emptyReportCalls))")
        try expect(
            reportPanelWindows().count == reportPanelsBefore,
            "a day without records should not open the report panel (got \(reportPanelWindows().count) vs \(reportPanelsBefore))"
        )
        try expect(controller.isPresented == false, "the menu should close even when there is nothing to show")
    }
}

/// 现在开着 / 关掉的面板窗口里，内容是哪一种（关掉的也会留在 NSApp.windows 里）
private func reportPanelWindows() -> [MenuFloatingPanelWindow] {
    NSApp.windows
        .compactMap { $0 as? MenuFloatingPanelWindow }
        .filter { $0.contentView is MenuTodayReportView }
}

func testFloatingPanelControllerDismissesOnEscape() throws {
    _ = NSApplication.shared

    let controller = FloatingPanelController()
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 120))
    controller.present(contentView: contentView, frame: NSRect(x: 120, y: 120, width: 180, height: 120))

    try expect(controller.isPresented == true, "floating panel controller should present a panel window")
    guard let panel = controller.panelWindow else {
        throw TestFailure(message: "floating panel controller should expose its panel window")
    }
    try expect(panel.styleMask.contains(.nonactivatingPanel), "floating panel should support presentation without activating the app")
    try expect(!panel.hidesOnDeactivate, "floating panel should stay visible while the app is inactive")
    try expect(panel.isVisible, "floating panel should be visible after present")

    panel.cancelOperation(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(controller.isPresented == false, "floating panel controller should dismiss the panel when escape is triggered")
}

func testFloatingPanelControllerDismissesOnApplicationDeactivate() throws {
    _ = NSApplication.shared

    let controller = FloatingPanelController()
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 120))
    controller.present(contentView: contentView, frame: NSRect(x: 120, y: 120, width: 180, height: 120))

    try expect(controller.isPresented == true, "floating panel should be visible before app deactivation")

    NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(controller.isPresented == false, "floating panel should dismiss when the app resigns active")
}

func testFloatingPanelControllerRepeatedPresentOnlyDismissesExistingPanels() throws {
    _ = NSApplication.shared

    let controller = FloatingPanelController()
    var dismissCount = 0
    controller.onDidDismiss = {
        dismissCount += 1
    }

    controller.present(
        contentView: NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 100)),
        frame: NSRect(x: 100, y: 100, width: 160, height: 100)
    )
    try expect(dismissCount == 0, "initial present should not emit a dismiss callback when no panel existed")

    controller.present(
        contentView: NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 120)),
        frame: NSRect(x: 120, y: 120, width: 180, height: 120)
    )
    try expect(dismissCount == 1, "re-presenting should dismiss exactly the previous panel")

    controller.dismiss()
    try expect(dismissCount == 2, "explicit dismiss should emit one additional dismiss callback")
}

func testFloatingPanelControllerDismissesOnOutsideClickEvent() throws {
    _ = NSApplication.shared

    let controller = FloatingPanelController()
    controller.present(
        contentView: NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 120)),
        frame: NSRect(x: 120, y: 120, width: 180, height: 120)
    )

    let otherWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    otherWindow.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 120))
    otherWindow.makeKeyAndOrderFront(nil)

    guard let outsideClick = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: NSPoint(x: 20, y: 20),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: otherWindow.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    ) else {
        throw TestFailure(message: "failed to create outside click event")
    }

    _ = controller.handleMonitoredMouseEvent(outsideClick)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(controller.isPresented == false, "floating panel should dismiss when a monitored outside click arrives")
}

func testMenuTodayReportViewReadsOutEveryNumber() throws {
    let content = reportContent(sampleFullDayReport, lifetime: HealthLifetimeSummary(workedDayCount: 3, onDutyDuration: 20 * 3600))
    let view = MenuTodayReportView(content: content)
    try expect(view.frame.size == MenuTodayReportView.preferredSize(for: content), "the report view sizes itself to its preferred size")

    let label = view.accessibilityLabel() ?? ""
    try expect(label.contains("上班 4:00"), "on duty counts work and focus (got \(label))")
    try expect(label.contains("2 次 · 0:40"), "the report reads the focus sessions (got \(label))")
    try expect(label.contains("4/5 次"), "the report reads the eye reminders against what was shown (got \(label))")
    try expect(label.contains("3/6 杯"), "the report reads the cups against the goal (got \(label))")
    try expect(label.contains("累计 3 天 · 20:00"), "the report reads the lifetime total (got \(label))")
    try expect(label.contains(content.advice[0].text), "the report reads its conclusion (got \(label))")
}

func testMenuTodayReportViewHidesRowsWithoutData() throws {
    let empty = reportContent(sampleEmptyDayReport)
    let label = MenuTodayReportView(content: empty).accessibilityLabel() ?? ""
    try expect(!label.contains("专注"), "no focus row without focus sessions (got \(label))")
    try expect(!label.contains("休息"), "no break row without breaks (got \(label))")
    try expect(!label.contains("护眼"), "no eye row without reminders (got \(label))")
    try expect(label.contains("上班 0:00"), "time on duty is always shown (got \(label))")
    try expect(label.contains("0/6 杯"), "hydration is always shown against the goal (got \(label))")

    let emptySize = MenuTodayReportView.preferredSize(for: empty)
    let withLifetime = MenuTodayReportView.preferredSize(for: reportContent(sampleEmptyDayReport, lifetime: HealthLifetimeSummary(workedDayCount: 1, onDutyDuration: 60)))
    try expect(withLifetime.height == emptySize.height + 10 + 22, "the lifetime footer adds a separator and a row (got \(emptySize.height) vs \(withLifetime.height))")
}

func testStatusMenuPanelControllerPresentsTodayReportUnderTheButton() throws {
    _ = NSApplication.shared

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 240, height: 240),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
    let button = NSStatusBarButton(frame: NSRect(x: 100, y: 200, width: 24, height: 24))
    window.contentView?.addSubview(button)
    window.makeKeyAndOrderFront(nil)

    let controller = StatusMenuPanelController { _ in }
    controller.presentTodayReport(from: button, content: reportContent(sampleFullDayReport))

    try expect(controller.isPresented, "presenting the today report should open a floating panel")

    // 关掉的面板窗口也会留在 NSApp.windows 里，按内容认出刚才弹出来的那个
    let reportPanels = NSApp.windows
        .compactMap { $0 as? MenuFloatingPanelWindow }
        .filter { $0.contentView is MenuTodayReportView }
    guard let panelWindow = reportPanels.last else {
        throw TestFailure(message: "the today report should open a floating panel window with the report view")
    }
    let buttonFrameInScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
    let frame = panelWindow.frame
    let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? .zero
    if buttonFrameInScreen.maxX - frame.width >= visible.minX {
        try expect(abs(frame.maxX - buttonFrameInScreen.maxX) < 0.5, "the report hangs under the button, right edges aligned (got \(frame))")
    }
    try expect(
        NSScreen.screens.contains { $0.visibleFrame.contains(frame) },
        "the report panel is clamped inside the visible screen area (got \(frame))"
    )

    controller.dismiss()
    try expect(controller.isPresented == false, "dismiss should close the today report panel")
}
