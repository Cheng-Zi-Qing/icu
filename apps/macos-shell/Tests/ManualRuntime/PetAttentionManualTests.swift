import Foundation

// 打扰分级（02-响应设计）：L3 在等你 > L2 健康提醒 > L1 干完了 / 出错了 > L0 安静陪着。
// 同一时间只表现最高的一级，低的排队；你不在、全屏时除了 L3 都先压着

private func session(_ id: String, _ event: String, project: String? = nil, at: Double = 1) -> AgentSession? {
    var record: [String: Any] = ["v": 1, "session": id, "event": event, "at": at]
    record["project"] = project
    return AgentSession(record: record)
}

private func summary(_ kind: AgentSummary.Kind, _ lead: AgentSession?, count: Int = 1) -> AgentSummary {
    AgentSummary(kind: kind, count: count, lead: lead)
}

func testPetAttentionHoldsBackRemindersAndCelebrationsWhenTheyWouldInterrupt() throws {
    let free = PetAttentionContext()
    try expect(PetAttention.reminderMayShow(free) && PetAttention.celebrationMayPlay(free), "nothing in the way: both go")

    let waiting = PetAttentionContext(agentWaiting: true)
    try expect(!PetAttention.reminderMayShow(waiting), "a reminder waits while an agent waits for you (L3 beats L2)")

    let fullscreen = PetAttentionContext(fullscreen: true)
    try expect(!PetAttention.reminderMayShow(fullscreen) && !PetAttention.celebrationMayPlay(fullscreen), "fullscreen holds back everything below L3")

    let away = PetAttentionContext(userAway: true)
    try expect(!PetAttention.celebrationMayPlay(away), "no one to celebrate with while you are away")
    try expect(PetAttention.reminderWhileAway == .skip, "a reminder that comes due while you are away is skipped: you were resting anyway")

    let carded = PetAttentionContext(reminderShowing: true)
    try expect(!PetAttention.celebrationMayPlay(carded) && !PetAttention.reminderMayShow(carded), "a reminder card on screen holds back the lower levels")
}

func testAgentStageLoopsWaitingAndPlaysDoneOnceWhenItIsAllowed() throws {
    var stage = AgentStage.initial
    stage = stage.receiving(.working)
    try expect(stage.scene(work: .read) == .work(.read), "working: the work scene")

    stage = stage.receiving(.waiting)
    try expect(stage.scene(work: nil) == .waiting, "waiting: the waving loop, always (L3)")

    stage = stage.receiving(.done)
    try expect(stage.pending == .done && stage.scene(work: nil) == nil, "done is queued, not played yet")
    stage = stage.starting(allowed: false)
    try expect(stage.pending == .done && stage.playing == nil, "held back while not allowed")
    stage = stage.starting(allowed: true)
    try expect(stage.playing == .done && stage.pending == nil && stage.scene(work: nil) == .done, "played once allowed")
    stage = stage.finished(.done)
    try expect(stage.playing == nil && stage.scene(work: nil) == nil, "and back to idle when it ends")

    stage = stage.receiving(.failed).receiving(.waiting)
    try expect(stage.pending == nil && stage.scene(work: nil) == .waiting, "a new wait for you drops the queued celebration")

    stage = AgentStage.initial.receiving(.done).receiving(.idle)
    try expect(stage.pending == .done, "an acknowledged / timed out done still celebrates when you come back")
    stage = stage.receiving(.working)
    try expect(stage.pending == nil, "…unless the agent is already back at work")
}

func testAwayDigestSumsUpWhatHappenedWhileYouWereAway() throws {
    var digest = AwayDigest.empty
    try expect(digest.message == nil, "nothing happened: nothing to say")

    digest = digest.recording(summary(.working, session("a", "PreToolUse", project: "icu")))
    try expect(digest.message == nil, "work in progress is not news")

    digest = digest.recording(summary(.done, session("a", "Stop", project: "icu")))
    try expect(digest.message == "你不在时：icu 干完了", "one finished session (got \(digest.message ?? "nil"))")

    digest = digest.recording(summary(.failed, session("b", "StopFailure", project: "blog")))
    digest = digest.recording(summary(.done, session("a", "Stop", project: "icu", at: 5)))
    try expect(digest.message == "你不在时：blog 出错了，还有 1 件", "the most important one leads, the rest are counted (got \(digest.message ?? "nil"))")

    digest = digest.recording(summary(.waiting, session("c", "PermissionRequest"), count: 3))
    try expect(digest.message == "你不在时：Claude 在等你，还有 2 件", "waiting leads; three sessions in all (got \(digest.message ?? "nil"))")
}

