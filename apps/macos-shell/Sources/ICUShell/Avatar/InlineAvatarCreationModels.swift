import Foundation

enum InlineAvatarCreation {
    static let requiredActions = ["idle", "working", "alert"]
}

enum InlineAvatarCreationStage: Equatable {
    case empty
    case drafted
    case previewReady
    case saving
}

enum AvatarStudioMode: Equatable {
    case browse
    case create
}

struct InlineAvatarPreviewDraft: Equatable {
    var actionImageURLs: [String: URL]
    var suggestedPersona: String

    var hasRequiredActionImages: Bool {
        InlineAvatarCreation.requiredActions.allSatisfy { actionImageURLs[$0] != nil }
    }
}

struct InlineAvatarSaveRequest: Equatable {
    var name: String
    var persona: String
    var actionImageURLs: [String: URL]
}
