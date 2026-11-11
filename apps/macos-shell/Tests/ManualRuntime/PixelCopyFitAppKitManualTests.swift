import AppKit

/// 英文比中文长：像素风的弹窗（今日报告、菜单顶上的今日、提醒卡、全屏休息、在等你的卡片、设置、衣柜）
/// 换成英文整个画一遍，一行字都不许比给它的框宽。画不下的句子会被截成「…」，这里把它们全列出来

private let fitRepoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private let fitMorning = Date(timeIntervalSince1970: 1_794_384_000)  // 2026-11-11 09:00 UTC

private func fitDay(
    work: Int, focus: Int = 0, rest: Int = 0, breaks: Int = 0,
    eye: HealthReminderCounts = .empty, cups: Int = 0, shown cupsShown: Int? = nil
) -> HealthDaySummary {
    HealthDaySummary(
        date: fitMorning, eyeReminder: eye,
        hydrationReminder: HealthReminderCounts(shown: cupsShown ?? cups, completed: cups, snoozed: 0, skipped: 0),
        workDuration: work, focusCount: focus > 0 ? 2 : 0, focusDuration: focus, breakCount: breaks, breakDuration: rest
    )
}

/// 报告里各种情况都走一遍：落后很多、加班、推迟很多次、一切都好、刚开工、逐段打卡（含意外退出）
private func sampleReportDays() -> [HealthDaySummary] {
    let snoozy = HealthReminderCounts(shown: 12, completed: 2, snoozed: 8, skipped: 2)
    let good = HealthReminderCounts(shown: 4, completed: 4, snoozed: 0, skipped: 0)
    var shifts = fitDay(work: 5 * 3600, breaks: 1, eye: good, cups: 3)
    shifts.shiftCount = 4
    shifts.firstClockInAt = fitMorning
    shifts.lastClockOutAt = fitMorning.addingTimeInterval(9 * 3600)
    shifts.shifts = [
        WorkShift(clockInAt: fitMorning, clockOutAt: fitMorning.addingTimeInterval(2 * 3600)),
        WorkShift(clockInAt: fitMorning.addingTimeInterval(10_000), clockOutAt: fitMorning.addingTimeInterval(14_000), endedUnexpectedly: true),
        WorkShift(clockInAt: fitMorning.addingTimeInterval(20_000)),
    ]
    return [
        fitDay(work: 11 * 3600 + 59 * 60, focus: 3 * 3600, rest: 600, breaks: 1, eye: snoozy, cups: 1, shown: 12),
        fitDay(work: 4 * 3600, rest: 1800, breaks: 3, eye: good, cups: 8),
        fitDay(work: 600),
        fitDay(work: 0),
        shifts,
    ]
}

private func sampleWeek() -> HealthWeekSummary {
    let start = fitMorning.addingTimeInterval(-2 * 86_400)
    let days = (0..<7).map { index -> HealthDaySummary in
        var day = fitDay(work: [6, 8, 4, 0, 0, 0, 0][index] * 3600)
        day.date = start.addingTimeInterval(Double(index) * 86_400)
        return day
    }
    return HealthWeekSummary(
        weekStartDate: start, weekEndExclusiveDate: start.addingTimeInterval(7 * 86_400),
        eyeReminder: .empty, eyeReminderCompletionRate: 0, hydrationReminder: .empty, hydrationReminderCompletionRate: 0,
        workDuration: 18 * 3600, focusCount: 0, focusDuration: 0, breakCount: 0, days: days
    )
}

@MainActor
private func draw(_ view: NSView) {
    view.layoutSubtreeIfNeeded()
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
    view.cacheDisplay(in: view.bounds, to: rep)
}

@MainActor
private func drawPixelPopups() throws {
    let lifetime = HealthLifetimeSummary(workedDayCount: 128, onDutyDuration: 1_234 * 3600 + 56 * 60)
    for day in sampleReportDays() {
        for isOnDuty in [false, true] {
            let content = TodayReportContent(
                day: day, lifetime: lifetime, cupsGoal: 14, workHours: 8, isOnDuty: isOnDuty, week: sampleWeek()
            )
            draw(MenuTodayReportView(content: content))
        }
        // 右键菜单 / 菜单栏菜单：顶上今日小结 + 每种状态下的按钮
        let summary = MenuTodaySummary(day: day, cupsGoal: 14)
        for state in [ShellWorkState.idle, .working, .focus, .breakState] {
            for connection in [true, false] {
                let sections = DesktopPetMenuModel(state: state, claudeConnection: connection).sections.map { actions in
                    ThemedMenuPanelSection(items: actions.map { ThemedMenuPanelItem(id: $0.rawValue, title: $0.title) })
                }
                draw(ThemedMenuPanel(sections: sections, summary: summary, onSelect: { _ in }))
            }
        }
        let statusSections = StatusItemMenuModel(claudeConnection: true).sections + StatusItemMenuModel(claudeConnection: false).sections
        draw(ThemedMenuPanel(
            sections: statusSections.map { actions in
                ThemedMenuPanelSection(items: actions.map { ThemedMenuPanelItem(id: "\($0)", title: $0.title) })
            },
            summary: summary,
            onSelect: { _ in }
        ))
    }

    let payloads = [
        ReminderPresentationPayload(id: UUID(), type: .hydration, text: "x"),
        ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 20),
        ReminderPresentationPayload(id: UUID(), type: .eyeCare, text: "x", restSeconds: 300),
    ]
    for payload in payloads {
        let content = ReminderCardContent(payload: payload, cups: CupProgress(done: 13, goal: 14))
        draw(ReminderStageView(content: content) { _ in nil })
        draw(EyeRestOverlayView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800), content: content) { _ in nil })
    }

    // 在等你的卡片：和 App 里一样挂在桌宠窗口上（卡片多宽由桌宠窗口定）；批准、提问（Yes / No 那种）、带不带「跳过去」都画
    let waits: [[String: Any]] = [
        ["event": "PermissionRequest", "tool": "Bash", "app": "com.example.term"],
        ["event": "PermissionRequest", "tool": "mcp__claude_ai_Claude_Docs__batch", "app": "com.example.term"],
        ["event": "PermissionRequest", "tool": "AskUserQuestion", "app": "com.example.term"],
        ["event": "Notification", "app": "com.example.term"],
        ["event": "PermissionRequest", "tool": "Bash"],
    ]
    for (index, wait) in waits.enumerated() {
        let record = wait.merging(["v": 1, "session": "s\(index)", "at": 1.0, "project": "icu"]) { mine, _ in mine }
        for count in [1, 3] {
            guard let content = AgentWaitCardContent(summary: AgentSummary(kind: .waiting, count: count, lead: AgentSession(record: record))) else { continue }
            let pet = DesktopPetView(frame: NSRect(origin: .zero, size: DesktopPetView.cardExpandedContentSize))
            pet.showWaitCard(content, onJump: { _ in }, onDismiss: {})
            draw(pet)
        }
    }

    for mode in EyeCareMode.allCases {
        let form = SettingsForm(profile: .default, timers: ReminderTimerSettings(eyeMode: mode))
        let settings = SettingsWindowController(form: form, decoration: nil) { _ in }
        if let view = settings.window?.contentView { draw(view) }
        settings.close()
    }

    let catalogURL = fitRepoRoot.appendingPathComponent("config/wardrobe.json")
    let catalog = WardrobeCatalog(jsonObject: try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)))
    let art = WardrobeArt(itemIcon: { _ in NSImage(size: NSSize(width: 16, height: 16)) }, preview: { _ in nil }, decoration: { _ in nil })
    let wardrobe = WardrobeWindowController(catalog: catalog, state: .initial(for: catalog), art: art) { _ in }
    if let view = wardrobe.window?.contentView { draw(view) }
    wardrobe.close()
}

