import Foundation

enum DesktopPetMenuAction: String, Equatable {
    case startWork
    case enterFocus
    case takeBreak
    case resumeWorking
    case stopWork
    case changeAvatar
    case openStudio
    case openGenerationConfig
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
        case .changeAvatar:
            return TextCatalog.shared.text(.menuChangeAvatar)
        case .openStudio:
            return TextCatalog.shared.text(.menuOpenStudio)
        case .openGenerationConfig:
            return TextCatalog.shared.text(.menuGenerationConfig)
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
                [.changeAvatar, .openStudio, .openGenerationConfig],
                [.closeWindow, .quitApp],
            ]
        case .working:
            return [
                [.enterFocus, .takeBreak, .stopWork],
                [.changeAvatar, .openStudio, .openGenerationConfig],
                [.closeWindow, .quitApp],
            ]
        case .focus, .breakState:
            return [
                [.resumeWorking, .stopWork],
                [.changeAvatar, .openStudio, .openGenerationConfig],
                [.closeWindow, .quitApp],
            ]
        }
    }

    var items: [DesktopPetMenuAction] {
        sections.flatMap { $0 }
    }
}
