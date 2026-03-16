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
        """显示提醒（通过桌宠气泡）"""
        from src.pet_instance import get_pet_instance
        pet = get_pet_instance()
        if pet:
            pet.show_bubble(message)
        else:
            # 降级到系统通知
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


class ReminderSystem:
    """独立提醒系统"""

    def __init__(self):
        self.timers = {}
        self.running = False
        self.load_config()

    def load_config(self):
        """加载配置"""
        try:
            with open('config/settings.json', 'r') as f:
                config = json.load(f)
            self.eye_interval = config.get('timers', {}).get('eye_interval', 1200)
            self.stretch_interval = config.get('timers', {}).get('stretch_interval', 2700)
        except:
            self.eye_interval = 1200
            self.stretch_interval = 2700

    def start(self):
        """启动提醒"""
        if self.running:
            return
        self.running = True
        self._schedule_eye()
        self._schedule_stretch()

    def stop(self):
        """停止提醒"""
        self.running = False
        for timer in self.timers.values():
            if timer:
                timer.cancel()
        self.timers.clear()

    def _show_notification(self, message, reminder_type):
        """显示气泡"""
        from src.pet_instance import get_pet_instance
        pet = get_pet_instance()
        if pet:
            pet.show_bubble(message, reminder_type)

    def _schedule_eye(self):
        """调度护眼提醒"""
        if not self.running:
            return
        from src.ai_assistant import AIAssistant
        ai = AIAssistant()
        msg = ai.generate_reminder('eye_care')
        self._show_notification(msg, 'eye_care')
        self.timers['eye'] = threading.Timer(self.eye_interval, self._schedule_eye)
        self.timers['eye'].start()

    def _schedule_stretch(self):
        """调度拉伸提醒"""
        if not self.running:
            return
        from src.ai_assistant import AIAssistant
        ai = AIAssistant()
        msg = ai.generate_reminder('stretch')
        self._show_notification(msg, 'stretch')
        self.timers['stretch'] = threading.Timer(self.stretch_interval, self._schedule_stretch)
        self.timers['stretch'].start()
