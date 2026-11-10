import Foundation

/// 一条使用时长记录。只有种类、时长、结束时间（和 Agent 那段怎么结束的），不记任何内容。
/// 先攒着看分布，以后再用来调「多久算你不在」「多久算长任务」
struct UsageSample: Codable, Equatable {
    enum Kind: String, Codable {
        /// 你停下键盘鼠标多久（短于打字间隙的不记）
        case userPause = "user_pause"
        /// Claude 一段连着干了多久
        case agentStretch = "agent_stretch"
    }

    let kind: Kind
    let seconds: TimeInterval
    /// 结束时间（Unix 秒）
    let endedAt: TimeInterval
    /// Agent 那段怎么结束的：done / failed / waiting / idle
    let ending: String?

    init(kind: Kind, seconds: TimeInterval, endedAt: TimeInterval, ending: String?) {
        self.kind = kind
        self.seconds = seconds.rounded()
        self.endedAt = endedAt.rounded()
        self.ending = ending
    }

    private enum CodingKeys: String, CodingKey {
        case kind, seconds, ending
        case endedAt = "at"
    }
}

/// 看你停顿了多久：停够 `minimumPause` 秒、又动起来时记一条
struct UserPauseRecorder: Equatable {
    /// 更短的只是打字、想事情的间隙
    static let minimumPause: TimeInterval = 10
    /// 最近一次输入在这么短之前，就算又动起来了（和打盹的「回来了」一致）
    static let resumedIdle: TimeInterval = 2

    private var longestIdle: TimeInterval = 0

    func feeding(userIdle: TimeInterval, at now: TimeInterval) -> (UserPauseRecorder, UsageSample?) {
        guard userIdle < Self.resumedIdle else {
            var next = self
            next.longestIdle = max(longestIdle, userIdle)
            return (next, nil)
        }
        let sample = longestIdle >= Self.minimumPause
            ? UsageSample(kind: .userPause, seconds: longestIdle, endedAt: now, ending: nil)
            : nil
        return (UserPauseRecorder(), sample)
    }
}

/// 看 Claude 一段连着干了多久：从开始干活到不干了（干完、出错、等你、空闲）记一条
struct AgentStretchRecorder: Equatable {
    private var startedAt: TimeInterval?

    func receiving(_ kind: AgentSummary.Kind, at now: TimeInterval) -> (AgentStretchRecorder, UsageSample?) {
        var next = self
        if kind == .working {
            next.startedAt = startedAt ?? now
            return (next, nil)
        }
        guard let startedAt else { return (self, nil) }
        next.startedAt = nil
        return (next, UsageSample(kind: .agentStretch, seconds: now - startedAt, endedAt: now, ending: Self.name(of: kind)))
    }

    private static func name(of kind: AgentSummary.Kind) -> String {
        switch kind {
        case .idle: return "idle"
        case .working: return "working"
        case .done: return "done"
        case .failed: return "failed"
        case .waiting: return "waiting"
        }
    }
}

/// `state/usage_samples.jsonl`：一行一条，只往后追加；启动时清掉 30 天以前的
struct UsageSampleLog {
    static let keepFor: TimeInterval = 30 * 24 * 60 * 60

    let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("usage_samples.jsonl", isDirectory: false)
    }

    init(appPaths: AppPaths) {
        self.init(directory: appPaths.stateDirectory)
    }

    func append(_ sample: UsageSample) throws {
        var line = try Self.encoder.encode(sample)
        line.append(UInt8(ascii: "\n"))
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else {
            try manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try line.write(to: fileURL, options: .atomic)
            return
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    /// 读不懂的行跳过（比如写到一半断电）
    func load() throws -> [UsageSample] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return text.split(separator: "\n").compactMap { line in
            try? JSONDecoder().decode(UsageSample.self, from: Data(line.utf8))
        }
    }

    func prune(olderThan age: TimeInterval, now: TimeInterval) throws {
        let samples = try load()
        let kept = samples.filter { now - $0.endedAt <= age }
        guard kept.count != samples.count else { return }
        let lines = try kept.map { String(decoding: try Self.encoder.encode($0), as: UTF8.self) }
        try (lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n")).write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}
