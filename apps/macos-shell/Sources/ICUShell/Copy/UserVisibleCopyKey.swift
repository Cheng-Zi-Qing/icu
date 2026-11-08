import Foundation

enum UserVisibleCopyKey: String {
    case menuShowPet = "menu.show_pet"
    case menuQuitApp = "menu.quit_app"
    case menuStartWork = "menu.start_work"
    case menuEnterFocus = "menu.enter_focus"
    case menuTakeBreak = "menu.take_break"
    case menuResumeWorking = "menu.resume_working"
    case menuStopWork = "menu.stop_work"
    case menuHidePet = "menu.hide_pet"
    case menuOpenSettings = "menu.open_settings"
    case menuOpenWardrobe = "menu.open_wardrobe"
    case menuConnectClaude = "menu.connect_claude"
    case menuDisconnectClaude = "menu.disconnect_claude"
}

extension UserVisibleCopyKey {
    var defaultValue: String {
        switch self {
        case .menuShowPet:
            return "显示桌宠"
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
        case .menuOpenSettings:
            return "设置…"
        case .menuOpenWardrobe:
            return "衣柜"
        case .menuConnectClaude:
            return "接入 Claude Code"
        case .menuDisconnectClaude:
            return "断开 Claude Code"
        }
    }
}
