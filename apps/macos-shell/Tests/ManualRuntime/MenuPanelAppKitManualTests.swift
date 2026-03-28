import AppKit

func testThemedMenuPanelUsesCompactPreferredSize() throws {
    let sections = [
        ThemedMenuPanelSection(items: [
            ThemedMenuPanelItem(id: "start", title: "开始工作"),
        ]),
        ThemedMenuPanelSection(items: [
            ThemedMenuPanelItem(id: "avatar", title: "更换形象"),
            ThemedMenuPanelItem(id: "generation", title: "生成配置"),
        ]),
        ThemedMenuPanelSection(items: [
            ThemedMenuPanelItem(id: "hide", title: "隐藏桌宠"),
            ThemedMenuPanelItem(id: "quit", title: "退出"),
        ]),
    ]

    let preferredSize = ThemedMenuPanel.preferredSize(for: sections)

    try expect(
        preferredSize == NSSize(width: 172, height: 174),
        "themed menu panel should use a compact preferred size for desktop pet context menus"
    )
}

func testThemedMenuPanelRendersRowsAndSeparatorsFromSections() throws {
    let panel = ThemedMenuPanel(
        sections: [
            ThemedMenuPanelSection(items: [
                ThemedMenuPanelItem(id: "start", title: "开始工作"),
            ]),
            ThemedMenuPanelSection(items: [
                ThemedMenuPanelItem(id: "avatar", title: "更换形象"),
                ThemedMenuPanelItem(id: "generation", title: "生成配置"),
            ]),
            ThemedMenuPanelSection(items: [
                ThemedMenuPanelItem(id: "hide", title: "隐藏桌宠"),
                ThemedMenuPanelItem(id: "quit", title: "退出"),
            ]),
        ],
        onSelect: { _ in }
    )

    let buttons = allSubviews(in: panel).compactMap { $0 as? NSButton }
    let separators = allSubviews(in: panel).filter { $0.identifier?.rawValue == "menu-separator" }

    try expect(buttons.count == 5, "themed menu panel should render one button per menu action")
    try expect(separators.count == 2, "themed menu panel should render a separator between menu sections")
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

    try requireButton(in: panel, title: "开始工作").performClick(nil)
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
