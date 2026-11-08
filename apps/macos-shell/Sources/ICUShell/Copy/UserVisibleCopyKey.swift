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
    case petReminderCompleteAction = "pet.reminder_complete_action"
    case petReminderSnoozeAction = "pet.reminder_snooze_action"
    case petReminderSkipAction = "pet.reminder_skip_action"
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
        case .petReminderCompleteAction:
            return "已完成"
        case .petReminderSnoozeAction:
            return "稍后提醒"
        case .petReminderSkipAction:
            return "跳过"
        }
    }
}
