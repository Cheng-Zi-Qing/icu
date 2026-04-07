import Foundation

enum UserVisibleCopyKey: String {
    case commonApplyButton = "common.apply_button"
    case commonCloseButton = "common.close_button"
    case commonPreviewButton = "common.preview_button"
    case commonRegenerateButton = "common.regenerate_button"

    case menuShowPet = "menu.show_pet"
    case menuChangeAvatar = "menu.change_avatar"
    case menuGenerationConfig = "menu.generation_config"
    case menuQuitApp = "menu.quit_app"
    case menuStartWork = "menu.start_work"
    case menuEnterFocus = "menu.enter_focus"
    case menuTakeBreak = "menu.take_break"
    case menuResumeWorking = "menu.resume_working"
    case menuStopWork = "menu.stop_work"
    case menuHidePet = "menu.hide_pet"
    case menuHealthReport = "menu.health_report"
    case petReminderCompleteAction = "pet.reminder_complete_action"
    case petReminderSnoozeAction = "pet.reminder_snooze_action"
    case petReminderSkipAction = "pet.reminder_skip_action"

    case generationConfigWindowTitle = "generation_config.window_title"
    case generationConfigWindowSubtitle = "generation_config.window_subtitle"
    case generationConfigStatusText = "generation_config.status_text"
    case generationConfigTextDescriptionTabTitle = "generation_config.text_description_tab_title"
    case generationConfigAnimationAvatarTabTitle = "generation_config.animation_avatar_tab_title"
    case generationConfigCodeGenerationTabTitle = "generation_config.code_generation_tab_title"
    case generationConfigTextDescriptionDetail = "generation_config.text_description_detail"
    case generationConfigAnimationAvatarDetail = "generation_config.animation_avatar_detail"
    case generationConfigCodeGenerationDetail = "generation_config.code_generation_detail"
    case generationConfigBasicSectionTitle = "generation_config.basic_section_title"
    case generationConfigAdvancedSectionTitle = "generation_config.advanced_section_title"
    case generationConfigShowAdvancedButton = "generation_config.show_advanced_button"
    case generationConfigHideAdvancedButton = "generation_config.hide_advanced_button"
    case generationConfigBasicButton = "generation_config.basic_button"
    case generationConfigAdvancedButton = "generation_config.advanced_button"
    case generationConfigSaveButton = "generation_config.save_button"
    case generationConfigSaveSuccessStatus = "generation_config.save_success_status"
    case generationConfigDefaultConfigTitle = "generation_config.default_config_title"
    case generationConfigProviderLabel = "generation_config.provider_label"
    case generationConfigPresetLabel = "generation_config.preset_label"
    case generationConfigCustomModelLabel = "generation_config.custom_model_label"
    case generationConfigModelLabel = "generation_config.model_label"
    case generationConfigAPIKeyLabel = "generation_config.api_key_label"
    case generationConfigBaseURLLabel = "generation_config.base_url_label"
    case generationConfigHeadersLabel = "generation_config.headers_label"
    case generationConfigAuthLabel = "generation_config.auth_label"
    case generationConfigOptionsLabel = "generation_config.options_label"
    case generationConfigTestConnectionButton = "generation_config.test_connection_button"
    case generationConfigTestConnectionSuccessStatus = "generation_config.test_connection_success_status"
    case generationConfigTestConnectionFailureStatus = "generation_config.test_connection_failure_status"
    case generationConfigCustomizeButton = "generation_config.customize_button"
    case generationConfigRestoreDefaultButton = "generation_config.restore_default_button"
    case generationConfigAdvancedParamsButton = "generation_config.advanced_params_button"
    case generationConfigUsingDefaultState = "generation_config.using_default_state"
    case generationConfigCustomizedState = "generation_config.customized_state"
    case generationConfigProviderPlaceholder = "generation_config.provider_placeholder"
    case generationConfigAPIKeyPlaceholder = "generation_config.api_key_placeholder"
    case generationConfigModelPlaceholder = "generation_config.model_placeholder"
    case generationConfigBaseURLPlaceholder = "generation_config.base_url_placeholder"
    case generationConfigAuthPlaceholder = "generation_config.auth_placeholder"
    case generationConfigOptionsPlaceholder = "generation_config.options_placeholder"
    case generationConfigProviderOpenAITitle = "generation_config.provider_openai_title"
    case generationConfigProviderAnthropicTitle = "generation_config.provider_anthropic_title"
    case generationConfigProviderOllamaTitle = "generation_config.provider_ollama_title"
    case generationConfigProviderHuggingFaceTitle = "generation_config.provider_huggingface_title"
    case generationConfigProviderOpenAICompatibleTitle = "generation_config.provider_openai_compatible_title"
    case generationConfigProviderDefaultOpenAIHelper = "generation_config.provider_default_openai_helper"
    case generationConfigProviderDefaultAnthropicHelper = "generation_config.provider_default_anthropic_helper"
    case generationConfigProviderDefaultOllamaHelper = "generation_config.provider_default_ollama_helper"
    case generationConfigProviderDefaultHuggingFaceHelper = "generation_config.provider_default_huggingface_helper"
    case generationConfigProviderDefaultOpenAICompatibleHelper = "generation_config.provider_default_openai_compatible_helper"

