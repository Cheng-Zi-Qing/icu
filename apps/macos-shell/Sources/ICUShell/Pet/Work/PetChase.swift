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

    /// 一个来回里「往左跑、离原位 `offset`」是第几秒：往回跑的路上又开始搜时，从这儿接着追
    func elapsed(resumingAt offset: CGFloat) -> TimeInterval {
        let clamped = max(-leftRoom, min(offset, rightRoom))
        // 原位左边：第一段（往左）；右边：最后一段（从右头往左回原位）
        let distance = clamped <= 0 ? -clamped : 2 * leftRoom + rightRoom + (rightRoom - clamped)
        return TimeInterval(distance / Self.speed)
    }

    /// 从离原位 `offset` 的地方小跑回原位要多久
    static func returnDuration(from offset: CGFloat) -> TimeInterval {
        TimeInterval(abs(offset) / speed)
    }
}

/// 追球时把桌宠窗口左右来回挪；不追了就转身小跑回原位
final class PetChaseRunner {
    private static let framesPerSecond: Double = 30

    var onFacingChanged: ((Bool) -> Void)?
    /// 小跑回到原位了（被拎走时不会调）
    var onReturnedHome: (() -> Void)?
    private(set) var motion: PetChaseMotion?
    /// 正在追球
    var isRunning: Bool { home != nil && returnTrip == nil }
    /// 不追了，正在往原位跑
    var isReturning: Bool { returnTrip != nil }

    private weak var window: NSWindow?
    private let visibleFrame: (CGRect) -> CGRect?
    private let now: () -> TimeInterval
    private let startsTimer: Bool
    private var home: CGPoint?
    private var startedAt: TimeInterval = 0
    /// 往回跑：从离原位多远出发、什么时候出发
    private var returnTrip: (from: CGFloat, startedAt: TimeInterval)?
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

    /// 开始追；正在往回跑时从当前位置接着追，不先跳回原位
    func start() {
        guard !isRunning, let window else { return }
        if let home, let motion, returnTrip != nil {
            returnTrip = nil
            startedAt = now() - motion.elapsed(resumingAt: window.frame.minX - home.x)
        } else {
            let frame = window.frame
            let screen = visibleFrame(frame) ?? frame
            home = frame.origin
            motion = PetChaseMotion(leftRoom: frame.minX - screen.minX, rightRoom: screen.maxX - frame.maxX)
            startedAt = now()
        }
        facingRight = nil
        tick()
        startTimerIfNeeded()
    }

    func tick() {
        guard let home, let window else { return }
        if let returnTrip {
            tickReturn(returnTrip, home: home, window: window)
            return
        }
        guard let motion else { return }
        let position = motion.position(after: now() - startedAt)
        window.setFrameOrigin(CGPoint(x: (home.x + position.offset).rounded(), y: home.y))
        face(right: position.movingRight)
    }

    /// 不追了：转身小跑回原位（被拎走时 `returnHome` 为 false，留在手里）
    func stop(returnHome: Bool = true) {
        guard isRunning || isReturning else { return }
        guard returnHome, let home, let window else {
            finish()
            return
        }
        guard !isReturning else { return }
        let offset = window.frame.minX - home.x
        returnTrip = (offset, now())
        face(right: offset < 0)
        tick()
        startTimerIfNeeded()
    }

    private func tickReturn(_ trip: (from: CGFloat, startedAt: TimeInterval), home: CGPoint, window: NSWindow) {
        let duration = PetChaseMotion.returnDuration(from: trip.from)
        let progress = duration > 0 ? min(1, (now() - trip.startedAt) / duration) : 1
        guard progress < 1 else {
            window.setFrameOrigin(home)
            finish()
            onReturnedHome?()
            return
        }
        window.setFrameOrigin(CGPoint(x: (home.x + trip.from * CGFloat(1 - progress)).rounded(), y: home.y))
    }

    private func face(right: Bool) {
        guard right != facingRight else { return }
        facingRight = right
        onFacingChanged?(right)
    }

    private func startTimerIfNeeded() {
        guard startsTimer, timer == nil else { return }
        let timer = Timer(timeInterval: 1 / Self.framesPerSecond, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        home = nil
        motion = nil
        returnTrip = nil
        facingRight = nil
    }
}
