import AppKit

/// 盖住屏幕的窗口：要能成为 key window，才收得到 Esc
final class EyeRestWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 护眼全屏休息：每块屏幕盖一层像素夜景，倒计时走完算完成；提前结束时歇够一半也算（见 ReminderStageRules）。
/// 休息期间 ICU 在前台接着键盘，你打的字不会漏到被盖住的 App 里；结束后把原来的 App 叫回前台
@MainActor
final class EyeRestOverlayController {
    private enum Motion {
        static let fadeIn: TimeInterval = 0.5
    }

    /// 倒计时和画面多久走一拍
    static let tickInterval: TimeInterval = 0.25

    private(set) var windows: [EyeRestWindow] = []
    private(set) var remaining: TimeInterval = 0
    private var total: TimeInterval = 0
    private var onFinish: ((HealthReminderOutcome) -> Void)?
    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var previousApp: NSRunningApplication?
    private let screenFrames: () -> [CGRect]
    private let now: () -> TimeInterval

    var isActive: Bool { !windows.isEmpty }
    var overlayViews: [EyeRestOverlayView] { windows.compactMap { $0.contentView as? EyeRestOverlayView } }

    init(
        screenFrames: @escaping () -> [CGRect] = { NSScreen.screens.map(\.frame) },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.screenFrames = screenFrames
        self.now = now
    }

    /// 开始休息。`petImage(elapsed)` 给打盹的水豚当前那一帧；结束（走完或提前）只报一次 `onFinish`
    func start(
        content: ReminderCardContent,
        petImage: @escaping (TimeInterval) -> NSImage?,
        onFinish: @escaping (HealthReminderOutcome) -> Void
    ) {
        close()
        total = max(1, content.restSeconds)
        remaining = total
        self.onFinish = onFinish
        previousApp = NSWorkspace.shared.frontmostApplication
        windows = screenFrames().map { makeWindow(frame: $0, content: content, petImage: petImage) }
        NSApp.activate(ignoringOtherApps: true)
        for (index, window) in windows.enumerated() {
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(window.contentView)
            } else {
                window.orderFrontRegardless()
            }
            fadeIn(window.contentView)
        }
        startTimer()
    }

    /// 时间往前走（计时器调；测试里直接调）。走完只算一次完成
    func advance(by seconds: TimeInterval) {
        guard isActive, remaining > 0 else { return }
        remaining = max(0, remaining - seconds)
        for view in overlayViews {
            view.update(elapsed: total - remaining, remaining: remaining)
        }
        if remaining <= 0 {
            finish(.completed)
        }
    }

    /// 提前结束：歇够一半算完成，不够算跳过
    func endEarly() {
        guard isActive else { return }
        finish(ReminderStageRules.restOutcome(rested: total - remaining, total: total))
    }

    /// 直接收起，不报结果
    func cancel() {
        onFinish = nil
        close()
    }

    private func finish(_ outcome: HealthReminderOutcome) {
        let report = onFinish
        onFinish = nil
        close()
        report?(outcome)
    }

    private func close() {
        timer?.invalidate()
        timer = nil
        let hadWindows = !windows.isEmpty
        windows.forEach { $0.orderOut(nil) }
        windows = []
        if hadWindows, let previousApp, previousApp != NSRunningApplication.current {
            previousApp.activate()
        }
        previousApp = nil
    }

    private func makeWindow(frame: CGRect, content: ReminderCardContent, petImage: @escaping (TimeInterval) -> NSImage?) -> EyeRestWindow {
        let window = EyeRestWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = EyeRestOverlayView(frame: NSRect(origin: .zero, size: frame.size), content: content, petImage: petImage)
        view.onEndEarly = { [weak self] in self?.endEarly() }
        window.contentView = view
        return window
    }

    /// 淡入只动图层，不动窗口的透明度（测试里窗口整个是透明的）
    private func fadeIn(_ view: NSView?) {
        guard let view else { return }
        view.wantsLayer = true
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = Motion.fadeIn
        view.layer?.add(fade, forKey: "eyeRest.fadeIn")
    }

    private func startTimer() {
        lastTick = now()
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let current = self.now()
                self.advance(by: current - self.lastTick)
                self.lastTick = current
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
