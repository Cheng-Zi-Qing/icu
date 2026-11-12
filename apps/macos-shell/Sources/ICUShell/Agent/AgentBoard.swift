import Foundation

/// Agent 在等你什么
enum AgentWait: Equatable {
    /// 要你批准用某个工具（工具名可能没有）
    case permission(tool: String?)
    /// 在问你问题（MCP 表单、Agent 要你回话）
    case question
}

/// 一个会话在桌宠眼里的样子
enum AgentPhase: Equatable {
    case idle
    case working
    case waiting(AgentWait)
    case done
    /// API 出错（限流、过载……）；按 Esc 中断没有事件，只能靠超时回到待机
    case failed(reason: String?)
}

/// `agents/<会话>.json` 里的一条记录（由 icu-hook 写入，格式见 AgentHookEvent）
struct AgentSession: Equatable {
    static let supportedSchemaVersion = 1

    let id: String
    let source: String
    let project: String?
    let appBundleID: String?
    let phase: AgentPhase
    /// PreToolUse 之后、PostToolUse 之前：工具在跑（构建、测试可能很久都没有新事件）
    let isInTool: Bool
    /// 正在调用的工具（只有 PreToolUse 带），决定演哪个干活小场景
    let tool: String?
    let updatedAt: TimeInterval

    init?(record: Any?) {
        guard
            let root = record as? [String: Any],
            (root["v"] as? Int ?? 0) <= Self.supportedSchemaVersion,
            let id = root["session"] as? String, !id.isEmpty,
            let event = root["event"] as? String,
            let at = root["at"] as? TimeInterval,
            let phase = Self.phase(event: event, kind: root["kind"] as? String, tool: root["tool"] as? String, error: root["error"] as? String)
        else {
            return nil
        }
        self.id = id
        source = root["source"] as? String ?? "claude"
        project = root["project"] as? String
        appBundleID = root["app"] as? String
        self.phase = phase
        isInTool = event == "PreToolUse"
        tool = isInTool ? root["tool"] as? String : nil
        updatedAt = at
    }

    /// 考虑超时和「你已经回到那个终端」之后，现在该显示什么
    /// - 在等你：你回去了就算交给你，显示成在干活
    /// - 干完了 / 出错了：是提醒，你看到了就消失
    func effectivePhase(at now: TimeInterval, acknowledged: Bool) -> AgentPhase {
        let age = now - updatedAt
        switch phase {
        case .idle:
            return .idle
        case .working:
            return age > (isInTool ? AgentBoard.toolTimeout : AgentBoard.workingTimeout) ? .idle : .working
        case .waiting:
            if age > AgentBoard.waitingTimeout { return .idle }
            return acknowledged ? .working : phase
        case .done, .failed:
            return age > AgentBoard.settledTimeout || acknowledged ? .idle : phase
        }
    }

    /// 在干活时演哪个小场景；工具之间算在想。不在干活（等你、干完了……）就没有
    var activity: AgentActivity? {
        guard phase == .working else { return nil }
        return isInTool ? AgentActivity(tool: tool) : .think
    }

    /// 你回去看一眼就算处理了的状态
    var needsAttention: Bool {
        switch phase {
        case .waiting, .done, .failed: return true
        case .idle, .working: return false
        }
    }

    private static func phase(event: String, kind: String?, tool: String?, error: String?) -> AgentPhase? {
        switch event {
        case "SessionStart":
            return .idle
        case "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure":
            return .working
        case "PermissionRequest":
            return .waiting(.permission(tool: tool))
        case "Stop":
            return .done
        case "StopFailure":
            return .failed(reason: error)
        case "Notification":
            switch kind {
            case "permission_prompt": return .waiting(.permission(tool: nil))
            case "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input": return .waiting(.question)
            case "idle_prompt": return .done
            default: return nil
            }
        default:
            return nil
        }
    }
}

