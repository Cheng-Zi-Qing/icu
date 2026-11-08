import Foundation

/// 今天喝了几杯 / 目标几杯（提醒卡上显示「第 x/y 杯」）
struct CupProgress: Equatable {
    let done: Int
    let goal: Int

    init(done: Int, goal: Int) {
        self.done = max(0, done)
        self.goal = max(1, goal)
    }

    init(summary: MenuTodaySummary) {
        self.init(done: summary.cupsDone, goal: summary.cupsGoal)
    }
}

/// 提醒卡上写什么：图标、随机俏皮标题、一行说明、随机按钮文字。和画法分开，方便单测
struct ReminderCardContent: Equatable {
    enum Symbol: Equatable {
        case drop
        case eye
    }

    static let progressSegments = 10

    let symbol: Symbol
    let title: String
    /// 倒计时总长；喝水提醒为 0（不倒计时）
    let restSeconds: TimeInterval
    let completeTitle: String
    let snoozeTitle: String
    let skipTitle: String
    private let fixedDetail: String?

    /// `pick(n)` 从 n 句里挑第几句；默认随机，测试里传固定值
    init(
        payload: ReminderPresentationPayload,
        cups: CupProgress?,
        pick: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) {
        func choose(_ options: [String]) -> String {
            options[min(max(0, pick(options.count)), options.count - 1)]
        }
        let pool: ReminderQuips.Pool
        switch payload.type {
        case .hydration:
            symbol = .drop
            pool = ReminderQuips.hydration
            restSeconds = 0
            fixedDetail = Self.cupDetail(cups)
        case .eyeCare:
            symbol = .eye
            pool = payload.restSeconds >= 60 ? ReminderQuips.standUp : ReminderQuips.lookAway
            restSeconds = max(1, payload.restSeconds)
            fixedDetail = nil
        }
        title = choose(pool.lines)
        completeTitle = choose(pool.done)
        snoozeTitle = choose(ReminderQuips.later)
        skipTitle = choose(ReminderQuips.nope)
    }

    var showsCountdown: Bool { restSeconds > 0 }

    /// 喝水：第几杯；护眼：还剩多久
    func detail(remaining: TimeInterval) -> String {
        if let fixedDetail { return fixedDetail }
        let seconds = max(0, Int(remaining.rounded(.up)))
        if restSeconds >= 60 && seconds >= 60 {
            return String(format: "还剩 %d:%02d", seconds / 60, seconds % 60)
        }
        return "还剩 \(seconds) 秒"
    }

    /// 进度条还亮着几格：最后一格要等时间真到了才灭
    func remainingSegments(remaining: TimeInterval) -> Int {
        guard showsCountdown, remaining > 0 else { return 0 }
        let share = min(1, remaining / restSeconds)
        return Int((share * Double(Self.progressSegments)).rounded(.up))
    }

    private static func cupDetail(_ cups: CupProgress?) -> String {
        guard let cups else { return "小口慢慢喝" }
        let next = cups.done + 1
        return next <= cups.goal ? "第 \(next)/\(cups.goal) 杯" : "超额 \(next - cups.goal) 杯"
    }
}
