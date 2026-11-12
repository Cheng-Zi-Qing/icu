import Foundation

/// 从一组俏皮话里挑一句（像 Claude Code 转圈时那串 Pondering… Noodling…，一组里随机换）。
///
/// 两种用法：
/// - `line`：状态条。每次刷新都会重新问，所以同一种情况一直给同一句，换了情况（或换了语言）才重新抽
/// - `fresh`：气泡。每次都抽新的
///
/// 两种都不会连着说同一句。池子在 `config/copy/` 里写成数组，空的时候退回 `fallback` 那个单句 key
final class PlayfulLines {
    /// 状态条上 Agent 的状态（在干什么活、在等你、干完了、出错了）
    static let agentStatus = PlayfulLines()
    /// 状态条上平时的状态（上班、专注、休息、发呆）
    static let workStatus = PlayfulLines()
    /// 状态条上另外画的演法、待机小动作自己那组话（见 SceneLinePool）
    static let sceneStatus = PlayfulLines()
    /// 冒在头上的气泡
    static let bubble = PlayfulLines()

    /// 状态条用的池子
    static let statusPools: [String] = AgentLinePool.allCases.map(\.key) + WorkLinePool.allCases.map(\.key)
        + SceneLinePool.allCases.map(\.key)
    /// 气泡用的池子
    static let bubblePools: [String] = BubbleLinePool.allCases.map(\.key)

    private var current: (pool: String, line: String)?
    private var lastSaid: String?
    private let roll: (Int) -> Int

    /// - Parameter roll: 给池子大小，返回下标（测试里固定）
    init(roll: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }) {
        self.roll = roll
    }

    func line(pool: String, fallback: String, catalog: TextCatalog = .shared) -> String {
        let lines = catalog.texts(pool)
        if let current, current.pool == pool, lines.contains(current.line) {
            return current.line
        }
        let next = pick(from: lines) ?? catalog.text(fallback)
        current = (pool, next)
        return next
    }

    func fresh(pool: String, fallback: String, catalog: TextCatalog = .shared) -> String {
        pick(from: catalog.texts(pool)) ?? catalog.text(fallback)
    }

    /// 抽一句，跳过刚说过的那句（池子只有一句时只能是它）
    private func pick(from lines: [String]) -> String? {
        let choices = lines.count > 1 ? lines.filter { $0 != lastSaid } : lines
        guard !choices.isEmpty else { return nil }
        let index = min(max(roll(choices.count), 0), choices.count - 1)
        let said = choices[index]
        lastSaid = said
        return said
    }
}

/// Agent 状态条的池子：`agent.lines.<name>`
enum AgentLinePool: String, CaseIterable {
    case think, read, search, update, bash, delegate, write, fetch, webSearch = "web_search"
    case waiting, done, failed

    var key: String { "agent.lines.\(rawValue)" }
}

/// 平时状态条的池子：`pet.lines.<name>`
enum WorkLinePool: String, CaseIterable {
    case idle, working, focus, breakTime = "break"

    var key: String { "pet.lines.\(rawValue)" }
}

/// 气泡的池子：桌宠自己说的在 `pet.lines.<name>`，跟 Claude 有关的在 `agent.lines.<name>`
enum BubbleLinePool: String, CaseIterable {
    case focusEndLight = "focus_end_light"
    case focusEndHeavy = "focus_end_heavy"
    case stopWork = "stop_work"
    case agentReminderEye = "reminder_eye"
    case agentReminderWater = "reminder_water"

    var key: String {
        switch self {
        case .focusEndLight, .focusEndHeavy, .stopWork: return "pet.lines.\(rawValue)"
        case .agentReminderEye, .agentReminderWater: return "agent.lines.\(rawValue)"
        }
    }
}
