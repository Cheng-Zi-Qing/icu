import Foundation

/// 在等你时头顶那张卡片上写什么：谁在等、等什么、能跳回哪个 App
struct AgentWaitCardContent: Equatable {
    /// 卡片只有 124pt 宽，项目名太长就截短
    static let maxProjectLength = 10

    let title: String
    let detail: String
    /// 跳过去时激活的 App；不知道是哪个时为 nil（不显示「跳过去」）
    let appBundleID: String?

    init?(summary: AgentSummary) {
        guard summary.kind == .waiting else { return nil }
        let lead = summary.lead
        let name = Self.shortened(lead?.project ?? "Claude")
        title = summary.count > 1 ? "\(name) 在等你（\(summary.count) 个）" : "\(name) 在等你"
        detail = Self.detail(for: lead?.phase)
        appBundleID = lead?.appBundleID
    }

    private static func detail(for phase: AgentPhase?) -> String {
        switch phase {
        case let .waiting(.permission(tool?)):
            return "想用 \(tool)，等你批准"
        case .waiting(.question):
            return "在问你问题"
        default:
            return "等你批准"
        }
    }

    private static func shortened(_ name: String) -> String {
        name.count > maxProjectLength ? "\(name.prefix(maxProjectLength))…" : name
    }
}
