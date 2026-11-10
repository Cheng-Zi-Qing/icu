import Foundation

/// 后台记使用时长（只记录，暂不拿来调任何数值）：你停顿了多久、Claude 一段连着干了多久。
/// 写不进去只打日志，不影响桌宠
@MainActor
final class UsageRecorder {
    private let log: UsageSampleLog
    /// 墙上时间（Unix 秒）：记录要按天清理，不能用开机时长
    private let now: () -> TimeInterval
    private var pauses = UserPauseRecorder()
    private var stretches = AgentStretchRecorder()

    init(log: UsageSampleLog, now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }) {
        self.log = log
        self.now = now
        do {
            try log.prune(olderThan: UsageSampleLog.keepFor, now: now())
        } catch {
            NSLog("[Usage] could not tidy \(log.fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// 桌宠每秒看一眼你多久没碰键盘鼠标，顺手交过来
    func userIdleChecked(_ idle: TimeInterval) {
        let (next, sample) = pauses.feeding(userIdle: idle, at: now())
        pauses = next
        sample.map(write)
    }

    func agentChanged(_ kind: AgentSummary.Kind) {
        let (next, sample) = stretches.receiving(kind, at: now())
        stretches = next
        sample.map(write)
    }

    private func write(_ sample: UsageSample) {
        do {
            try log.append(sample)
        } catch {
            NSLog("[Usage] could not write a usage sample: \(error.localizedDescription)")
        }
    }
}
