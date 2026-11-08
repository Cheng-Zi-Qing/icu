import AppKit

/// 追球时窗口怎么跑：从原位先往左（水豚脸朝左），跑到头掉头，来回跑。
/// 左右能跑多远由屏幕边决定，没地方就原地跑。
struct PetChaseMotion: Equatable {
    /// 最远跑出去多少点
    static let maxRun: CGFloat = 60
    /// 每秒跑多少点
    static let speed: CGFloat = 55

    let leftRoom: CGFloat
    let rightRoom: CGFloat

    init(leftRoom: CGFloat, rightRoom: CGFloat) {
        self.leftRoom = max(0, min(leftRoom, Self.maxRun))
        self.rightRoom = max(0, min(rightRoom, Self.maxRun))
    }

    /// 跑一个来回（原位 → 左头 → 右头 → 原位）要多久
    var period: TimeInterval {
        TimeInterval(2 * (leftRoom + rightRoom) / Self.speed)
    }

    /// 开跑 `elapsed` 秒后：离原位多远（负数在左边），正在往哪边跑
    func position(after elapsed: TimeInterval) -> (offset: CGFloat, movingRight: Bool) {
        guard period > 0 else { return (0, false) }
        let distance = CGFloat(elapsed.truncatingRemainder(dividingBy: period)) * Self.speed
        // 一个来回的路程：往左 leftRoom → 往右 leftRoom + rightRoom → 往左 rightRoom
        if distance < leftRoom { return (-distance, false) }
        let backRight = distance - leftRoom
        if backRight < leftRoom + rightRoom { return (-leftRoom + backRight, true) }
        return (rightRoom - (backRight - leftRoom - rightRoom), false)
    }
}

/// 追球时把桌宠窗口左右来回挪；停下时回到原位
final class PetChaseRunner {
    private static let framesPerSecond: Double = 30

    var onFacingChanged: ((Bool) -> Void)?
    private(set) var motion: PetChaseMotion?
    var isRunning: Bool { home != nil }

    private weak var window: NSWindow?
    private let visibleFrame: (CGRect) -> CGRect?
    private let now: () -> TimeInterval
    private let startsTimer: Bool
    private var home: CGPoint?
    private var startedAt: TimeInterval = 0
    private var facingRight: Bool?
    private var timer: Timer?

    init(
        window: NSWindow,
        visibleFrame: @escaping (CGRect) -> CGRect? = PetEdgeDockController.visibleFrame(containing:),
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        startsTimer: Bool = true
    ) {
        self.window = window
        self.visibleFrame = visibleFrame
        self.now = now
        self.startsTimer = startsTimer
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard !isRunning, let window else { return }
        let frame = window.frame
        let screen = visibleFrame(frame) ?? frame
        home = frame.origin
        motion = PetChaseMotion(leftRoom: frame.minX - screen.minX, rightRoom: screen.maxX - frame.maxX)
        startedAt = now()
        facingRight = nil
        tick()
        guard startsTimer else { return }
        let timer = Timer(timeInterval: 1 / Self.framesPerSecond, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func tick() {
        guard let home, let motion, let window else { return }
        let position = motion.position(after: now() - startedAt)
        window.setFrameOrigin(CGPoint(x: (home.x + position.offset).rounded(), y: home.y))
        if position.movingRight != facingRight {
            facingRight = position.movingRight
            onFacingChanged?(position.movingRight)
        }
    }

    /// 不追了：回到原位（被拖走时 `returnHome` 为 false，留在手里）
    func stop(returnHome: Bool = true) {
        timer?.invalidate()
        timer = nil
        if returnHome, let home {
            window?.setFrameOrigin(home)
        }
        home = nil
        motion = nil
        facingRight = nil
    }
}
