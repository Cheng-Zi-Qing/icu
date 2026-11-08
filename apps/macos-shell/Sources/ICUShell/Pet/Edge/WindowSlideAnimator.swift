import AppKit

/// 平滑移动窗口（吸边 / 藏边 / 探出来）
protocol WindowMoving: AnyObject {
    func move(_ window: NSWindow, to origin: CGPoint, duration: TimeInterval, completion: @escaping () -> Void)
    /// 立刻停在当前位置（比如用户又抓起了它）
    func cancel()
}

/// 延迟执行藏边
protocol HideScheduling: AnyObject {
    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void)
    func cancel()
}

/// 用 60Hz 定时器逐帧插值窗口原点（ease-out），可随时取消。
/// 不用 `window.animator()`：它无法中途打断，和手动拖拽抢位置。
final class WindowSlideAnimator: WindowMoving {
    private static let frameInterval: TimeInterval = 1.0 / 60

    private var timer: Timer?
    private let timeProvider: () -> TimeInterval

    init(timeProvider: @escaping () -> TimeInterval = { CACurrentMediaTime() }) {
        self.timeProvider = timeProvider
    }

    deinit {
        timer?.invalidate()
    }

    func move(_ window: NSWindow, to origin: CGPoint, duration: TimeInterval, completion: @escaping () -> Void) {
        cancel()
        let start = window.frame.origin
        guard duration > 0, start != origin else {
            window.setFrameOrigin(origin)
            completion()
            return
        }

        let startTime = timeProvider()
        let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self, weak window] timer in
            guard let self, let window else {
                timer.invalidate()
                return
            }
            let progress = min(1, (self.timeProvider() - startTime) / duration)
            let eased = Self.easeOutCubic(progress)
            window.setFrameOrigin(CGPoint(
                x: start.x + (origin.x - start.x) * eased,
                y: start.y + (origin.y - start.y) * eased
            ))
            guard progress >= 1 else { return }
            timer.invalidate()
            self.timer = nil
            completion()
        }
        // 拖拽 / 菜单追踪期间也要继续动
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    static func easeOutCubic(_ t: Double) -> CGFloat {
        let inverse = 1 - t
        return CGFloat(1 - inverse * inverse * inverse)
    }
}

final class MainQueueHideScheduler: HideScheduling {
    private var workItem: DispatchWorkItem?

    deinit {
        workItem?.cancel()
    }

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
