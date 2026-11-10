import Foundation

func testIdleMenuShowsStartWork() throws {
    let model = DesktopPetMenuModel(state: .idle)
    try expect(
        model.items == [.startWork, .showTodayReport, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "idle menu items should be flattened from themed sections"
    )
}

func testWorkingMenuShowsFocusAndBreakActions() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.items == [.enterFocus, .takeBreak, .stopWork, .showTodayReport, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "working menu items should be flattened from themed sections"
    )
}

func testPausedStatesShowResumeAction() throws {
    try expect(
        DesktopPetMenuModel(state: .focus).items == [.resumeWorking, .stopWork, .showTodayReport, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "focus menu items should be flattened from themed sections"
    )
    try expect(
        DesktopPetMenuModel(state: .breakState).items == [.resumeWorking, .stopWork, .showTodayReport, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "break menu items should be flattened from themed sections"
    )
}

func testWorkingMenuSectionsStayGroupedForThemedPanel() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.sections == [
            [.enterFocus, .takeBreak, .stopWork],
            [.showTodayReport, .openWardrobe, .openSettings],
            [.closeWindow, .quitApp]
        ],
        "working menu sections should remain grouped for the themed context panel"
    )
}

func testStatusItemMenuShowsPetAndQuit() throws {
    let model = StatusItemMenuModel()
    try expect(
        model.sections == [[.showPet], [.showTodayReport, .openWardrobe, .openSettings], [.quitApp]],
        "status item menu should keep show pet, today report, wardrobe, settings and quit"
    )
}

func testStatusItemMenuTitlesAreNotEmpty() throws {
    let actions: [StatusItemMenuAction] = [.showPet, .showTodayReport, .openWardrobe, .openSettings, .connectClaude, .disconnectClaude, .quitApp]
    try expect(actions.allSatisfy { !$0.title.isEmpty }, "every status item menu entry should have a title")
    try expect(StatusItemMenuAction.showTodayReport.title == "今日报告…", "the today report entry reads 今日报告…")
}

func testWardrobeMenuEntryIsCalledWardrobe() throws {
    try expect(UserVisibleCopyKey.menuOpenWardrobe.defaultValue == "衣柜", "the wardrobe entry reads 衣柜")
}

func testMenuActionTitlesCanBeOverriddenByTextCatalog() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: #"{ "menu": { "show_pet": "显示桌宠", "start_work": "开始工作" } }"#,
        overrideJSON: #"{ "menu": { "show_pet": "召唤桌宠", "start_work": "上工" } }"#
    )

    try expect(
        StatusItemMenuAction.showPet.title == "召唤桌宠",
        "status item menu title should come from the installed text catalog"
    )
    try expect(
        DesktopPetMenuAction.startWork.title == "上工",
        "desktop pet menu title should come from the installed text catalog"
    )
}

func testClaudeMenuEntryFollowsTheConnection() throws {
    try expect(
        DesktopPetMenuModel(state: .idle, claudeConnection: false).sections
            == [[.startWork], [.showTodayReport, .openWardrobe, .openSettings, .connectClaude], [.closeWindow, .quitApp]],
        "not connected: offer to connect Claude Code next to wardrobe and settings"
    )
    try expect(
        DesktopPetMenuModel(state: .working, claudeConnection: true).sections[1] == [.showTodayReport, .openWardrobe, .openSettings, .disconnectClaude],
        "connected: offer to disconnect"
    )
    try expect(
        StatusItemMenuModel(claudeConnection: false).sections == [[.showPet], [.showTodayReport, .openWardrobe, .openSettings, .connectClaude], [.quitApp]],
        "the menu bar menu offers it too"
    )
    try expect(StatusItemMenuModel(claudeConnection: true).sections[1].last == .disconnectClaude, "menu bar: disconnect when connected")
    try expect(DesktopPetMenuAction.connectClaude.title == "接入 Claude Code", "connect title")
    try expect(DesktopPetMenuAction.showTodayReport.title == "今日报告…", "the pet menu offers the today report too")
    try expect(StatusItemMenuAction.disconnectClaude.title == "断开 Claude Code", "disconnect title")
}
