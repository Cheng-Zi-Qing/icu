"""测试 FSM 与 ReminderManager 集成"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.state_machine import HealthStateMachine
from src.reminder import ReminderManager
from src.hydration import HydrationCalculator
from src.database import Database


def test_reminder_integration():
    """测试提醒系统集成"""
    db = Database(':memory:')
    hydration = HydrationCalculator()
    fsm = HealthStateMachine()
    reminder = ReminderManager(db, hydration)

    # 测试启动提醒
    fsm.start_work()
    reminder.start_reminders()
    assert len(reminder.timers) == 3

    # 测试暂停提醒
    reminder.pause_reminders()

    # 测试停止提醒
    reminder.stop_reminders()
    assert len(reminder.timers) == 0

    print("✅ 集成测试通过")


if __name__ == '__main__':
    test_reminder_integration()
