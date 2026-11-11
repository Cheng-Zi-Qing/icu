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

/// 屏幕中央那张提醒卡（和护眼全屏休息）上写什么：图标、随机俏皮标题、说明、随机按钮文字。和画法分开，方便单测
struct ReminderCardContent: Equatable {
    enum Symbol: Equatable {
        case drop
        case eye
    }

    /// 全屏休息的倒计时条分几格
    static let progressSegments = 20

    let symbol: Symbol
    let title: String
    /// 倒计时总长；喝水提醒为 0（不倒计时）
    let restSeconds: TimeInterval
    /// 主按钮：喝水是「我喝了」，护眼是「开始休息」（点了才开始全屏倒计时）
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
            guard !options.isEmpty else { return "" }
            return options[min(max(0, pick(options.count)), options.count - 1)]
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
        completeTitle = choose(payload.type == .eyeCare ? pool.start : pool.done)
        snoozeTitle = choose(ReminderQuips.later)
        skipTitle = choose(ReminderQuips.nope)
    }

    var showsCountdown: Bool { restSeconds > 0 }

    /// 点主按钮是不是先进全屏休息（护眼），而不是直接算完成（喝水）
    var startsRest: Bool { showsCountdown }

    /// 起身歇几分钟的那种休息（否则是看远处几十秒）
    var isLongRest: Bool { restSeconds >= 60 }

    /// 提醒卡上的一行说明。喝水：第几杯；护眼：要歇多久
    var summary: String {
        if let fixedDetail { return fixedDetail }
        return isLongRest
            ? TextCatalog.shared.format("reminder.eye_plan_minutes", Int((restSeconds / 60).rounded()))
            : TextCatalog.shared.format("reminder.eye_plan_seconds", Int(restSeconds.rounded()))
    }

    /// 说明下面那行小字：点了按钮会发生什么
    var hint: String {
        TextCatalog.shared.text(startsRest ? "reminder.card_hint_rest" : "reminder.card_hint_water")
    }

    /// 全屏休息时的大标题
    var restTitle: String {
        TextCatalog.shared.text(isLongRest ? "rest.title_stand_up" : "rest.title_look_away")
    }

    /// 跟着提醒做动作的场景
    var scene: PetScene { .remind(symbol == .drop ? .hydration : .eyeCare) }

    /// 全屏休息时的倒计时文字（喝水没有倒计时，还是第几杯）
    func detail(remaining: TimeInterval) -> String {
        if let fixedDetail { return fixedDetail }
        let seconds = max(0, Int(remaining.rounded(.up)))
        if isLongRest && seconds >= 60 {
            return TextCatalog.shared.format("reminder.remaining_clock", seconds / 60, seconds % 60)
        }
        return TextCatalog.shared.format("reminder.remaining_seconds", seconds)
    }

    /// 进度条还亮着几格：最后一格要等时间真到了才灭
    func remainingSegments(remaining: TimeInterval) -> Int {
        guard showsCountdown, remaining > 0 else { return 0 }
        let share = min(1, remaining / restSeconds)
        return Int((share * Double(Self.progressSegments)).rounded(.up))
    }

    private static func cupDetail(_ cups: CupProgress?) -> String {
        guard let cups else { return TextCatalog.shared.text("reminder.sip_slowly") }
        let next = cups.done + 1
        return next <= cups.goal
            ? TextCatalog.shared.format("reminder.cup_progress", next, cups.goal)
            : TextCatalog.shared.format("reminder.cup_over", next - cups.goal)
    }
}
