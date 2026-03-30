import Foundation

enum InlineAvatarCreationStage: Equatable {
    case empty
    case drafted
    case previewReady
    case saving
}

struct InlineAvatarPreviewDraft: Equatable {
    var actionImageURLs: [String: URL]
    var suggestedPersona: String
}

struct InlineAvatarSaveRequest: Equatable {
    var name: String
    var persona: String
    var actionImageURLs: [String: URL]
}
