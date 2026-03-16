"""数据持久化模块"""
import sqlite3
from datetime import datetime
from pathlib import Path


class Database:
    """
    SQLite 数据库管理

    负责状态切换、健康提醒、饮水记录的持久化存储
    """

    def __init__(self, db_path='data/icu.db'):
        """
        初始化数据库连接

        Args:
            db_path: 数据库文件路径，默认 'data/icu.db'
        """
        Path(db_path).parent.mkdir(exist_ok=True)
        self.conn = sqlite3.connect(db_path)
        self.create_tables()

    def create_tables(self):
        """创建数据表（如果不存在）"""
        cursor = self.conn.cursor()

        # 状态切换记录表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS state_transitions (
                id INTEGER PRIMARY KEY,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                from_state TEXT,
                to_state TEXT,
                duration_seconds INT
            )
        ''')

        # 健康提醒记录表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS health_reminders (
                id INTEGER PRIMARY KEY,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                reminder_type TEXT,
                focus_duration INT,
                user_response TEXT,
                response_time INT
            )
        ''')

        # 饮水记录表
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS water_intake (
                id INTEGER PRIMARY KEY,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                volume_ml INT,
                cup_percentage INT
            )
        ''')

        self.conn.commit()

    def log_state_transition(self, from_state, to_state, duration=0):
        """
        记录状态切换

        Args:
            from_state: 源状态
            to_state: 目标状态
            duration: 持续时长（秒），默认 0
        """
        cursor = self.conn.cursor()
        cursor.execute(
            'INSERT INTO state_transitions (from_state, to_state, duration_seconds) VALUES (?, ?, ?)',
            (from_state, to_state, duration)
        )
        self.conn.commit()

    def log_reminder(self, reminder_type, focus_duration, user_response, response_time=0):
        """记录健康提醒"""
        cursor = self.conn.cursor()
        cursor.execute(
            'INSERT INTO health_reminders (reminder_type, focus_duration, user_response, response_time) VALUES (?, ?, ?, ?)',
            (reminder_type, focus_duration, user_response, response_time)
        )
        self.conn.commit()

    def log_water_intake(self, volume_ml, cup_percentage):
        """记录饮水"""
        cursor = self.conn.cursor()
        cursor.execute(
            'INSERT INTO water_intake (volume_ml, cup_percentage) VALUES (?, ?)',
            (volume_ml, cup_percentage)
        )
        self.conn.commit()

    def close(self):
        """关闭数据库连接"""
        self.conn.close()
