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
                return text("errors.work_invalid_start_work", fallback: "当前状态下不能开始工作。")
            case "enterFocus":
                return text("errors.work_invalid_enter_focus", fallback: "只有在工作中才能进入专注。")
            case "takeBreak":
                return text("errors.work_invalid_take_break", fallback: "只有在工作中才能暂离。")
            case "resumeWorking":
                return text("errors.work_invalid_resume_working", fallback: "当前不需要恢复工作。")
            default:
                return text("errors.work_invalid_transition", fallback: "当前状态下不能执行这个操作。")
            }
        }
    }

    static func avatarMessage(for error: Error) -> String {
        guard let error = error as? AvatarBuilderBridgeError else {
            return error.localizedDescription
        }

        switch error {
        case let .executionFailed(command, details):
            switch command {
            case "load-avatars" where details == "no avatars found":
                return text("errors.avatar_no_avatars_available", fallback: "当前还没有可用形象，请先生成或导入一个形象。")
            case "load-avatars":
                return text("errors.avatar_load_avatars_failed", fallback: "暂时无法读取形象列表，请稍后再试。")
            case "list-image-models":
                return text("errors.avatar_list_models_failed", fallback: "暂时无法读取图像模型配置，请检查生成配置。")
            case "optimize-prompt":
                return text("errors.avatar_optimize_prompt_failed", fallback: "暂时无法优化提示词，请检查文本模型配置。")
            case "generate-image":
                return text("errors.avatar_generate_image_failed", fallback: "暂时无法生成形象动作，请检查图像模型配置或鉴权信息。")
            case "generate-persona":
                return text("errors.avatar_generate_persona_failed", fallback: "暂时无法生成人设，请检查文本模型配置。")
            default:
                return text("errors.avatar_bridge_operation_failed", fallback: "形象功能暂时不可用，请稍后再试。")
            }
        case .invalidResponse:
            return text("errors.avatar_bridge_invalid_response", fallback: "形象生成服务返回了无法识别的数据。")
        }
    }
}
