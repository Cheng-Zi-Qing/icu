import Foundation

enum PetAnimationLoopMode: String, Codable, Equatable {
    case loop
    case once
}

struct PetAnimationDescriptor: Equatable {
    var stateID: String
    var variantID: String
    var frameURLs: [URL]
    var framesPerSecond: Double
    var loopMode: PetAnimationLoopMode
}
