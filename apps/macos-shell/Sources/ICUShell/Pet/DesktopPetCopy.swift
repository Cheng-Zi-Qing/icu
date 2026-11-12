import Foundation

enum DesktopPetCopy {
    private static func text(_ key: String) -> String {
        TextCatalog.shared.text(key)
    }

    /// 状态条上平时的字：每种状态一组话，进这个状态时抽一句，待在这个状态里不换
    static func statusText(for state: ShellWorkState) -> String {
        switch state {
        case .idle:
            return PlayfulLines.workStatus.line(pool: WorkLinePool.idle.key, fallback: "pet.status_idle")
        case .working:
            return PlayfulLines.workStatus.line(pool: WorkLinePool.working.key, fallback: "pet.status_working")
        case .focus:
            return PlayfulLines.workStatus.line(pool: WorkLinePool.focus.key, fallback: "pet.status_focus")
        case .breakState:
            return PlayfulLines.workStatus.line(pool: WorkLinePool.breakTime.key, fallback: "pet.status_break")
        }
    }

    static func focusSuggestionMessage(for suggestion: FocusEndSuggestion?) -> String? {
        switch suggestion {
        case .light:
            return PlayfulLines.bubble.fresh(pool: BubbleLinePool.focusEndLight.key, fallback: "pet.focus_end_light")
        case .heavy:
            return PlayfulLines.bubble.fresh(pool: BubbleLinePool.focusEndHeavy.key, fallback: "pet.focus_end_heavy")
        case nil:
            return nil
        }
    }

    static func stopWorkMessage() -> String {
        PlayfulLines.bubble.fresh(pool: BubbleLinePool.stopWork.key, fallback: "pet.stop_work_message")
    }

    static func eyeReminderMessage() -> String {
        text("pet.eye_reminder")
    }

    static func hydrationReminderMessage() -> String {
        text("pet.hydration_reminder")
    }

}
