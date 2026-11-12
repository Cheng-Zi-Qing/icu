import Foundation

/// 你不在时 Agent 那边发生的事：回来时合成一句话（最要紧的一件 + 还有几件），只冒一次
struct AwayDigest: Equatable {
    struct Item: Equatable {
        let session: String
        let kind: AgentSummary.Kind
        let project: String?
    }

    static let empty = AwayDigest(items: [], largestCount: 0)

    /// 每个会话只记最后的样子，按发生先后排
    let items: [Item]
    /// 状态条上同一种状态最多时有几个（只知道领头的那个会话，其余的只知道数量）
    let largestCount: Int

    /// 记下一次 Agent 状态变化；在干活、没事不算新闻
    func recording(_ summary: AgentSummary) -> AwayDigest {
        guard summary.kind >= .done, let lead = summary.lead else { return self }
        let item = Item(session: lead.id, kind: summary.kind, project: lead.project)
        let others = items.filter { $0.session != lead.id }
        return AwayDigest(items: others + [item], largestCount: max(largestCount, summary.count))
    }

    var isEmpty: Bool { items.isEmpty }

    /// 回来时冒的那句话；没事发生时为 nil
    var message: String? {
        // 同样要紧时取最近的那件
        guard let top = items.reversed().max(by: { $0.kind < $1.kind }) else { return nil }
        let total = max(items.count, largestCount)
        let headline = TextCatalog.shared.format("digest.headline", top.project ?? "Claude", Self.verb(for: top.kind))
        return total > 1 ? TextCatalog.shared.format("digest.more", headline, total - 1) : headline
    }

    private static func verb(for kind: AgentSummary.Kind) -> String {
        switch kind {
        case .waiting: return TextCatalog.shared.text("digest.verb_waiting")
        case .failed: return TextCatalog.shared.text("digest.verb_failed")
        case .done, .working, .idle: return TextCatalog.shared.text("digest.verb_done")
        }
    }
}
