import Foundation

enum StatusItemMenuAction: String, Equatable {
    case showPet
    case quitApp

    var title: String {
        switch self {
        case .showPet:
            return TextCatalog.shared.text(.menuShowPet)
        case .quitApp:
            return TextCatalog.shared.text(.menuQuitApp)
        }
    }
}

struct StatusItemMenuModel: Equatable {
    let sections: [[StatusItemMenuAction]] = [
        [.showPet],
        [.quitApp]
    ]
}
