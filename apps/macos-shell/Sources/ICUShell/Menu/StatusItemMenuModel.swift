import Foundation

enum StatusItemMenuAction: String, Equatable {
    case showPet
    case changeAvatar
    case openStudio
    case openGenerationConfig
    case quitApp

    var title: String {
        switch self {
        case .showPet:
            return TextCatalog.shared.text(.menuShowPet)
        case .changeAvatar:
            return TextCatalog.shared.text(.menuChangeAvatar)
        case .openStudio:
            return TextCatalog.shared.text(.menuOpenStudio)
        case .openGenerationConfig:
            return TextCatalog.shared.text(.menuGenerationConfig)
        case .quitApp:
            return TextCatalog.shared.text(.menuQuitApp)
        }
    }
}

struct StatusItemMenuModel: Equatable {
    let sections: [[StatusItemMenuAction]] = [
        [.showPet, .changeAvatar, .openStudio, .openGenerationConfig],
        [.quitApp]
    ]
}
