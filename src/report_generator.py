"""报告生成模块"""
from datetime import datetime, timedelta
from src.logger import logger


class ReportGenerator:
    """报告生成器"""

    def __init__(self, db):
        self.db = db

    def generate_daily_report(self):
        """生成每日报告"""
        today = datetime.now().date()
        conn = self.db.conn
        cursor = conn.cursor()

        cursor.execute("""
            SELECT SUM(duration_seconds)
            FROM state_transitions
            WHERE DATE(timestamp) = ? AND to_state = 'working'
        """, (today,))
        work_seconds = cursor.fetchone()[0] or 0

        cursor.execute("""
            SELECT COUNT(*)
            FROM state_transitions
            WHERE DATE(timestamp) = ? AND to_state = 'focus'
        """, (today,))
        focus_count = cursor.fetchone()[0]

        cursor.execute("""
            SELECT reminder_type, COUNT(*)
            FROM health_reminders
            WHERE DATE(timestamp) = ?
            GROUP BY reminder_type
        """, (today,))
        reminders = dict(cursor.fetchall())

        report = {
            'date': str(today),
            'work_hours': round(work_seconds / 3600, 1),
            'focus_count': focus_count,
            'reminders': reminders
        }

        logger.info(f"📊 每日报告: 工作{report['work_hours']}小时, 专注{focus_count}次")
        return report