func testAgentReminderCopyNudgesYouToMoveDuringLongTasks() throws {
    try expect(AgentReminderCopy.text(for: .eyeCare, agentWorkingFor: nil) == nil, "no agent: the usual copy")
    try expect(AgentReminderCopy.text(for: .hydration, agentWorkingFor: 60) == nil, "a short task: the usual copy")
    let eye = AgentReminderCopy.text(for: .eyeCare, agentWorkingFor: AgentReminderCopy.longTask)
    let water = AgentReminderCopy.text(for: .hydration, agentWorkingFor: AgentReminderCopy.longTask + 1)
    try expect(eye?.contains("Claude") == true && water?.contains("Claude") == true, "a long task: copy that says Claude is busy, go move (got \(eye ?? "nil"), \(water ?? "nil"))")
}

/// 全屏：前台 App 有一个普通层的窗口正好铺满某块屏幕（看视频、演示、全屏游戏）；不需要录屏权限
func testFullscreenDetectorSpotsAFrontmostWindowCoveringAScreen() throws {
    let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: -200, width: 1920, height: 1080)]
    let video = OnScreenWindow(ownerPID: 42, layer: 0, bounds: CGRect(x: 1512, y: -200, width: 1920, height: 1080))
    let maximized = OnScreenWindow(ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 33, width: 1512, height: 870))
    let menuBar = OnScreenWindow(ownerPID: 7, layer: 25, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982))
    let other = OnScreenWindow(ownerPID: 9, layer: 0, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982))

    try expect(FullscreenDetector.isFullscreen(frontmostPID: 42, windows: [maximized, video], screens: screens), "a window filling the second screen counts")
    try expect(!FullscreenDetector.isFullscreen(frontmostPID: 42, windows: [maximized], screens: screens), "a maximized window leaves the menu bar and Dock: not fullscreen")
    try expect(!FullscreenDetector.isFullscreen(frontmostPID: 42, windows: [maximized, menuBar, other], screens: screens), "only the frontmost app's normal windows count")
    try expect(!FullscreenDetector.isFullscreen(frontmostPID: nil, windows: [video], screens: screens), "no frontmost app: not fullscreen")
    let overlay = OnScreenWindow(ownerPID: 42, layer: 0, bounds: screens[0], alpha: 0)
    try expect(!FullscreenDetector.isFullscreen(frontmostPID: 42, windows: [overlay], screens: screens), "an invisible screen-sized overlay is not fullscreen")
}

@MainActor
private final class AttentionProbe {
    var clock: TimeInterval = 1000
    var reminders: [String] = []
    var withdrawn = 0
    var messages: [String] = []
    var stageChanges = 0
    lazy var coordinator: PetAttentionCoordinator = {
        let coordinator = PetAttentionCoordinator(now: { [unowned self] in self.clock }, schedulesRecheck: false)
        coordinator.onReminderReady = { [unowned self] in self.reminders.append($0.text) }
        coordinator.onReminderWithdrawn = { [unowned self] in self.withdrawn += 1 }
        coordinator.onDigest = { [unowned self] in self.messages.append($0) }
        coordinator.onStageChanged = { [unowned self] in self.stageChanges += 1 }
        return coordinator
    }()
}

private func reminder(_ type: HealthReminderType, _ text: String) -> ReminderPresentationPayload {
    ReminderPresentationPayload(id: UUID(), type: type, text: text)
}

@MainActor
func testPetAttentionCoordinatorQueuesRemindersBehindAWaitingAgent() throws {
    let probe = AttentionProbe()
    let attention = probe.coordinator

    attention.reminderDue(reminder(.hydration, "喝水"))
    try expect(probe.reminders == ["喝水"], "nothing in the way: shown")
    attention.agentChanged(summary(.waiting, session("a", "PermissionRequest")))
    try expect(probe.withdrawn == 1, "an agent waiting for you takes over from the reminder card")
    attention.reminderDue(reminder(.eyeCare, "看远处"))
    try expect(probe.reminders == ["喝水"], "and new reminders wait")

    attention.agentChanged(summary(.working, session("a", "PreToolUse")))
    try expect(probe.reminders == ["喝水", "喝水"], "once it stops waiting the first held reminder comes back (got \(probe.reminders))")
    attention.reminderClosed(attention.showingReminderID)
    try expect(probe.reminders == ["喝水", "喝水", "看远处"], "then the next one (got \(probe.reminders))")
    attention.reminderClosed(attention.showingReminderID)

    let stale = reminder(.hydration, "旧的")
    attention.reminderDue(reminder(.hydration, "喝水 2"))
    attention.reminderClosed(stale.id)
    attention.reminderDue(reminder(.eyeCare, "看远处 3"))
    try expect(probe.reminders.last == "喝水 2", "closing some other card does not free the slot of the one on screen (got \(probe.reminders))")
    attention.reminderClosed(attention.showingReminderID)
    try expect(probe.reminders.last == "看远处 3", "closing the one on screen does")
    attention.reminderClosed(attention.showingReminderID)

    let shownBefore = probe.reminders.count
    attention.fullscreenChanged(true)
    attention.reminderDue(reminder(.eyeCare, "看远处 2"))
    try expect(probe.reminders.count == shownBefore, "fullscreen holds reminders")
    attention.fullscreenChanged(false)
    try expect(probe.reminders.last == "看远处 2", "and lets them out after")
}

