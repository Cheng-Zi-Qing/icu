import Foundation

enum StatusItemMenuAction: String, Equatable {
    case showPet
    case showTodayReport
    case openWardrobe
    case openSettings
    case connectClaude
    case disconnectClaude
    case quitApp

    var title: String {
        switch self {
        case .showPet:
            return TextCatalog.shared.text(.menuShowPet)
        case .showTodayReport:
            return TextCatalog.shared.text(.menuTodayReport)
        case .openWardrobe:
            return TextCatalog.shared.text(.menuOpenWardrobe)
        case .openSettings:
            return TextCatalog.shared.text(.menuOpenSettings)
        case .connectClaude:
            return TextCatalog.shared.text(.menuConnectClaude)
        case .disconnectClaude:
            return TextCatalog.shared.text(.menuDisconnectClaude)
        case .quitApp:
            return TextCatalog.shared.text(.menuQuitApp)
        }
    }
}

struct StatusItemMenuModel: Equatable {
    /// Claude Code 接上了没有；nil = 没法接，菜单里不出现
    let claudeConnection: Bool?

    init(claudeConnection: Bool? = nil) {
        self.claudeConnection = claudeConnection
    }

    var sections: [[StatusItemMenuAction]] {
        let toggle: [StatusItemMenuAction] = claudeConnection.map { [$0 ? .disconnectClaude : .connectClaude] } ?? []
        return [[.showPet], [.showTodayReport, .openWardrobe, .openSettings] + toggle, [.quitApp]]
    }
}
