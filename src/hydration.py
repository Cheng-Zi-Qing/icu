"""动态水合算法模块"""
import math


class HydrationCalculator:
    """
    动态水合算法

    根据体重、杯子容量和工作时长计算个性化补水提醒间隔
    """

    def __init__(self, body_weight=70, cup_volume=300, work_hours=8):
        """
        初始化水合计算器

        Args:
            body_weight: 体重（kg），默认 70
            cup_volume: 杯子容量（ml），默认 300
            work_hours: 预计工作时长（小时），默认 8
        """
        self.body_weight = body_weight
        self.cup_volume = cup_volume
        self.work_hours = work_hours

    def calculate(self):
        """
        计算补水参数

        Returns:
            dict: 包含以下字段
                - daily_water: 每日总需水量（ml）
                - work_water: 工作期间需水量（ml）
                - cups_needed: 需喝杯数
                - interval: 提醒间隔（秒）
        """
        daily_water = self.body_weight * 35  # 每日总需水量 = 体重 × 35ml
        work_water = daily_water * 0.65  # 工作期间需水量 = 总需水量 × 65%
        cups_needed = math.ceil(work_water / self.cup_volume)  # 需喝杯数（向上取整）
        interval = (self.work_hours * 3600) / cups_needed  # 提醒间隔（秒）

        # 安全阈值约束
        if interval < 1800:  # 最小间隔 30 分钟
            interval = 1800
        elif interval > 7200:  # 最大间隔 120 分钟
            interval = 5400  # 修正为 90 分钟

        return {
            'daily_water': daily_water,
            'work_water': work_water,
            'cups_needed': cups_needed,
            'interval': interval
        }
