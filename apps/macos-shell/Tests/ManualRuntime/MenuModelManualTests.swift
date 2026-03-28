import Foundation

func testIdleMenuShowsStartWork() throws {
    let model = DesktopPetMenuModel(state: .idle)
    try expect(
        model.items == [.startWork, .changeAvatar, .openGenerationConfig, .closeWindow, .quitApp],
        "idle menu items should be flattened from themed sections"
    )
}

func testWorkingMenuShowsFocusAndBreakActions() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.items == [.enterFocus, .takeBreak, .stopWork, .changeAvatar, .openGenerationConfig, .closeWindow, .quitApp],
        "working menu items should be flattened from themed sections"
    )
}

func testPausedStatesShowResumeAction() throws {
    try expect(
        DesktopPetMenuModel(state: .focus).items == [.resumeWorking, .stopWork, .changeAvatar, .openGenerationConfig, .closeWindow, .quitApp],
        "focus menu items should be flattened from themed sections"
    )
    try expect(
        DesktopPetMenuModel(state: .breakState).items == [.resumeWorking, .stopWork, .changeAvatar, .openGenerationConfig, .closeWindow, .quitApp],
        "break menu items should be flattened from themed sections"
    )
}

func testIdleMenuShowsGenerationConfigEntryInUtilitySection() throws {
    let model = DesktopPetMenuModel(state: .idle)
    try expect(
        model.sections == [
            [.startWork],
            [.changeAvatar, .openGenerationConfig],
            [.closeWindow, .quitApp]
        ],
        "desktop menu should expose generation config as a themed-panel action"
    )
}

func testWorkingMenuSectionsStayGroupedForThemedPanel() throws {
    let model = DesktopPetMenuModel(state: .working)
    try expect(
        model.sections == [
            [.enterFocus, .takeBreak, .stopWork],
            [.changeAvatar, .openGenerationConfig],
            [.closeWindow, .quitApp]
        ],
        "working menu sections should remain grouped for the themed context panel"
    )
}

func testStatusItemMenuExposesGenerationConfig() throws {
    let model = StatusItemMenuModel()
    try expect(
        model.sections == [
            [.showPet, .changeAvatar, .openGenerationConfig],
            [.quitApp]
        ],
        "status item menu should expose native generation config entry"
    )
}

func testMenuActionTitlesCanBeOverriddenByTextCatalog() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "menu": {
            "show_pet": "显示桌宠",
            "change_avatar": "更换形象",
            "generation_config": "生成配置"
          }
        }
        """,
        overrideJSON: """
        {
          "menu": {
            "show_pet": "召唤桌宠",
            "change_avatar": "换个搭档",
            "generation_config": "模型设置"
          }
        }
        """
    )

    try expect(
        StatusItemMenuAction.showPet.title == "召唤桌宠",
        "status item menu title should come from the installed text catalog"
    )
    try expect(
        DesktopPetMenuAction.changeAvatar.title == "换个搭档",
        "desktop pet menu title should come from the installed text catalog"
    )
    try expect(
        DesktopPetMenuAction.openGenerationConfig.title == "模型设置",
        "generation config menu title should come from the installed text catalog"
    )
}
