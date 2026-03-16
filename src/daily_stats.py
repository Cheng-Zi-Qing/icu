"""每日统计数据收集"""
import json
from pathlib import Path
from datetime import datetime, date


class DailyStats:
    """每日统计数据"""

    def __init__(self, data_file='data/daily_stats.json'):
        self.data_file = Path(data_file)
        self.data_file.parent.mkdir(exist_ok=True)
        self.stats = self._load()

    def _load(self):
        """加载统计数据"""
        if self.data_file.exists():
            with open(self.data_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}

    def _save(self):
        """保存统计数据"""
        with open(self.data_file, 'w', encoding='utf-8') as f:
            json.dump(self.stats, f, indent=2, ensure_ascii=False)

    def get_today_key(self):
        """获取今日日期键"""
        return date.today().isoformat()

    def init_today(self):
        """初始化今日数据"""
        today = self.get_today_key()
        if today not in self.stats:
            self.stats[today] = {
                'work_minutes': 0,
                'focus_count': 0,
                'focus_minutes': 0,
                'break_count': 0,
                'eye_care': {'triggered': 0, 'responded': 0},
                'stretch': {'triggered': 0, 'responded': 0},
                'hydration': {'triggered': 0, 'responded': 0, 'cups': 0}
            }
            self._save()

    def record_work_time(self, minutes):
        """记录工作时长"""
        today = self.get_today_key()
        self.init_today()
        self.stats[today]['work_minutes'] += minutes
        self._save()

    def record_focus(self, minutes):
        """记录专注时段"""
        today = self.get_today_key()
        self.init_today()
        self.stats[today]['focus_count'] += 1
        self.stats[today]['focus_minutes'] += minutes
        self._save()

    def record_break(self):
        """记录暂离"""
        today = self.get_today_key()
        self.init_today()
        self.stats[today]['break_count'] += 1
        self._save()

    def record_reminder(self, reminder_type, responded=False):
        """记录提醒响应"""
        today = self.get_today_key()
        self.init_today()
        
        if reminder_type in self.stats[today]:
            self.stats[today][reminder_type]['triggered'] += 1
            if responded:
                self.stats[today][reminder_type]['responded'] += 1
        
        self._save()

    def record_water_intake(self):
        """记录饮水"""
        today = self.get_today_key()
        self.init_today()
        self.stats[today]['hydration']['cups'] += 1
        self._save()

    def log_reminder_response(self, reminder_type, responded):
        """记录提醒响应（别名方法）"""
        # 映射提醒类型
        type_map = {
            'eye_care': 'eye_care',
            'stretch': 'stretch',
            'hydration': 'hydration'
        }
        mapped_type = type_map.get(reminder_type, reminder_type)
        self.record_reminder(mapped_type, responded)

    def get_today_stats(self):
        """获取今日统计"""
        today = self.get_today_key()
        self.init_today()
        return self.stats[today]

    def get_week_stats(self):
        """获取本周统计"""
        from datetime import timedelta
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
        
        week_data = []
        for i in range(7):
            day = (week_start + timedelta(days=i)).isoformat()
            if day in self.stats:
                week_data.append(self.stats[day])
        
        return week_data