/// 所有会话合在一起：桌宠只表现最需要你关注的那一种（规则见 02-响应设计 · Agent 响应）
struct AgentBoard: Equatable {
    /// 思考中（两次事件之间）多久没动静算停了：按 Esc 中断不会发任何事件
    static let workingTimeout: TimeInterval = 10 * 60
    /// 工具在跑（构建、跑测试）时放宽
    static let toolTimeout: TimeInterval = 30 * 60
    /// 在等你：你走开了它也一直等，但总得有个头（会话可能被直接关掉）
    static let waitingTimeout: TimeInterval = 2 * 60 * 60
    /// 干完了 / 出错了显示多久
    static let settledTimeout: TimeInterval = 30 * 60

    let sessions: [AgentSession]
    /// 你已经切回去看过的会话（在等你 / 干完了 / 出错了）：会话 → 那条记录的时间。同一会话来了新事件就不算
    let acknowledged: [String: TimeInterval]

    init(sessions: [AgentSession], acknowledged: [String: TimeInterval] = [:]) {
        self.sessions = sessions
        self.acknowledged = acknowledged
    }

    func summary(at now: TimeInterval) -> AgentSummary {
        let shown = sessions.map { session in
            (session, AgentSummary.Kind(session.effectivePhase(at: now, acknowledged: isAcknowledged(session))))
        }
        guard let top = shown.map(\.1).max(), top != .idle else { return .idle }
        let leading = shown.filter { $0.1 == top }.map(\.0)
        return AgentSummary(kind: top, count: leading.count, lead: leading.max { $0.updatedAt < $1.updatedAt })
    }

    /// 你切到了某个 app：在那里等你的会话交给你了，干完 / 出错的提醒也算看到了
    func acknowledging(appBundleID: String) -> AgentBoard {
        let seen = sessions.filter { session in
            session.needsAttention && session.appBundleID == appBundleID
        }
        let added = Dictionary(seen.map { ($0.id, $0.updatedAt) }) { _, new in new }
        return AgentBoard(sessions: sessions, acknowledged: acknowledged.merging(added) { _, new in new })
    }

    /// 换上重新读到的会话；还对得上的「已经切回去」保留
    func replacing(sessions newSessions: [AgentSession]) -> AgentBoard {
        let kept = acknowledged.filter { id, at in newSessions.contains { $0.id == id && $0.updatedAt == at } }
        return AgentBoard(sessions: newSessions, acknowledged: kept)
    }

    private func isAcknowledged(_ session: AgentSession) -> Bool {
        acknowledged[session.id] == session.updatedAt
    }
}

/// 桌宠要表现的那一种状态，带数量和「领头」的会话（卡片、跳回去用它）
struct AgentSummary: Equatable {
    /// 从低到高：越往后越需要你
    enum Kind: Int, Comparable {
        case idle, working, done, failed, waiting

        init(_ phase: AgentPhase) {
            switch phase {
            case .idle: self = .idle
            case .working: self = .working
            case .done: self = .done
            case .failed: self = .failed
            case .waiting: self = .waiting
            }
        }

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static let idle = AgentSummary(kind: .idle, count: 0, lead: nil)

    let kind: Kind
    let count: Int
    let lead: AgentSession?

    /// 桌宠该演的干活小场景：只有「在干活」时才有，跟着最近那个会话
    var activity: AgentActivity? {
        guard kind == .working else { return nil }
        return lead?.activity ?? .think
    }

    /// 状态条上的字；nil = 不盖掉平时的状态
    var statusText: String? {
        switch kind {
        case .idle: return nil
        case .working: return AgentActivity.statusText(tool: lead?.tool)
        case .done:
            return count > 1
                ? TextCatalog.shared.format("agent.done_count", count)
                : PlayfulLines.agentStatus.line(pool: AgentLinePool.done.key, fallback: "agent.done")
        case .failed:
            return PlayfulLines.agentStatus.line(pool: AgentLinePool.failed.key, fallback: "agent.failed")
        case .waiting:
            return count > 1
                ? TextCatalog.shared.format("agent.waiting_count", count)
                : PlayfulLines.agentStatus.line(pool: AgentLinePool.waiting.key, fallback: "agent.waiting")
        }
    }
}
