import Foundation

final class PetAnimationPlayer {
    private(set) var frameURLs: [URL] = []
    private(set) var currentFrameIndex: Int = 0
    private var loopMode: PetAnimationLoopMode = .loop
    private var framesPerSecond: Double = 0

    func load(_ animation: PetAnimationDescriptor) -> URL? {
        frameURLs = animation.frameURLs
        currentFrameIndex = 0
        loopMode = animation.loopMode
        framesPerSecond = animation.framesPerSecond
        return currentFrameURL
    }

    func reset() {
        currentFrameIndex = 0
    }

    func clear() {
        frameURLs = []
        currentFrameIndex = 0
        loopMode = .loop
        framesPerSecond = 0
    }

    func advanceFrame() -> URL? {
        guard !frameURLs.isEmpty else {
            return nil
        }

        if frameURLs.count == 1 {
            currentFrameIndex = 0
            return frameURLs[0]
        }

        switch loopMode {
        case .loop:
            currentFrameIndex = (currentFrameIndex + 1) % frameURLs.count
        case .once:
            if currentFrameIndex < frameURLs.count - 1 {
                currentFrameIndex += 1
            }
        }

        return frameURLs[currentFrameIndex]
    }

    var currentFrameURL: URL? {
        guard !frameURLs.isEmpty else {
            return nil
        }
        let boundedIndex = min(max(currentFrameIndex, 0), frameURLs.count - 1)
        return frameURLs[boundedIndex]
    }

    var frameInterval: TimeInterval? {
        guard framesPerSecond > 0 else {
            return nil
        }
        return 1.0 / framesPerSecond
    }

    var shouldAnimate: Bool {
        frameURLs.count > 1
    }
}
