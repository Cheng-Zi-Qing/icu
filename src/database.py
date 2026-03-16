"""数据持久化模块"""
import sqlite3
from datetime import datetime
from pathlib import Path


class Database:
    """SQLite 数据库"""

    def __init__(self, db_path='data/icu.db'):
        Path(db_path).parent.mkdir(exist_ok=True)
        self.conn = sqlite3.connect(db_path)
        self.create_tables()

    def create_tables(self):
        """创建表"""
        cursor = self.conn.cursor()

        # 状态切换记录
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS state_transitions (
                id INTEGER PRIMARY KEY,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                from_state TEXT,
                to_state TEXT,
                duration_seconds INT
            )
        ''')

        # 健康提醒记录
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

        # 饮水记录
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
        """记录状态切换"""
        cursor = self.conn.cursor()
        cursor.execute(
            'INSERT INTO state_transitions (from_state, to_state, duration_seconds) VALUES (?, ?, ?)',
            (from_state, to_state, duration)
        )
        self.conn.commit()

    def close(self):
        """关闭连接"""
        self.conn.close()
