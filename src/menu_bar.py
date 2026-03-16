"""Menu Bar UI 模块"""
import rumps
from src.state_machine import HealthStateMachine


class ICUMenuBar(rumps.App):
    """I.C.U. Menu Bar 应用"""

    def __init__(self):
        super().__init__("I.C.U.", "🛌")
        self.fsm = HealthStateMachine()
        self.update_menu()

    def update_menu(self):
        """根据状态更新菜单"""
        self.menu.clear()

        if self.fsm.state == 'idle':
            self.menu = ["开始工作", None, "设置", "退出"]
        elif self.fsm.state == 'working':
            self.menu = ["进入专注", "暂离", "下班", None, "设置", "退出"]
        elif self.fsm.state in ['focus', 'break']:
            self.menu = ["回来工作", "下班", None, "设置", "退出"]

    @rumps.clicked("开始工作")
    def start_work(self, _):
        self.fsm.start_work()
        self.icon = "💻"
        self.update_menu()

    @rumps.clicked("进入专注")
    def enter_focus(self, _):
        self.fsm.enter_focus()
        self.icon = "🔕"
        self.update_menu()

    @rumps.clicked("回来工作")
    def resume_work(self, _):
        if self.fsm.state == 'focus':
            self.fsm.exit_focus()
        else:
            self.fsm.resume_work()
        self.icon = "💻"
        self.update_menu()

    @rumps.clicked("暂离")
    def take_break(self, _):
        self.fsm.take_break()
        self.icon = "☕"
        self.update_menu()

    @rumps.clicked("下班")
    def stop_work(self, _):
        self.fsm.stop_work()
        self.icon = "🛌"
        self.update_menu()
