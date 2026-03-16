"""测试核心 FSM 功能"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.state_machine import HealthStateMachine
from src.hydration import HydrationCalculator
from src.database import Database


def test_fsm():
    """测试状态机"""
    print("=== 测试状态机 ===")
    fsm = HealthStateMachine()

    print(f"初始状态: {fsm.state}")

    fsm.start_work()
    print(f"开始工作: {fsm.state}")

    fsm.enter_focus()
    print(f"进入专注: {fsm.state}")

    fsm.exit_focus()
    print(f"退出专注: {fsm.state}")

    fsm.stop_work()
    print(f"下班: {fsm.state}")


def test_hydration():
    """测试水合算法"""
    print("\n=== 测试水合算法 ===")
    calc = HydrationCalculator(body_weight=70, cup_volume=300, work_hours=8)
    result = calc.calculate()

    print(f"每日需水量: {result['daily_water']} ml")
    print(f"工作期间需水: {result['work_water']:.0f} ml")
    print(f"需喝杯数: {result['cups_needed']} 杯")
    print(f"提醒间隔: {result['interval']/60:.0f} 分钟")


def test_database():
    """测试数据库"""
    print("\n=== 测试数据库 ===")
    db = Database('data/test.db')
    db.log_state_transition('idle', 'working', 0)
    print("状态切换已记录")
    db.close()


if __name__ == "__main__":
    test_fsm()
    test_hydration()
    test_database()
    print("\n✅ 所有测试通过")
