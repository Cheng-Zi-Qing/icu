import Foundation

func testIdleMenuShowsStartWork() throws {
    let model = DesktopPetMenuModel(state: .idle)
    try expect(
        model.items == [.startWork, .closeWindow, .quitApp],
        "idle menu items should be flattened from themed sections"
    )
}

func testWorkingMenuShowsFocusAndBreakActions() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.items == [.enterFocus, .takeBreak, .stopWork, .closeWindow, .quitApp],
        "working menu items should be flattened from themed sections"
    )
}

func testPausedStatesShowResumeAction() throws {
    try expect(
        DesktopPetMenuModel(state: .focus).items == [.resumeWorking, .stopWork, .closeWindow, .quitApp],
        "focus menu items should be flattened from themed sections"
    )
    try expect(
        DesktopPetMenuModel(state: .breakState).items == [.resumeWorking, .stopWork, .closeWindow, .quitApp],
        "break menu items should be flattened from themed sections"
    )
}

func testWorkingMenuSectionsStayGroupedForThemedPanel() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.sections == [
            [.enterFocus, .takeBreak, .stopWork],
            [.closeWindow, .quitApp]
        ],
        "working menu sections should remain grouped for the themed context panel"
    )
}

func testStatusItemMenuShowsPetAndQuit() throws {
    let model = StatusItemMenuModel()
    try expect(
        model.sections == [[.showPet], [.quitApp]],
        "status item menu should only keep show pet and quit"
    )
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
