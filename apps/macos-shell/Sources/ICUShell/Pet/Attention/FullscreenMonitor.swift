import AppKit

/// 盯着前台 App 是不是全屏：切 App、切桌面（进出全屏会换一个桌面）时马上看，另外每几秒补看一次
@MainActor
final class FullscreenMonitor {
    static let pollInterval: TimeInterval = 5

    var onChange: ((Bool) -> Void)?
    private(set) var isFullscreen = false

    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.check() }
            })
        }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    func stop() {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers = []
        timer?.invalidate()
        timer = nil
    }

    func check() {
        let front = NSWorkspace.shared.frontmostApplication
        // ICU 自己到了前台（看视频时点了一下桌宠）：全屏的 App 还在后面，维持原来的判断
        guard front?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let pid = front?.processIdentifier
        let next = FullscreenDetector.isFullscreen(
            frontmostPID: pid,
            windows: FullscreenDetector.liveWindows(),
            screens: FullscreenDetector.liveScreens()
        )
        guard next != isFullscreen else { return }
        isFullscreen = next
        onChange?(next)
    }
}
