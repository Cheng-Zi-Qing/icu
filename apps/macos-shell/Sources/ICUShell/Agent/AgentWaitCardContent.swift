import Foundation

/// 在等你时头顶那张卡片上写什么：谁在等、等什么、能跳回哪个 App。
/// 桌宠上不批准、不回答：卡片太小，看不到改动和问题全文，在这里点同意等于盲签，所以只指路回终端。
///
/// 卡片很窄，字放不下时只截项目名、工具名（`titleName`、`detailTool`），固定的字（「在等你」「回终端批准」）完整留着
struct AgentWaitCardContent: Equatable {
    /// 项目名（没有就是 Claude），放不下时截它
    let titleName: String
    /// 跟在项目名后面、不截的部分：「在等你」，几个会话一起等时加「×N」
    let titleSuffix: String
    /// 副行开头、不截的部分：「回终端批准」「回终端回答问题」
    let detailLead: String
    /// 要批准的工具名，放不下时截它；在问问题时没有
    let detailTool: String?
    /// 跳过去时激活的 App；不知道是哪个时为 nil（不显示「跳过去」）
    let appBundleID: String?

    var title: String { "\(titleName) \(titleSuffix)" }
    var detail: String { detailTool.map { "\(detailLead) \($0)" } ?? detailLead }

    init?(summary: AgentSummary) {
        guard summary.kind == .waiting else { return nil }
        let lead = summary.lead
        titleName = lead?.project ?? "Claude"
        titleSuffix = summary.count > 1 ? "在等你 ×\(summary.count)" : "在等你"
        switch lead?.phase {
        case .waiting(.question):
            detailLead = "回终端回答问题"
            detailTool = nil
        case let .waiting(.permission(tool?)):
            detailLead = "回终端批准"
            detailTool = Self.displayName(of: tool)
        default:
            detailLead = "回终端批准"
            detailTool = nil
        }
        appBundleID = lead?.appBundleID
    }

    /// MCP 工具（`mcp__服务__动作`）只显示动作名
    private static func displayName(of tool: String) -> String {
        guard tool.hasPrefix("mcp__"), let action = tool.components(separatedBy: "__").last, !action.isEmpty else { return tool }
        return action
    }
}
