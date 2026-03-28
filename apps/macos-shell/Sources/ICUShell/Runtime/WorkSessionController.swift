import Foundation

enum WorkSessionError: Error, LocalizedError {
    case invalidTransition(from: ShellWorkState, attempted: String)

    var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, attempted):
            return "Invalid transition from \(from.rawValue) via \(attempted)"
        }
    }
}

final class WorkSessionController {
    private let store: StateStore
    private(set) var currentState: PersistedRuntimeState

    init(store: StateStore) throws {
        self.store = store
        self.currentState = try store.load()
    }

    var state: ShellWorkState {
        currentState.state
    }

    var savedWindowPlacement: SavedWindowPlacement? {
        currentState.windowPlacement
    }

    func startWork(now: Date = .now) throws {
        guard state == .idle else {
            throw WorkSessionError.invalidTransition(from: state, attempted: "startWork")
        }

        currentState = PersistedRuntimeState(
            state: .working,
            updatedAt: now,
            workStartedAt: now,
            focusStartedAt: nil,
            breakStartedAt: nil,
            windowPlacement: currentState.windowPlacement
        )
        try store.save(currentState)
    }

    func enterFocus(now: Date = .now) throws {
        guard state == .working else {
            throw WorkSessionError.invalidTransition(from: state, attempted: "enterFocus")
        }

        currentState.state = .focus
        currentState.updatedAt = now
        currentState.focusStartedAt = now
        currentState.breakStartedAt = nil
        try store.save(currentState)
    }

    func takeBreak(now: Date = .now) throws {
        guard state == .working else {
            throw WorkSessionError.invalidTransition(from: state, attempted: "takeBreak")
        }

        currentState.state = .breakState
        currentState.updatedAt = now
        currentState.breakStartedAt = now
        currentState.focusStartedAt = nil
        try store.save(currentState)
    }

    func resumeWorking(now: Date = .now) throws -> FocusEndSuggestion? {
        switch state {
        case .focus:
            let suggestion = focusEndSuggestion(now: now)
            currentState.state = .working
            currentState.updatedAt = now
            currentState.workStartedAt = now
            currentState.focusStartedAt = nil
            currentState.breakStartedAt = nil
            try store.save(currentState)
            return suggestion
        case .breakState:
            currentState.state = .working
            currentState.updatedAt = now
            currentState.workStartedAt = now
            currentState.breakStartedAt = nil
            currentState.focusStartedAt = nil
            try store.save(currentState)
            return nil
        default:
            throw WorkSessionError.invalidTransition(from: state, attempted: "resumeWorking")
        }
    }

    func stopWork(now: Date = .now) throws {
        currentState = PersistedRuntimeState.idle(
            now: now,
            windowPlacement: currentState.windowPlacement
        )
        try store.save(currentState)
    }

    func persistWindowPlacement(_ placement: SavedWindowPlacement, now: Date = .now) throws {
        currentState.windowPlacement = placement
        currentState.updatedAt = now
        try store.save(currentState)
    }

    private func focusEndSuggestion(now: Date) -> FocusEndSuggestion? {
        guard let focusStartedAt = currentState.focusStartedAt else {
            return nil
        }

        let duration = now.timeIntervalSince(focusStartedAt)
        if duration >= 3600 {
            return .heavy
        }
        if duration >= 1800 {
            return .light
        }
        return nil
    }
}
