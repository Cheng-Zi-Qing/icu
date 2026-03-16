"""每周报告对话框"""
from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel, QPushButton, QHBoxLayout
from PySide6.QtCore import Qt
from datetime import date, timedelta


class WeeklyReportDialog(QDialog):
    """每周健康报告对话框"""

    def __init__(self, week_data, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        self.week_data = week_data
        self.setup_ui()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("本周健康报告")
        self.setFixedSize(450, 500)

        # 像素风格样式
        self.setStyleSheet("""
            QDialog {
                background-color: #2b2b2b;
            }
            QLabel {
                color: #e0e0e0;
                font-family: 'Courier New', monospace;
                font-size: 13px;
            }
            QPushButton {
                background-color: #3a3a3a;
                color: #e0e0e0;
                border: 3px solid #5a5a5a;
                border-style: outset;
                padding: 10px 20px;
                font-family: 'Courier New', monospace;
            }
            QPushButton:hover {
                background-color: #4a4a4a;
            }
            QPushButton:pressed {
                border-style: inset;
            }
        """)

        layout = QVBoxLayout()

        # 标题
        week_range = self._get_week_range()
        title = QLabel(f"📈 本周健康报告 ({week_range})")
        title.setStyleSheet("font-size: 18px; font-weight: bold; color: #00ff00; padding: 10px;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)

        # 汇总统计
        total_work = sum(d.get('work_minutes', 0) for d in self.week_data)
        total_focus = sum(d.get('focus_count', 0) for d in self.week_data)
        total_focus_mins = sum(d.get('focus_minutes', 0) for d in self.week_data)

        work_label = QLabel(f"⏰ 总工作时长: {total_work // 60}小时 {total_work % 60}分钟")
        work_label.setStyleSheet("color: #00ccff; font-size: 14px;")
        layout.addWidget(work_label)

        avg_work = total_work // max(len(self.week_data), 1)
        avg_label = QLabel(f"📊 日均工作: {avg_work // 60}小时 {avg_work % 60}分钟")
        avg_label.setStyleSheet("color: #ffcc00; font-size: 14px;")
        layout.addWidget(avg_label)

        focus_label = QLabel(f"🔥 深度专注: {total_focus}次, 累计{total_focus_mins // 60}小时")
        focus_label.setStyleSheet("color: #ff9900; font-size: 14px;")
        layout.addWidget(focus_label)

        layout.addSpacing(20)

        # 健康行为趋势
        health_title = QLabel("━━━ 健康行为趋势 ━━━")
        health_title.setStyleSheet("color: #00ff00; font-size: 14px;")
        health_title.setAlignment(Qt.AlignCenter)
        layout.addWidget(health_title)

        eye_rate = self._calc_avg_rate('eye_care')
        eye_label = QLabel(f"👁️  护眼响应率: {eye_rate}%")
        eye_label.setStyleSheet(f"color: {self._get_rate_color(eye_rate)};")
        layout.addWidget(eye_label)

        stretch_rate = self._calc_avg_rate('stretch')
        stretch_label = QLabel(f"🤸 拉伸响应率: {stretch_rate}%")
        stretch_label.setStyleSheet(f"color: {self._get_rate_color(stretch_rate)};")
        layout.addWidget(stretch_label)

        hydration_rate = self._calc_avg_rate('hydration')
        hydration_label = QLabel(f"💧 饮水达成率: {hydration_rate}%")
        hydration_label.setStyleSheet(f"color: {self._get_rate_color(hydration_rate)};")
        layout.addWidget(hydration_label)

        layout.addSpacing(20)

        # 改进建议
        layout.addWidget(QLabel("改进建议："))
        suggestions = self._generate_suggestions(eye_rate, stretch_rate, hydration_rate)
        for suggestion in suggestions:
            layout.addWidget(QLabel(f"• {suggestion}"))

        layout.addStretch()

        # 关闭按钮
        btn_layout = QHBoxLayout()
        close_btn = QPushButton("关闭")
        close_btn.clicked.connect(self.accept)
        btn_layout.addStretch()
        btn_layout.addWidget(close_btn)
        layout.addLayout(btn_layout)

        self.setLayout(layout)

    def _get_week_range(self):
        """获取本周日期范围"""
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
        week_end = week_start + timedelta(days=6)
        return f"{week_start.strftime('%m.%d')} - {week_end.strftime('%m.%d')}"

    def _calc_avg_rate(self, reminder_type):
        """计算平均响应率"""
        total_triggered = sum(d.get(reminder_type, {}).get('triggered', 0) for d in self.week_data)
        total_responded = sum(d.get(reminder_type, {}).get('responded', 0) for d in self.week_data)

        if total_triggered == 0:
            return 0
        return int(total_responded / total_triggered * 100)

    def _get_rate_color(self, rate):
        """根据达成率返回颜色"""
        if rate >= 80:
            return '#00ff00'
        elif rate >= 60:
            return '#ffcc00'
        else:
            return '#ff6666'

    def _generate_suggestions(self, eye_rate, stretch_rate, hydration_rate):
        """生成改进建议"""
        suggestions = []
        
        if stretch_rate < 70:
            suggestions.append("拉伸响应率偏低，建议调整间隔")
        if eye_rate < 70:
            suggestions.append("护眼提醒响应不足，注意用眼健康")
        if hydration_rate < 80:
            suggestions.append("饮水量不足，建议增加补水频率")
        
        if not suggestions:
            suggestions.append("本周表现良好，继续保持！")
        
        return suggestions
