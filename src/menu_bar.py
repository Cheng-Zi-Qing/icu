"""Menu Bar UI 模块"""
import rumps
from src.state_machine import HealthStateMachine
from src.reminder import ReminderManager
from src.hydration import HydrationCalculator
from src.database import Database
from src.report_generator import ReportGenerator
from src.state_sync import StateSync


class ICUMenuBar(rumps.App):
    """I.C.U. Menu Bar 应用"""

    def __init__(self):
        super().__init__("I.C.U.", "🛌")
        self.db = Database()
        self.hydration_calc = HydrationCalculator()
        self.fsm = HealthStateMachine()
        self.reminder = ReminderManager(self.db, self.hydration_calc)
        self.report = ReportGenerator(self.db)
        self.state_sync = StateSync()
        self.update_menu()

    def update_menu(self):
        """根据状态更新菜单"""
        self.menu.clear()

        if self.fsm.state == 'idle':
            self.menu = ["开始工作", None, "更换形象", "个人设置", "AI 配置", "退出"]
        elif self.fsm.state == 'working':
            self.menu = ["进入专注", "暂离", "下班", None, "更换形象", "个人设置", "AI 配置", "退出"]
        elif self.fsm.state in ['focus', 'break']:
            self.menu = ["回来工作", "下班", None, "更换形象", "个人设置", "AI 配置", "退出"]

    @rumps.clicked("开始工作")
    def start_work(self, _):
        self.fsm.start_work()
        self.reminder.start_reminders()
        self.state_sync.write_state('working', {'work_start_time': self.fsm.work_start_time})
        self.icon = "💻"
        self.update_menu()

    @rumps.clicked("进入专注")
    def enter_focus(self, _):
        self.fsm.enter_focus()
        self.reminder.pause_reminders()
        self.state_sync.write_state('focus', {'focus_count': self.fsm.focus_count})
        self.icon = "🔕"
        self.update_menu()

    @rumps.clicked("回来工作")
    def resume_work(self, _):
        if self.fsm.state == 'focus':
            self.fsm.exit_focus()
        else:
            self.fsm.resume_work()
        self.reminder.resume_reminders()
        self.state_sync.write_state('working')
        self.icon = "💻"
        self.update_menu()

    @rumps.clicked("暂离")
    def take_break(self, _):
        self.fsm.take_break()
        self.reminder.pause_reminders()
        self.state_sync.write_state('break')
        self.icon = "☕"
        self.update_menu()

    @rumps.clicked("下班")
    def stop_work(self, _):
        self.fsm.stop_work()
        self.reminder.stop_reminders()
        self.state_sync.write_state('idle')
        self.icon = "🛌"

        # 显示每日报告
        self.show_daily_report()

        self.update_menu()

    def quit_application(self, _=None):
        """退出应用"""
        self.reminder.stop_reminders()
        self.state_sync.write_state('quit')
        rumps.quit_application()

    @rumps.clicked("更换形象")
    def change_avatar(self, _):
        """更换形象"""
        import json
        import subprocess
        from src.avatar_manager import AvatarManager
        from src.avatar_selector import AvatarSelector
        from PySide6.QtWidgets import QApplication
        import sys

        # 创建临时 QApplication
        app = QApplication.instance() or QApplication(sys.argv)

        # 读取当前形象
        with open('config/settings.json', 'r') as f:
            config = json.load(f)
        current_id = config.get('avatar', {}).get('current_id', 'seal')

        # 显示选择器
        manager = AvatarManager()
        selector = AvatarSelector(manager, current_id)

        if selector.exec():
            # 保存选择
            config['avatar']['current_id'] = selector.selected_id
            with open('config/settings.json', 'w') as f:
                json.dump(config, f, indent=2)

            # 重启桌宠进程
            subprocess.run(['pkill', '-f', 'src.pet_main'])
            subprocess.Popen(['python3', '-m', 'src.pet_main'])

    def show_daily_report(self):
        """显示每日报告"""
        from src.daily_report import DailyReportDialog
        from PySide6.QtWidgets import QApplication
        import sys
        
        # 获取今日统计
        stats = self.fsm.daily_stats.get_today_stats()
        
        # 创建 Qt 应用（如果不存在）
        app = QApplication.instance()
        if app is None:
            app = QApplication(sys.argv)
        
        # 显示报告对话框
        dialog = DailyReportDialog(stats)
        dialog.exec()

    @rumps.clicked("个人设置")
    def open_user_config(self, _):
        """打开个人设置"""
        from src.user_config_dialog import UserConfigDialog
        from PySide6.QtWidgets import QApplication
        import sys

        app = QApplication.instance() or QApplication(sys.argv)
        dialog = UserConfigDialog()
        if dialog.exec():
            # 重新加载配置
            import json
            with open('config/settings.json', 'r') as f:
                config = json.load(f)
            user_config = config.get('user', {})
            self.hydration_calc = HydrationCalculator(
                user_config.get('body_weight', 70),
                user_config.get('cup_volume', 300),
                user_config.get('work_hours', 8)
            )
            self.reminder.hydration_calc = self.hydration_calc

    @rumps.clicked("AI 配置")
    def open_ai_config(self, _):
        """打开 AI 配置"""
        from src.ai_config_dialog import AIConfigDialog
        from PySide6.QtWidgets import QApplication
        import sys

        app = QApplication.instance() or QApplication(sys.argv)
        dialog = AIConfigDialog()
        dialog.exec()
