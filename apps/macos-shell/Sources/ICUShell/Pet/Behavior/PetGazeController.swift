import AppKit

/// 每秒看 5 次鼠标在哪，按 PetGazeTracker 的判断让桌宠转身。读鼠标位置不需要任何权限。
final class PetGazeController {
    static let pollInterval: TimeInterval = 0.2

    /// 现在能不能转身：贴在左右屏幕边、探头、被拎着、打盹时不行
    var canTurn: () -> Bool = { true }

    private let bodyFrameOnScreen: () -> CGRect?
    private let isFacingRight: () -> Bool
    private let onTurn: (Bool) -> Void
    private let cursor: () -> CGPoint
    private let now: () -> TimeInterval
    private var tracker = PetGazeTracker()
    private var timer: Timer?

    init(
        bodyFrameOnScreen: @escaping () -> CGRect?,
        isFacingRight: @escaping () -> Bool,
        onTurn: @escaping (Bool) -> Void,
        cursor: @escaping () -> CGPoint = { NSEvent.mouseLocation },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        startsTimer: Bool = true
    ) {
        self.bodyFrameOnScreen = bodyFrameOnScreen
        self.isFacingRight = isFacingRight
        self.onTurn = onTurn
        self.cursor = cursor
        self.now = now
        guard startsTimer else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    func tick() {
        guard canTurn(), let body = bodyFrameOnScreen() else {
            tracker = tracker.paused()
            return
        }
        let (next, turn) = tracker.observing(cursor: cursor(), body: body, facingRight: isFacingRight(), at: now())
        tracker = next
        if let turn {
            onTurn(turn)
        }
    }
}
