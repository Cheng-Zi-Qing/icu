import Foundation

/// 一段上班的打卡记录：几点上班、几点下班。一天点几次「我要上班」就有几段。
///
/// App 被强退 / 崩溃 / 断电时来不及下班打卡：上班期间每分钟记一次「还在上班」（`lastSeenAt`），
/// 下次打开时用它补上下班时刻，并标成「意外退出」，打卡记录不丢。不可变：改动都返回新值
struct WorkShift: Codable, Equatable {
    let clockInAt: Date
    /// 下班时刻；还在上班（或意外退出还没补上）时为 nil
    let clockOutAt: Date?
    /// 最后一次确认还在上班的时刻
    let lastSeenAt: Date
    /// 这段是 App 意外退出结束的，下班时刻是补的
    let endedUnexpectedly: Bool

    init(clockInAt: Date, clockOutAt: Date? = nil, lastSeenAt: Date? = nil, endedUnexpectedly: Bool = false) {
        self.clockInAt = clockInAt
        self.clockOutAt = clockOutAt
        self.lastSeenAt = lastSeenAt ?? clockOutAt ?? clockInAt
        self.endedUnexpectedly = endedUnexpectedly
    }

    var isOpen: Bool { clockOutAt == nil }

    /// 正常下班
    func clockingOut(at date: Date) -> WorkShift {
        let end = max(date, clockInAt)
        return WorkShift(clockInAt: clockInAt, clockOutAt: end, lastSeenAt: end)
    }

    /// 还在上班：记一下这一刻
    func seen(at date: Date) -> WorkShift {
        WorkShift(clockInAt: clockInAt, clockOutAt: clockOutAt, lastSeenAt: max(lastSeenAt, date), endedUnexpectedly: endedUnexpectedly)
    }

    /// 上次 App 意外退出、没下班：按最后一次确认还在上班的时刻补下班
    func closedAfterInterruption() -> WorkShift {
        WorkShift(clockInAt: clockInAt, clockOutAt: lastSeenAt, lastSeenAt: lastSeenAt, endedUnexpectedly: true)
    }
}
