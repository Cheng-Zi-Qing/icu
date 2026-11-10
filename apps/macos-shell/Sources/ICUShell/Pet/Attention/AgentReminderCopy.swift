import Foundation

/// 健康提醒和 Agent 联动：Claude 在跑长任务时，提醒换成「它在忙，你正好起来动动」
enum AgentReminderCopy {
    /// Agent 连续干活多久算长任务
    static let longTask: TimeInterval = 5 * 60

    /// - Parameter agentWorkingFor: Agent 已经连续干了多久；nil = 没在干活
    /// - Returns: 联动的文案；不是长任务时为 nil（用平时的文案）
    static func text(for type: HealthReminderType, agentWorkingFor: TimeInterval?) -> String? {
        guard let agentWorkingFor, agentWorkingFor >= longTask else { return nil }
        switch type {
        case .eyeCare: return "Claude 还在跑，起来走两步，看看远处"
        case .hydration: return "Claude 还要忙一阵，去倒杯水吧"
        }
    }
}
