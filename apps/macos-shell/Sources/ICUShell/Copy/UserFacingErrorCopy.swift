import Foundation

enum UserFacingErrorCopy {
    private static func text(_ key: String, fallback: String) -> String {
        TextCatalog.shared.text(key, fallback: fallback)
    }

    static func desktopPetMessage(for error: Error) -> String {
        guard let error = error as? WorkSessionError else {
            return error.localizedDescription
        }

        switch error {
        case let .invalidTransition(_, attempted):
            switch attempted {
            case "startWork":
                return text("errors.work_invalid_start_work", fallback: "已经在上班了。")
            case "enterFocus":
                return text("errors.work_invalid_enter_focus", fallback: "先点「我要上班」，才能专注。")
            case "takeBreak":
                return text("errors.work_invalid_take_break", fallback: "还没上班，不用离开。")
            case "resumeWorking":
                return text("errors.work_invalid_resume_working", fallback: "当前不需要恢复工作。")
            default:
                return text("errors.work_invalid_transition", fallback: "当前状态下不能执行这个操作。")
            }
        }
    }
}
