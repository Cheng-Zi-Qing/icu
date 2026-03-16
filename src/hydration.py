"""动态水合算法模块"""
import math


class HydrationCalculator:
    """动态水合算法"""

    def __init__(self, body_weight=70, cup_volume=300, work_hours=8):
        self.body_weight = body_weight
        self.cup_volume = cup_volume
        self.work_hours = work_hours

    def calculate(self):
        """计算补水参数"""
        daily_water = self.body_weight * 35
        work_water = daily_water * 0.65
        cups_needed = math.ceil(work_water / self.cup_volume)
        interval = (self.work_hours * 3600) / cups_needed

        # 安全约束
        if interval < 1800:
            interval = 1800
        elif interval > 7200:
            interval = 5400

        return {
            'daily_water': daily_water,
            'work_water': work_water,
            'cups_needed': cups_needed,
            'interval': interval
        }
