import Foundation

enum ShellWorkState: String, Codable {
    case idle
    case working
    case focus
    case breakState = "break"
}

enum FocusEndSuggestion: String, Codable {
    case light = "focus_end_light"
    case heavy = "focus_end_heavy"
}

struct PersistedRuntimeState: Codable, Equatable {
    var state: ShellWorkState
    var updatedAt: Date
    var workStartedAt: Date?
    var focusStartedAt: Date?
    var breakStartedAt: Date?
    var windowPlacement: SavedWindowPlacement?

    static func idle(
        now: Date = .now,
        windowPlacement: SavedWindowPlacement? = nil
    ) -> PersistedRuntimeState {
        PersistedRuntimeState(
            state: .idle,
            updatedAt: now,
            workStartedAt: nil,
            focusStartedAt: nil,
            breakStartedAt: nil,
            windowPlacement: windowPlacement
        )
    }
}
