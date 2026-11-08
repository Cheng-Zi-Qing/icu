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

    try requirePixelButton(in: panel, title: "开始工作").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(receivedActions == [.startWork], "context menu controller should dispatch the selected menu action")
    try expect(controller.isPresented == false, "context menu controller should dismiss after selecting an action")
}

func testFloatingPanelControllerDismissesOnEscape() throws {
    _ = NSApplication.shared

    let controller = FloatingPanelController()
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 120))
    controller.present(contentView: contentView, frame: NSRect(x: 120, y: 120, width: 180, height: 120))

    try expect(controller.isPresented == true, "floating panel controller should present a panel window")

    controller.panelWindow?.cancelOperation(nil)
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
