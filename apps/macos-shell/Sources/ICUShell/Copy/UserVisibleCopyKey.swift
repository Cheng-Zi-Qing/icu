import Foundation

enum UserVisibleCopyKey: String, CaseIterable {
    case menuShowPet = "menu.show_pet"
    case menuTodayReport = "menu.today_report"
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
        case .menuTodayReport:
            return "今日报告…"
        case .menuQuitApp:
            return "退出"
        case .menuStartWork:
            return "我要上班"
        case .menuEnterFocus:
            return "我要专注"
        case .menuTakeBreak:
            return "我离开一下"
        case .menuResumeWorking:
            return "我回来了"
        case .menuStopWork:
            return "我下班了"
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
