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

enum InlineAvatarCreationStep: Equatable {
    case promptAndPreview
    case metadataAndSave
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
