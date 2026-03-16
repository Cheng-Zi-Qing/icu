"""核心状态机模块"""
from transitions import Machine
from datetime import datetime
from src.daily_stats import DailyStats


class HealthStateMachine:
    """
    I.C.U. 健康状态机

    管理 4 种工作状态的切换：idle（待机）、working（工作）、focus（专注）、break（暂离）
    """

    states = ['idle', 'working', 'focus', 'break']

    def __init__(self):
        """初始化状态机"""
        self.focus_start_time = None
        self.work_start_time = None
        self.daily_stats = DailyStats()

        self.machine = Machine(
            model=self,
            states=HealthStateMachine.states,
            initial='idle'
        )

        # 状态转换定义
        self.machine.add_transition('start_work', 'idle', 'working', before='_on_start_work')
        self.machine.add_transition('enter_focus', 'working', 'focus', before='_record_focus_start')
        self.machine.add_transition('exit_focus', 'focus', 'working', before='_on_exit_focus')
        self.machine.add_transition('take_break', 'working', 'break', before='_on_take_break')
        self.machine.add_transition('resume_work', 'break', 'working')
        self.machine.add_transition('stop_work', '*', 'idle', before='_on_stop_work')

    def _record_focus_start(self):
        """记录专注开始时间（内部方法）"""
        self.focus_start_time = datetime.now()

    def get_focus_duration(self):
        """
        获取专注时长

        Returns:
            int: 专注时长（秒）
        """
        if self.focus_start_time:
            return (datetime.now() - self.focus_start_time).total_seconds()
        return 0

    def _on_start_work(self):
        """开始工作回调"""
        self.work_start_time = datetime.now()

    def _on_exit_focus(self):
        """退出专注回调"""
        if self.focus_start_time:
            minutes = int((datetime.now() - self.focus_start_time).total_seconds() / 60)
            self.daily_stats.record_focus(minutes)

    def _on_take_break(self):
        """暂离回调"""
        self.daily_stats.record_break()

    def _on_stop_work(self):
        """下班回调"""
        if self.work_start_time:
            minutes = int((datetime.now() - self.work_start_time).total_seconds() / 60)
            self.daily_stats.record_work_time(minutes)