    case themeStudioTabTitle = "theme_studio.tab_title"
    case speechStudioBubblePreviewTitle = "speech_studio.bubble_preview_title"

    case errorEmptyVibe = "errors.empty_vibe"
    case errorMissingCapabilityConfig = "errors.missing_capability_config"
    case errorUnsupportedProviderForTheme = "errors.unsupported_provider_for_theme"
    case errorUnsupportedProviderForCapability = "errors.unsupported_provider_for_capability"
    case errorInvalidBaseURL = "errors.invalid_base_url"
    case errorRequestFailed = "errors.request_failed"
    case errorInvalidResponse = "errors.invalid_response"
    case errorProviderReturnedError = "errors.provider_returned_error"
    case errorResponseMissingContent = "errors.response_missing_content"
    case errorBridgeCommandFailedPrefix = "errors.bridge_command_failed_prefix"
    case errorBridgeInvalidResponse = "errors.bridge_invalid_response"
    case errorInvalidJSONObject = "errors.invalid_json_object"
    case errorInvalidJSONValue = "errors.invalid_json_value"
}

extension UserVisibleCopyKey {
    var defaultValue: String {
        switch self {
        case .commonApplyButton:
            return "应用"
        case .commonCloseButton:
            return "关闭"
        case .commonPreviewButton:
            return "生成预览"
        case .commonRegenerateButton:
            return "重新生成"
        case .menuShowPet:
            return "显示桌宠"
        case .menuChangeAvatar:
            return "更换形象"
        case .menuGenerationConfig:
            return "生成配置"
        case .menuQuitApp:
            return "退出"
        case .menuStartWork:
            return "开始工作"
        case .menuEnterFocus:
            return "进入专注"
        case .menuTakeBreak:
            return "暂离"
        case .menuResumeWorking:
            return "回来工作"
        case .menuStopWork:
            return "下班"
        case .menuHidePet:
            return "隐藏桌宠"
        case .menuHealthReport:
            return "健康报告"
        case .petReminderCompleteAction:
            return "已完成"
        case .petReminderSnoozeAction:
            return "稍后提醒"
        case .petReminderSkipAction:
            return "跳过"
        case .generationConfigWindowTitle:
            return "模型工作台"
        case .generationConfigWindowSubtitle:
            return "这里只配模型；生成、预览、应用都在更换形象页。"
        case .generationConfigStatusText:
            return "这里只配置模型，不负责生成与应用。"
        case .generationConfigTextDescriptionTabTitle:
            return "文本描述"
        case .generationConfigAnimationAvatarTabTitle:
            return "动画形象"
        case .generationConfigCodeGenerationTabTitle:
            return "主题代码"
        case .generationConfigTextDescriptionDetail:
            return "负责把 prompt 转成结构化文字意图。"
        case .generationConfigAnimationAvatarDetail:
            return "负责生成桌宠形象与动作素材。"
        case .generationConfigCodeGenerationDetail:
            return "负责把文字意图转成主题草稿。"
        case .generationConfigBasicSectionTitle:
            return "基础配置"
        case .generationConfigAdvancedSectionTitle:
            return "高级设置"
        case .generationConfigShowAdvancedButton:
            return "显示高级设置"
        case .generationConfigHideAdvancedButton:
            return "隐藏高级设置"
        case .generationConfigBasicButton:
            return "基础"
        case .generationConfigAdvancedButton:
            return "高级"
        case .generationConfigSaveButton:
            return "保存"
        case .generationConfigSaveSuccessStatus:
            return "模型配置已保存。"
        case .generationConfigDefaultConfigTitle:
            return "Default Config"
        case .generationConfigProviderLabel:
            return "服务商"
        case .generationConfigPresetLabel:
            return "Preset"
        case .generationConfigCustomModelLabel:
            return "Custom Model"
        case .generationConfigModelLabel:
            return "模型"
        case .generationConfigAPIKeyLabel:
            return "API Key"
        case .generationConfigBaseURLLabel:
            return "Base URL"
        case .generationConfigHeadersLabel:
            return "Headers JSON"
        case .generationConfigAuthLabel:
            return "认证 JSON"
        case .generationConfigOptionsLabel:
            return "选项 JSON"
        case .generationConfigTestConnectionButton:
            return "Test Connection"
        case .generationConfigTestConnectionSuccessStatus:
            return "%@ connection succeeded."
        case .generationConfigTestConnectionFailureStatus:
            return "%@ connection failed: %@"
        case .generationConfigCustomizeButton:
            return "Customize"
        case .generationConfigRestoreDefaultButton:
            return "Restore Default"
        case .generationConfigAdvancedParamsButton:
            return "Advanced Params"
        case .generationConfigUsingDefaultState:
            return "Using Default Config"
        case .generationConfigCustomizedState:
            return "Customized"
        case .generationConfigProviderPlaceholder:
            return "provider，如 ollama / huggingface / openai-compatible"
        case .generationConfigAPIKeyPlaceholder:
            return "api_key"
        case .generationConfigModelPlaceholder:
            return "model"
        case .generationConfigBaseURLPlaceholder:
            return "base_url"
        case .generationConfigAuthPlaceholder:
            return "auth JSON，如 {\"api_key\":\"sk-xxx\"}"
        case .generationConfigOptionsPlaceholder:
            return "options JSON，如 {\"temperature\":0.7}"
        case .generationConfigProviderOpenAITitle:
            return "OpenAI"
        case .generationConfigProviderAnthropicTitle:
            return "Anthropic"
        case .generationConfigProviderOllamaTitle:
            return "Ollama"
        case .generationConfigProviderHuggingFaceTitle:
            return "HuggingFace"
        case .generationConfigProviderOpenAICompatibleTitle:
            return "OpenAI-Compatible"
        case .generationConfigProviderDefaultOpenAIHelper:
            return "Reuse one OpenAI key and base URL for text and code cards."
        case .generationConfigProviderDefaultAnthropicHelper:
            return "Set your Claude key once, then point supported cards at Anthropic."
        case .generationConfigProviderDefaultOllamaHelper:
            return "Use your local Ollama host defaults for on-device text and code models."
        case .generationConfigProviderDefaultHuggingFaceHelper:
            return "Store a shared HuggingFace token here for avatar-generation presets."
        case .generationConfigProviderDefaultOpenAICompatibleHelper:
            return "Use this for gateways and self-hosted endpoints that speak the OpenAI API."
        case .themeStudioTabTitle:
            return "主题风格"
        case .speechStudioBubblePreviewTitle:
            return "桌宠对话气泡预览"
        case .errorEmptyVibe:
            return "Please enter a vibe description before generating a theme."
        case .errorMissingCapabilityConfig:
            return "Generation capability '%@' is not configured."
        case .errorUnsupportedProviderForTheme:
            return "Provider '%@' is not supported for theme generation."
        case .errorUnsupportedProviderForCapability:
            return "Capability '%@' does not support provider '%@'."
        case .errorInvalidBaseURL:
            return "Invalid generation endpoint URL: %@"
        case .errorRequestFailed:
            return "Generation request failed: %@"
        case .errorInvalidResponse:
            return "Generation service returned invalid JSON: %@"
        case .errorProviderReturnedError:
            return "Generation provider returned an error: %@"
        case .errorResponseMissingContent:
            return "Generation provider response did not include JSON content: %@"
        case .errorBridgeCommandFailedPrefix:
            return "Bridge command failed"
        case .errorBridgeInvalidResponse:
            return "Bridge command returned invalid JSON"
        case .errorInvalidJSONObject:
            return "%@ 需要填写合法的 JSON 对象。"
        case .errorInvalidJSONValue:
            return "%@ 中的字段 '%@' 格式不正确。"
        }
    }
}
