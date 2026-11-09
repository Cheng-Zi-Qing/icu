import AppKit

// 静默跑 AppKit 测试：窗口照常创建、照常算可见，但完全透明，不在屏幕上闪

private func windowServerAlpha(of window: NSWindow) -> Double? {
    let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(window.windowNumber)) as? [[String: Any]]
    return info?.first?[kCGWindowAlpha as String] as? Double
}

func testHeadlessWindowsStayInvisibleButBehaveNormally() throws {
    let showMethods: [(String, (NSWindow) -> Void)] = [
        ("makeKeyAndOrderFront", { $0.makeKeyAndOrderFront(nil) }),
        ("orderFront", { $0.orderFront(nil) }),
        ("orderFrontRegardless", { $0.orderFrontRegardless() }),
        ("orderWindow", { $0.order(.above, relativeTo: 0) }),
    ]
    for (name, show) in showMethods {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        show(window)
        defer { window.orderOut(nil) }

        try expect(window.isVisible, "\(name): the window still counts as shown, so tests behave as before")
        try expect(window.frame.origin == NSPoint(x: 200, y: 200), "\(name): position is untouched")
        try expect(window.alphaValue == 0, "\(name): the window is fully transparent while testing")
        if let alpha = windowServerAlpha(of: window) {
            try expect(alpha == 0, "\(name): the window server draws nothing on screen (alpha \(alpha))")
        }
    }
}
