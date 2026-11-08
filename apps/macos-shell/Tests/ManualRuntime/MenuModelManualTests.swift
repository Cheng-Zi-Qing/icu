import Foundation

func testIdleMenuShowsStartWork() throws {
    let model = DesktopPetMenuModel(state: .idle)
    try expect(
        model.items == [.startWork, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "idle menu items should be flattened from themed sections"
    )
}

func testWorkingMenuShowsFocusAndBreakActions() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.items == [.enterFocus, .takeBreak, .stopWork, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "working menu items should be flattened from themed sections"
    )
}

func testPausedStatesShowResumeAction() throws {
    try expect(
        DesktopPetMenuModel(state: .focus).items == [.resumeWorking, .stopWork, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "focus menu items should be flattened from themed sections"
    )
    try expect(
        DesktopPetMenuModel(state: .breakState).items == [.resumeWorking, .stopWork, .openWardrobe, .openSettings, .closeWindow, .quitApp],
        "break menu items should be flattened from themed sections"
    )
}

func testWorkingMenuSectionsStayGroupedForThemedPanel() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.sections == [
            [.enterFocus, .takeBreak, .stopWork],
            [.openWardrobe, .openSettings],
            [.closeWindow, .quitApp]
        ],
        "working menu sections should remain grouped for the themed context panel"
    )
}

func testStatusItemMenuShowsPetAndQuit() throws {
    let model = StatusItemMenuModel()
    try expect(
        model.sections == [[.showPet], [.openWardrobe, .openSettings], [.quitApp]],
        "status item menu should keep show pet, wardrobe, settings and quit"
    )
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
