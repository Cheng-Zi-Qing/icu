import Foundation

// 先只记录、不应用：你停顿了多久、Claude 一段连着干了多久。只记时长，不记内容，全在本机

func testPauseRecorderNotesPausesLongerThanTypingGaps() throws {
    var recorder = UserPauseRecorder()
    var samples: [UsageSample] = []
    func feed(_ idle: TimeInterval, at now: TimeInterval) {
        let (next, sample) = recorder.feeding(userIdle: idle, at: now)
        recorder = next
        if let sample { samples.append(sample) }
    }

    for second in 0..<5 { feed(Double(second), at: 100 + Double(second)) }
    feed(0.3, at: 105)
    try expect(samples.isEmpty, "a few seconds without input is just a typing gap")

    for second in stride(from: 0.0, through: 95, by: 1) { feed(second, at: 200 + second) }
    feed(0.5, at: 296)
    try expect(samples == [UsageSample(kind: .userPause, seconds: 95, endedAt: 296, ending: nil)], "a 95 s pause is noted once you move again (got \(samples))")
    feed(0.2, at: 297)
    try expect(samples.count == 1, "only once")
}

func testAgentStretchRecorderNotesHowLongClaudeWorkedAndHowItEnded() throws {
    var recorder = AgentStretchRecorder()
    var samples: [UsageSample] = []
    func feed(_ kind: AgentSummary.Kind, at now: TimeInterval) {
        let (next, sample) = recorder.receiving(kind, at: now)
        recorder = next
        if let sample { samples.append(sample) }
    }

    feed(.working, at: 10)
    feed(.working, at: 50)
    feed(.waiting, at: 70)
    feed(.working, at: 100)
    feed(.done, at: 400)
    feed(.idle, at: 500)
    try expect(samples == [
        UsageSample(kind: .agentStretch, seconds: 60, endedAt: 70, ending: "waiting"),
        UsageSample(kind: .agentStretch, seconds: 300, endedAt: 400, ending: "done"),
    ], "each stretch of work is noted with what ended it (got \(samples))")
}

func testUsageSampleLogAppendsAndKeepsOnlyRecentSamples() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-usage-\(UUID().uuidString)", isDirectory: true)
    let log = UsageSampleLog(directory: directory)
    let day: TimeInterval = 24 * 60 * 60
    let now: TimeInterval = 100 * day
    try log.append(UsageSample(kind: .userPause, seconds: 30, endedAt: now - 40 * day, ending: nil))
    try log.append(UsageSample(kind: .agentStretch, seconds: 300, endedAt: now - day, ending: "done"))
    try log.append(UsageSample(kind: .userPause, seconds: 120, endedAt: now, ending: nil))
    let all = try log.load()
    try expect(all.count == 3, "appended one per line")

    try log.prune(olderThan: UsageSampleLog.keepFor, now: now)
    let kept = try log.load()
    try expect(kept.map(\.seconds) == [300, 120], "samples older than 30 days are dropped (got \(kept))")

    let line = try String(contentsOf: log.fileURL, encoding: .utf8).split(separator: "\n").last.map(String.init) ?? ""
    try expect(line == #"{"at":8640000,"kind":"user_pause","seconds":120}"#, "a line holds only the kind, the duration and when (got \(line))")
}

@MainActor
func testUsageRecorderWritesPausesAndAgentStretchesToTheLog() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("icu-usage-\(UUID().uuidString)", isDirectory: true)
    let log = UsageSampleLog(directory: directory)
    var clock: TimeInterval = 1_000_000
    let recorder = UsageRecorder(log: log, now: { clock })

    recorder.agentChanged(.working)
    for _ in 0..<30 {
        clock += 1
        recorder.userIdleChecked(clock - 1_000_000)
    }
    recorder.userIdleChecked(0.4)
    recorder.agentChanged(.done)
    let samples = try log.load()
    try expect(samples.map(\.kind) == [.userPause, .agentStretch], "a pause and a stretch of work are written (got \(samples))")
    try expect(samples.last?.seconds == 30 && samples.last?.ending == "done", "with their lengths (got \(samples))")
}
