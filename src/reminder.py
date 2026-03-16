"""提醒管理模块"""
import threading
import json
import random
import subprocess
from datetime import datetime
from pathlib import Path
from src.ai_assistant import AIAssistant


class ReminderManager:
    """提醒管理器"""

    def __init__(self, db, hydration_calc):
        self.db = db
        self.hydration_calc = hydration_calc
        self.timers = {}
        self.paused_times = {}
        self.ai = AIAssistant()

    def start_reminders(self):
        """启动所有提醒"""
        self.timers['eye'] = threading.Timer(1200, self._eye_reminder)
        self.timers['eye'].start()

        self.timers['stretch'] = threading.Timer(2700, self._stretch_reminder)
        self.timers['stretch'].start()

        interval = self.hydration_calc.calculate()['interval']
        self.timers['water'] = threading.Timer(interval, self._water_reminder)
        self.timers['water'].start()

    def stop_reminders(self):
        """停止所有提醒"""
        for timer in self.timers.values():
            if timer and timer.is_alive():
                timer.cancel()
        self.timers.clear()
        self.paused_times.clear()

    def pause_reminders(self):
        """暂停提醒（break模式）"""
        for name, timer in self.timers.items():
            if timer and timer.is_alive():
                # 记录剩余时间（简化：重新开始）
                timer.cancel()

    def resume_reminders(self):
        """恢复提醒"""
        self.start_reminders()

    def _show_notification(self, title, message):
        """显示macOS通知"""
        script = f'display notification "{message}" with title "{title}"'
        subprocess.run(['osascript', '-e', script])

    def _eye_reminder(self):
        """护眼提醒"""
        msg = self.ai.generate_reminder('eye_care')
        self._show_notification("护眼提醒", msg)
        self.db.log_reminder('eye_care', 0, 'shown')
        self.timers['eye'] = threading.Timer(1200, self._eye_reminder)
        self.timers['eye'].start()

    def _stretch_reminder(self):
        """拉伸提醒"""
        msg = self.ai.generate_reminder('stretch')
        self._show_notification("拉伸提醒", msg)
        self.db.log_reminder('stretch', 0, 'shown')
        self.timers['stretch'] = threading.Timer(2700, self._stretch_reminder)
        self.timers['stretch'].start()

    def _water_reminder(self):
        """补水提醒"""
        msg = self.ai.generate_reminder('water')
        self._show_notification("补水提醒", msg)
        self.db.log_reminder('water', 0, 'shown')
        interval = self.hydration_calc.calculate()['interval']
        self.timers['water'] = threading.Timer(interval, self._water_reminder)
        self.timers['water'].start()
