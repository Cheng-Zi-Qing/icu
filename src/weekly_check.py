"""每周报告检查模块"""
from datetime import datetime, timedelta
import json
from pathlib import Path


class WeeklyCheck:
    """每周报告检查器"""

    def __init__(self):
        self.flag_file = Path('data/weekly_report_flag.json')

    def should_show_report(self):
        """检查是否应该显示周报"""
        today = datetime.now()

        # 检查是否是周日或周一
        if today.weekday() not in [6, 0]:  # 6=周日, 0=周一
            return False

        # 检查上次显示时间
        if self.flag_file.exists():
            with open(self.flag_file, 'r') as f:
                data = json.load(f)
                last_show_str = data.get('last_show', '2000-01-01')

                # 只比较日期，忽略时间
                last_show_date = datetime.fromisoformat(last_show_str).date()
                today_date = today.date()

                # 如果今天已显示过，不再显示
                if last_show_date == today_date:
                    return False

        return True

    def mark_shown(self):
        """标记已显示"""
        with open(self.flag_file, 'w') as f:
            json.dump({'last_show': datetime.now().isoformat()}, f)