@MainActor
func testEnglishCopyFitsEveryPixelPopup() throws {
    _ = try makeInstalledThemeManager()
    PixelFont.register(assetsDirectory: fitRepoRoot.appendingPathComponent("assets"))
    try expect(PixelFont.isAvailable, "measure with the real pixel font")
    let original = TextCatalog.shared
    defer {
        TextCatalog.installShared(original)
        PixelPaint.overflowObserver = nil
    }

    for language in [AppLanguage.chinese, .english] {
        TextCatalog.installShared(try TextCatalog.live(appPaths: nil, repoRootURL: fitRepoRoot, language: language))
        var overflows: [String: String] = [:]
        PixelPaint.overflowObserver = { text, width, room in
            overflows[text] = "'\(text)' needs \(Int(width.rounded(.up)))pt, has \(Int(room))pt"
        }
        try drawPixelPopups()
        try expect(overflows.isEmpty, "\(language) copy runs past its box:\n  " + overflows.values.sorted().joined(separator: "\n  "))
    }
}

func testPixelTextThatDoesNotFitIsCutWithAnEllipsis() throws {
    PixelFont.register(assetsDirectory: fitRepoRoot.appendingPathComponent("assets"))
    let font = PixelFont.font()
    let room = PixelPaint.textSize("Look far away", font: font).width
    let cut = PixelPaint.fitted("Look far away and rest your eyes", width: room, font: font)
    try expect(cut.hasSuffix("…") && cut.hasPrefix("Look far"), "too long: cut and end in … (got \(cut))")
    try expect(PixelPaint.textSize(cut, font: font).width <= room, "the cut text fits (got \(cut))")
    try expect(PixelPaint.fitted("Look far away", width: room, font: font) == "Look far away", "text that fits is left alone")
}

/// 桌宠头上的气泡：英文按词换行，比中文更容易多出一行。每句会冒在气泡里的话都得整句落在气泡里
@MainActor
func testEveryBubbleLineStaysInsideTheBubble() throws {
    _ = try makeInstalledThemeManager()
    PixelFont.register(assetsDirectory: fitRepoRoot.appendingPathComponent("assets"))
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }
    let bubblePrefixes = ["pet.", "agent.reminder", "poke.", "errors.", "digest.", "app.", "common.save_failed"]

    var spills: [String] = []
    for language in [AppLanguage.chinese, .english] {
        let catalog = try TextCatalog.live(appPaths: nil, repoRootURL: fitRepoRoot, language: language)
        TextCatalog.installShared(catalog)
        let view = DesktopPetView(frame: NSRect(origin: .zero, size: DesktopPetView.compactContentSize))
        let lines = catalog.keys.filter { key in bubblePrefixes.contains { key.hasPrefix($0) } }.map { catalog.text($0) }
        for line in Set(lines).sorted() {
            view.showTransientMessage(line)
            guard let label = allSubviews(in: view).compactMap({ $0 as? NSTextField })
                .first(where: { $0.identifier?.rawValue == "desktopPet.transientBubbleLabel" }),
                  let bubble = label.superview, let cell = label.cell else { throw TestFailure(message: "bubble label") }
            let needed = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: label.frame.width, height: 10_000))
            // 整句都画得下（不被截成「…」），而且标签在气泡里面
            let fits = needed.height <= label.frame.height + 0.5 && bubble.bounds.contains(label.frame)
            if !fits {
                spills.append("'\(line)' needs \(Int(needed.width))×\(Int(needed.height.rounded(.up))), label is \(Int(label.frame.width))×\(Int(label.frame.height))")
            }
        }
    }
    try expect(spills.isEmpty, "bubble lines do not fit the bubble:\n  " + spills.joined(separator: "\n  "))
}