@MainActor
func testPetAttentionCoordinatorCelebratesWhenYouComeBackWithOneMessage() throws {
    let probe = AttentionProbe()
    let attention = probe.coordinator

    attention.userLeft()
    attention.reminderDue(reminder(.eyeCare, "看远处"))
    try expect(probe.reminders.isEmpty, "a reminder while you are away is skipped")
    attention.agentChanged(summary(.done, session("a", "Stop", project: "icu")))
    attention.agentChanged(summary(.failed, session("b", "StopFailure", project: "blog")))
    try expect(attention.stage.playing == nil && attention.stage.pending == .failed, "nothing plays while you are away; the latest one is queued")

    attention.userReturned()
    try expect(attention.stage.playing == .failed, "it plays when you come back")
    try expect(probe.messages == ["你不在时：blog 出错了，还有 1 件"], "one message for everything (got \(probe.messages))")
    attention.userReturned()
    try expect(probe.messages.count == 1, "no repeats")

    attention.sceneFinished(.failed)
    try expect(attention.stage.playing == nil, "back to idle after the one-shot")
}

@MainActor
func testPetAttentionCoordinatorUsesLongTaskCopyWhileClaudeWorks() throws {
    let probe = AttentionProbe()
    let attention = probe.coordinator
    attention.agentChanged(summary(.working, session("a", "PreToolUse")))
    attention.reminderDue(reminder(.hydration, "喝水"))
    attention.reminderClosed(attention.showingReminderID)
    probe.clock += AgentReminderCopy.longTask
    attention.agentChanged(summary(.working, session("a", "PostToolUse", at: 2)))
    attention.reminderDue(reminder(.hydration, "喝水"))
    try expect(probe.reminders.first == "喝水", "a short task keeps the usual copy")
    try expect(probe.reminders.last?.contains("Claude") == true, "a long task gets the go-move copy (got \(probe.reminders))")
}

func testAgentWaitCardSaysWhoWaitsAndWhatFor() throws {
    var record: [String: Any] = ["v": 1, "session": "a", "event": "PermissionRequest", "tool": "Bash", "at": 1.0, "project": "icu", "app": "com.mitchellh.ghostty"]
    let bash = AgentWaitCardContent(summary: summary(.waiting, AgentSession(record: record)))
    try expect(bash?.title == "icu 在等你" && bash?.detail == "回终端批准 Bash", "points you back to the terminal to approve, naming the tool (got \(String(describing: bash)))")
    try expect(bash?.titleName == "icu" && bash?.detailTool == "Bash", "the parts that may be cut to fit are kept apart from the fixed words")
    try expect(bash?.appBundleID == "com.mitchellh.ghostty", "knows which app to jump to")

    record["event"] = "Notification"
    record["kind"] = "elicitation_dialog"
    record["project"] = nil
    record["app"] = nil
    let question = AgentWaitCardContent(summary: summary(.waiting, AgentSession(record: record), count: 2))
    try expect(question?.title == "Claude 在等你 ×2" && question?.detail == "回终端回答问题", "no project: Claude; several: counted (got \(String(describing: question)))")
    try expect(question?.detailTool == nil, "a question names no tool")
    try expect(question?.appBundleID == nil, "no app known: nowhere to jump")

    try expect(AgentWaitCardContent(summary: summary(.done, session("a", "Stop"))) == nil, "only for waiting")
    record["event"] = "PermissionRequest"
    record["tool"] = "mcp__claude_ai_Claude_Docs__batch"
    try expect(AgentWaitCardContent(summary: summary(.waiting, AgentSession(record: record)))?.detail == "回终端批准 batch", "an MCP tool shows its action name")
}
