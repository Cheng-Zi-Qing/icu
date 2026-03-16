"""测试 PRD 1.3 功能"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.report_generator import ReportGenerator
from src.ai_assistant import AIAssistant
from src.database import Database


def test_report_generator():
    """测试报告生成"""
    db = Database(':memory:')
    rg = ReportGenerator(db)
    report = rg.generate_daily_report()
    assert 'work_hours' in report
    print("✅ 报告生成测试通过")


def test_ai_assistant():
    """测试 AI 助手"""
    ai = AIAssistant()
    msg = ai.generate_reminder('eye_care')
    assert len(msg) > 0
    print(f"✅ AI 助手测试通过: {msg}")


if __name__ == '__main__':
    test_report_generator()
    test_ai_assistant()
