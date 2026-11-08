import Foundation

enum DesktopPetMenuAction: String, Equatable {
    case startWork
    case enterFocus
    case takeBreak
    case resumeWorking
    case stopWork
    case openWardrobe
    case openSettings
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
        case .closeWindow:
            return TextCatalog.shared.text(.menuHidePet)
        case .quitApp:
            return TextCatalog.shared.text(.menuQuitApp)
        }
    }
}

struct DesktopPetMenuModel: Equatable {
    let state: ShellWorkState

    var sections: [[DesktopPetMenuAction]] {
        switch state {
        case .idle:
            return [
                [.startWork],
                [.openWardrobe, .openSettings],
                [.closeWindow, .quitApp],
            ]
        case .working:
            return [
                [.enterFocus, .takeBreak, .stopWork],
                [.openWardrobe, .openSettings],
                [.closeWindow, .quitApp],
            ]
        case .focus, .breakState:
            return [
                [.resumeWorking, .stopWork],
                [.openWardrobe, .openSettings],
                [.closeWindow, .quitApp],
            ]
        }
    }

    var items: [DesktopPetMenuAction] {
        sections.flatMap { $0 }
    }
}
