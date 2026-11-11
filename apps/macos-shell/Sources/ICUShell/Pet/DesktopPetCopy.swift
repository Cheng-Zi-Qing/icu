import Foundation

enum DesktopPetCopy {
    private static func text(_ key: String) -> String {
        TextCatalog.shared.text(key)
    }

    static func statusText(for state: ShellWorkState) -> String {
        switch state {
        case .idle:
            return text("pet.status_idle")
        case .working:
            return text("pet.status_working")
        case .focus:
            return text("pet.status_focus")
        case .breakState:
            return text("pet.status_break")
        }
    }

    static func focusSuggestionMessage(for suggestion: FocusEndSuggestion?) -> String? {
        switch suggestion {
        case .light:
            return text("pet.focus_end_light")
        case .heavy:
            return text("pet.focus_end_heavy")
        case nil:
            return nil
        }
    }

    static func stopWorkMessage() -> String {
        text("pet.stop_work_message")
    }

    static func eyeReminderMessage() -> String {
        text("pet.eye_reminder")
    }

    static func hydrationReminderMessage() -> String {
        text("pet.hydration_reminder")
    }

}
