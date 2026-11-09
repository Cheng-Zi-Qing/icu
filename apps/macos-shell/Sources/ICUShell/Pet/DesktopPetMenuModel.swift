import Foundation

enum DesktopPetMenuAction: String, Equatable {
    case startWork
    case enterFocus
    case takeBreak
    case resumeWorking
    case stopWork
    case openWardrobe
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
        case .openWardrobe:
            return TextCatalog.shared.text(.menuOpenWardrobe)
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

    init(state: ShellWorkState, claudeConnection: Bool? = nil) {
        self.state = state
        self.claudeConnection = claudeConnection
    }

    var sections: [[DesktopPetMenuAction]] {
        let tools: [DesktopPetMenuAction] = [.openWardrobe, .openSettings] + claudeToggle
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
