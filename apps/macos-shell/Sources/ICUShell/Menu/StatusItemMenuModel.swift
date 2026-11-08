import Foundation

enum StatusItemMenuAction: String, Equatable {
    case showPet
    case openWardrobe
    case openSettings
    case quitApp

    var title: String {
        switch self {
        case .showPet:
            return TextCatalog.shared.text(.menuShowPet)
        case .openWardrobe:
            return TextCatalog.shared.text(.menuOpenWardrobe)
        case .openSettings:
            return TextCatalog.shared.text(.menuOpenSettings)
        case .quitApp:
            return TextCatalog.shared.text(.menuQuitApp)
        }
    }
}

struct StatusItemMenuModel: Equatable {
    let sections: [[StatusItemMenuAction]] = [
        [.showPet],
        [.openWardrobe, .openSettings],
        [.quitApp]
    ]
}
