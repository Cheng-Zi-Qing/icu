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

    /// 这种活的通称，按 Claude Code 终端里的说法（Thinking、Read、Search、Update、Bash、子 Agent）
    var label: String {
        switch self {
        case .think: return "思考中"
        case .read: return "读取中"
        case .search: return "搜索中"
        case .write: return "更新中"
        case .eat: return "运行 Bash"
        case .delegate: return "子 Agent 运行中"
        }
    }

    /// Claude Code 终端里有自己名字的工具，状态条照着翻
    private static let toolLabels: [String: String] = [
        "Write": "写入中", "WebFetch": "抓取网页中", "WebSearch": "网页搜索中",
    ]

    /// 状态条上的字：和 Claude Code 终端里显示的工具名对得上；没调用工具就是「思考中」
    static func statusText(tool: String?) -> String {
        tool.flatMap { toolLabels[$0] } ?? AgentActivity(tool: tool).label
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

/// 换场景至少隔几秒：Agent 常常一秒内连调好几个工具，每个都换会一直闪
struct AgentSceneHold: Equatable {
    static let minimumDuration: TimeInterval = 3
    static let none = AgentSceneHold(shown: nil, since: 0)

    /// 现在演的场景；nil = 没在演（在等你、干完了、没活）
    let shown: AgentActivity?
    /// 这个场景从什么时候开始演
    let since: TimeInterval

    /// 想换成 `desired`：开始演、停下都马上；从一个场景换到另一个要等够 3 秒，
    /// 没等够时返回还差几秒，到时候再问一次
    func updated(desired: AgentActivity?, at now: TimeInterval) -> (hold: AgentSceneHold, recheckAfter: TimeInterval?) {
        guard desired != shown else { return (self, nil) }
        guard let current = shown, desired != nil, current != desired else {
            return (AgentSceneHold(shown: desired, since: now), nil)
        }
        let elapsed = now - since
        guard elapsed >= Self.minimumDuration else { return (self, Self.minimumDuration - elapsed) }
        return (AgentSceneHold(shown: desired, since: now), nil)
    }
}
