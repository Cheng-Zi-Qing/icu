import Foundation

enum InlineAvatarCreation {
    static let requiredActions = ["idle", "working", "alert"]

    static func hasAllRequiredActions(in actionImageURLs: [String: URL]) -> Bool {
        requiredActions.allSatisfy { actionImageURLs[$0] != nil }
    }
}

enum InlineAvatarCreationStage: Equatable {
    case empty
    case drafted
    case previewReady
    case saving
}

struct InlineAvatarPreviewDraft: Equatable {
    var actionImageURLs: [String: URL]
    var suggestedPersona: String

    var hasRequiredActionImages: Bool {
        InlineAvatarCreation.hasAllRequiredActions(in: actionImageURLs)
    }
}

struct InlineAvatarSaveRequest: Equatable {
    var name: String
    var persona: String
    var actionImageURLs: [String: URL]
}
