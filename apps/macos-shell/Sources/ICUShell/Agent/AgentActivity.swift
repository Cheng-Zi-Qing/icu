import Foundation

/// Agent 正在干的那种活；rawValue 就是 `work/scenes.json` 里的场景名
enum AgentActivity: String, CaseIterable, Equatable {
    /// 在想（两次工具调用之间、还没调用工具）
    case think
    /// 读文件、打开网页：戴眼镜翻书
    case read
    /// 搜代码、搜网页：追球
    case search
    /// 改文件、新建文件：写字
    case write
    /// 跑命令：吃饭
    case eat
    /// 派子 Agent：放小鸟
    case delegate

    private static let byTool: [String: AgentActivity] = [
        "Read": .read, "WebFetch": .read, "NotebookRead": .read,
        "Grep": .search, "Glob": .search, "WebSearch": .search, "LS": .search, "ToolSearch": .search,
        "Edit": .write, "Write": .write, "MultiEdit": .write, "NotebookEdit": .write,
        "Bash": .eat, "BashOutput": .eat, "KillShell": .eat, "KillBash": .eat,
        "Task": .delegate, "Agent": .delegate,
    ]

    /// MCP 工具（`mcp__服务__动作`）按动作名里的词猜
    private static let mcpKeywords: [(words: [String], activity: AgentActivity)] = [
        (["search", "find", "query", "list"], .search),
        (["write", "edit", "create", "update", "delete", "add"], .write),
        (["read", "fetch", "get", "open", "view"], .read),
    ]

    /// 这种活在状态条上说什么：从一组俏皮话里抽（同一种活一直是同一句，换了活才换）
    var label: String {
        Self.line(for: pool)
    }

    /// 每种活对应的那组话（`agent.lines.*`），抽不到时退回老的单句 key
    private var pool: AgentLinePool {
        switch self {
        case .think: return .think
        case .read: return .read
        case .search: return .search
        case .write: return .update
        case .eat: return .bash
        case .delegate: return .delegate
        }
    }

    /// Claude Code 终端里有自己名字的工具，单独一组话
    private static let toolPools: [String: AgentLinePool] = [
        "Write": .write, "WebFetch": .fetch, "WebSearch": .webSearch,
    ]

    private static let fallbackKeys: [AgentLinePool: String] = [
        .think: "agent.activity_think", .read: "agent.activity_read", .search: "agent.activity_search",
        .update: "agent.activity_update", .bash: "agent.activity_bash", .delegate: "agent.activity_delegate",
        .write: "agent.activity_write", .fetch: "agent.activity_fetch", .webSearch: "agent.activity_web_search",
    ]

    private static func line(for pool: AgentLinePool) -> String {
        PlayfulLines.agentStatus.line(pool: pool.key, fallback: fallbackKeys[pool] ?? "agent.activity_think")
    }

    /// 状态条上的字：按工具挑那一组话；没调用工具就是在想
    static func statusText(tool: String?) -> String {
        if let tool, let pool = toolPools[tool] { return line(for: pool) }
        return AgentActivity(tool: tool).label
    }

    init(tool: String?) {
        guard let tool else {
            self = .think
            return
        }
        if let known = Self.byTool[tool] {
            self = known
            return
        }
        let action = tool.hasPrefix("mcp__") ? (tool.components(separatedBy: "__").last ?? "").lowercased() : ""
        self = Self.mcpKeywords.first { entry in entry.words.contains { action.contains($0) } }?.activity ?? .think
    }
}

/// 换场景要停够：像 Claude Code 转圈时那一个词，一段活儿里不老换。
/// Agent 常常一秒内连调好几个工具，工具之间还夹着一两秒的「在想」，每个都换会一直闪
struct AgentSceneHold: Equatable {
    /// 一段场景至少演多久
    static let minimumDuration: TimeInterval = 20
    /// 从干活换成「在想」：要一直在想这么久才换（工具之间的空档不算）
    static let thinkSettle: TimeInterval = 12
    static let none = AgentSceneHold(shown: nil, since: 0)

    /// 现在演的场景；nil = 没在演（在等你、干完了、没活）
    let shown: AgentActivity?
    /// 这个场景从什么时候开始演
    let since: TimeInterval
    /// Agent 现在其实在干的活、从什么时候开始干的（还没换上屏时用来算等多久）
    let wanted: AgentActivity?
    let wantedSince: TimeInterval

    init(shown: AgentActivity?, since: TimeInterval, wanted: AgentActivity? = nil, wantedSince: TimeInterval? = nil) {
        self.shown = shown
        self.since = since
        self.wanted = wanted ?? shown
        self.wantedSince = wantedSince ?? since
    }

    /// 想换成 `desired`：开始演、停下都马上；从一个场景换到另一个要等够 `minimumDuration`，
    /// 换成「在想」还要一直在想够 `thinkSettle`。没等够时返回还差几秒，到时候再问一次
    func updated(desired: AgentActivity?, at now: TimeInterval) -> (hold: AgentSceneHold, recheckAfter: TimeInterval?) {
        let wantedSince = desired == wanted ? self.wantedSince : now
        guard desired != shown else {
            return (AgentSceneHold(shown: shown, since: since), nil)
        }
        guard shown != nil, desired != nil else {
            return (AgentSceneHold(shown: desired, since: now), nil)
        }
        var ready = since + Self.minimumDuration
        if desired == .think {
            ready = max(ready, wantedSince + Self.thinkSettle)
        }
        guard now >= ready else {
            return (AgentSceneHold(shown: shown, since: since, wanted: desired, wantedSince: wantedSince), ready - now)
        }
        return (AgentSceneHold(shown: desired, since: now), nil)
    }
}
