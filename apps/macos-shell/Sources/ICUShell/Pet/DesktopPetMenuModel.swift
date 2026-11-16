import Foundation

enum DesktopPetMenuAction: String, Equatable {
    case startWork
    case enterFocus
    case takeBreak
    case resumeWorking
    case stopWork
    case showTodayReport
    case openWardrobe
    case openBackpack
    case openSettings
    case connectClaude
    case disconnectClaude
    case closeWindow
    case quitApp

    var title: String {
        switch self {
        case .startWork:
            return TextCatalog.shared.text(.menuStartWork)
        case .enterFocus:
            return TextCatalog.shared.text(.menuEnterFocus)
        case .takeBreak:
            return TextCatalog.shared.text(.menuTakeBreak)
        case .resumeWorking:
            return TextCatalog.shared.text(.menuResumeWorking)
        case .stopWork:
            return TextCatalog.shared.text(.menuStopWork)
        case .showTodayReport:
            return TextCatalog.shared.text(.menuTodayReport)
        case .openWardrobe:
            return TextCatalog.shared.text(.menuOpenWardrobe)
        case .openBackpack:
            return TextCatalog.shared.text(.menuOpenBackpack)
        case .openSettings:
            return TextCatalog.shared.text(.menuOpenSettings)
        case .connectClaude:
            return TextCatalog.shared.text(.menuConnectClaude)
        case .disconnectClaude:
            return TextCatalog.shared.text(.menuDisconnectClaude)
        case .closeWindow:
            return TextCatalog.shared.text(.menuHidePet)
        case .quitApp:
            return TextCatalog.shared.text(.menuQuitApp)
        }
    }
}

struct DesktopPetMenuModel: Equatable {
    let state: ShellWorkState
    /// Claude Code 接上了没有；nil = 没法接（找不到 icu-hook），菜单里不出现
    let claudeConnection: Bool?
    /// 掉落开着（`loot_enabled`）才有「背包」
    let showsBackpack: Bool

    init(state: ShellWorkState, claudeConnection: Bool? = nil, showsBackpack: Bool = false) {
        self.state = state
        self.claudeConnection = claudeConnection
        self.showsBackpack = showsBackpack
    }

    var sections: [[DesktopPetMenuAction]] {
        let backpack: [DesktopPetMenuAction] = showsBackpack ? [.openBackpack] : []
        let tools: [DesktopPetMenuAction] = [.showTodayReport, .openWardrobe] + backpack + [.openSettings] + claudeToggle
        switch state {
        case .idle:
            return [[.startWork], tools, [.closeWindow, .quitApp]]
        case .working:
            return [[.enterFocus, .takeBreak, .stopWork], tools, [.closeWindow, .quitApp]]
        case .focus, .breakState:
            return [[.resumeWorking, .stopWork], tools, [.closeWindow, .quitApp]]
        }
    }

    private var claudeToggle: [DesktopPetMenuAction] {
        claudeConnection.map { [$0 ? .disconnectClaude : .connectClaude] } ?? []
    }

    var items: [DesktopPetMenuAction] {
        sections.flatMap { $0 }
    }
}
