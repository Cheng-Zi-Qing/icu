import AppKit
import ObjectiveC

/// 静默跑 AppKit 测试：拦下 NSWindow 的上屏方法，上屏前先把窗口设成全透明。
///
/// 窗口照常创建、照常 isVisible / 成为 key，位置不变，所以测试逻辑不受影响；
/// 只是窗口服务器什么也不画，跑测试时屏幕上不会闪出桌宠、菜单面板、健康报告这些窗口。
/// 只在测试入口调用，正式 App 不受影响。想看窗口时设环境变量 ICU_TEST_SHOW_WINDOWS=1。
enum HeadlessWindows {
    static let showWindowsEnvironmentKey = "ICU_TEST_SHOW_WINDOWS"

    private static var isInstalled = false

    static func installUnlessRequested(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard environment[showWindowsEnvironmentKey] != "1", !isInstalled else { return }
        isInstalled = true
        exchange(#selector(NSWindow.orderFront(_:)), with: #selector(NSWindow.headless_orderFront(_:)))
        exchange(#selector(NSWindow.makeKeyAndOrderFront(_:)), with: #selector(NSWindow.headless_makeKeyAndOrderFront(_:)))
        exchange(#selector(NSWindow.orderFrontRegardless), with: #selector(NSWindow.headless_orderFrontRegardless))
        exchange(#selector(NSWindow.order(_:relativeTo:)), with: #selector(NSWindow.headless_orderWindow(_:relativeTo:)))
    }

    private static func exchange(_ original: Selector, with replacement: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(NSWindow.self, original),
            let replacementMethod = class_getInstanceMethod(NSWindow.self, replacement)
        else {
            fatalError("[HeadlessWindows] NSWindow is missing \(original); cannot keep test windows off screen")
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}

// 交换实现后，调用 headless_xxx 实际走的是系统原来的实现
extension NSWindow {
    @objc fileprivate func headless_orderFront(_ sender: Any?) {
        alphaValue = 0
        headless_orderFront(sender)
    }

    @objc fileprivate func headless_makeKeyAndOrderFront(_ sender: Any?) {
        alphaValue = 0
        headless_makeKeyAndOrderFront(sender)
    }

    @objc fileprivate func headless_orderFrontRegardless() {
        alphaValue = 0
        headless_orderFrontRegardless()
    }

    @objc fileprivate func headless_orderWindow(_ place: NSWindow.OrderingMode, relativeTo otherWindow: Int) {
        if place != .out {
            alphaValue = 0
        }
        headless_orderWindow(place, relativeTo: otherWindow)
    }
}
