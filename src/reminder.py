"""提醒管理模块"""
import threading
from datetime import datetime


class ReminderManager:
    """提醒管理器"""

    def __init__(self, fsm, hydration_calc):
        self.fsm = fsm
        self.hydration_calc = hydration_calc
        self.timers = {}

    def start_timers(self):
        """启动计时器"""
        if self.fsm.state != 'working':
            return

        # 护眼提醒 20 分钟
        self.timers['eye'] = threading.Timer(1200, self._eye_reminder)
        self.timers['eye'].start()

        # 拉伸提醒 45 分钟
        self.timers['stretch'] = threading.Timer(2700, self._stretch_reminder)
        self.timers['stretch'].start()

        # 补水提醒（动态间隔）
        interval = self.hydration_calc.calculate()['interval']
        self.timers['water'] = threading.Timer(interval, self._water_reminder)
        self.timers['water'].start()

    def stop_timers(self):
        """停止所有计时器"""
        for timer in self.timers.values():
            if timer.is_alive():
                timer.cancel()
        self.timers.clear()

    def _eye_reminder(self):
        """护眼提醒"""
        if self.fsm.state == 'working':
            print(f"[提醒] 护眼：盯屏幕 20 分钟了，看看远处吧~")

    def _stretch_reminder(self):
        """拉伸提醒"""
        if self.fsm.state == 'working':
            print(f"[提醒] 拉伸：坐了 45 分钟，起来动动吧！")

    def _water_reminder(self):
        """补水提醒"""
        if self.fsm.state == 'working':
            print(f"[提醒] 补水：该喝水啦，补充水分！")
