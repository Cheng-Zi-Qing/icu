"""核心状态机模块"""
from transitions import Machine
from datetime import datetime


class HealthStateMachine:
    """I.C.U. 健康状态机"""

    states = ['idle', 'working', 'focus', 'break']

    def __init__(self):
        self.focus_start_time = None

        self.machine = Machine(
            model=self,
            states=HealthStateMachine.states,
            initial='idle'
        )

        # 状态转换
        self.machine.add_transition('start_work', 'idle', 'working')
        self.machine.add_transition('enter_focus', 'working', 'focus')
        self.machine.add_transition('exit_focus', 'focus', 'working')
        self.machine.add_transition('take_break', 'working', 'break')
        self.machine.add_transition('resume_work', 'break', 'working')
        self.machine.add_transition('stop_work', '*', 'idle')

    def get_focus_duration(self):
        """获取专注时长（秒）"""
        if self.focus_start_time:
            return (datetime.now() - self.focus_start_time).total_seconds()
        return 0
