import Foundation

enum DesktopPetCopy {
    private static func text(_ key: String, fallback: String) -> String {
        TextCatalog.shared.text(key, fallback: fallback)
    }

    static func statusText(for state: ShellWorkState) -> String {
        switch state {
        case .idle:
            return text("pet.status_idle", fallback: "待机中")
        case .working:
            return text("pet.status_working", fallback: "工作中")
        case .focus:
            return text("pet.status_focus", fallback: "专注中")
        case .breakState:
            return text("pet.status_break", fallback: "暂离中")
        }
    }

    static func focusSuggestionMessage(for suggestion: FocusEndSuggestion?) -> String? {
        switch suggestion {
        case .light:
            return text("pet.focus_end_light", fallback: "抬头缓一缓，再接着做。")
        case .heavy:
            return text("pet.focus_end_heavy", fallback: "这一段够久了，先休息一下。")
        case nil:
            return nil
        }
    }

    static func stopWorkMessage() -> String {
        text("pet.stop_work_message", fallback: "收工，歇会儿。")
    }

    static func eyeReminderMessage() -> String {
        text("pet.eye_reminder", fallback: "看看远处，护护眼。")
    }

    static func hydrationReminderMessage() -> String {
        text("pet.hydration_reminder", fallback: "喝口水，慢慢来。")
    }

    static func reminderCompleteActionTitle() -> String {
        TextCatalog.shared.text(.petReminderCompleteAction)
    }

    static func reminderSnoozeActionTitle() -> String {
        TextCatalog.shared.text(.petReminderSnoozeAction)
    }

    static func reminderSkipActionTitle() -> String {
        TextCatalog.shared.text(.petReminderSkipAction)
    }

    static func healthReportComingSoonMessage() -> String {
        TextCatalog.shared.text(.petHealthReportComingSoon)
    }

    static func healthReportUnavailableMessage() -> String {
        TextCatalog.shared.text(.petHealthReportUnavailable)
    }
}
