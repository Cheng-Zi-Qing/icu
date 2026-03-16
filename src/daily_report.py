"""每日报告对话框"""
from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel, QPushButton, QHBoxLayout, QFrame
from PySide6.QtCore import Qt
from PySide6.QtGui import QFont


class DailyReportDialog(QDialog):
    """每日工作小结对话框"""

    def __init__(self, stats, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        self.stats = stats
        self.setup_ui()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("今日工作小结")
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
                background-color: transparent;
            }
            QPushButton {
                background-color: #3a3a3a;
                color: #e0e0e0;
                border: 3px solid #5a5a5a;
                border-style: outset;
                padding: 10px 20px;
                font-family: 'Courier New', monospace;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #4a4a4a;
                border: 3px solid #6a6a6a;
            }
            QPushButton:pressed {
                border-style: inset;
            }
        """)

        layout = QVBoxLayout()
        layout.setSpacing(10)

        # 标题
        title = QLabel("📊 今日工作小结")
        title.setStyleSheet("font-size: 18px; font-weight: bold; color: #00ff00; padding: 10px;")
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)

        # 分隔线
        line = QFrame()
        line.setFrameShape(QFrame.HLine)
        line.setStyleSheet("background-color: #4a4a4a;")
        layout.addWidget(line)

        # 工作统计
        work_hours = self.stats['work_minutes'] // 60
        work_mins = self.stats['work_minutes'] % 60
        work_label = QLabel(f"⏰ 工作时长: {work_hours}小时 {work_mins}分钟")
        work_label.setStyleSheet("font-size: 14px; color: #00ccff;")
        layout.addWidget(work_label)

        focus_hours = self.stats['focus_minutes'] // 60
        focus_mins = self.stats['focus_minutes'] % 60
        focus_label = QLabel(f"🔥 深度专注: {self.stats['focus_count']}次, 累计{focus_hours}小时{focus_mins}分钟")
        focus_label.setStyleSheet("font-size: 14px; color: #ff9900;")
        layout.addWidget(focus_label)

        break_label = QLabel(f"☕ 暂离次数: {self.stats['break_count']}次")
        break_label.setStyleSheet("font-size: 14px; color: #ffcc00;")
        layout.addWidget(break_label)

        layout.addSpacing(15)

        # 健康行为达成率
        health_title = QLabel("━━━ 健康行为统计 ━━━")
        health_title.setStyleSheet("font-size: 14px; color: #00ff00;")
        health_title.setAlignment(Qt.AlignCenter)
        layout.addWidget(health_title)

        eye_rate = self._calc_rate(self.stats['eye_care'])
        eye_label = QLabel(f"👁️  护眼: {self.stats['eye_care']['responded']}/{self.stats['eye_care']['triggered']} ({eye_rate}%)")
        eye_label.setStyleSheet(f"color: {self._get_rate_color(eye_rate)};")
        layout.addWidget(eye_label)

        stretch_rate = self._calc_rate(self.stats['stretch'])
        stretch_label = QLabel(f"🤸 拉伸: {self.stats['stretch']['responded']}/{self.stats['stretch']['triggered']} ({stretch_rate}%)")
        stretch_label.setStyleSheet(f"color: {self._get_rate_color(stretch_rate)};")
        layout.addWidget(stretch_label)

        hydration_rate = self._calc_rate(self.stats['hydration'])
        hydration_label = QLabel(f"💧 补水: {self.stats['hydration']['responded']}/{self.stats['hydration']['triggered']} ({hydration_rate}%)")
        hydration_label.setStyleSheet(f"color: {self._get_rate_color(hydration_rate)};")
        layout.addWidget(hydration_label)
        
        layout.addSpacing(20)

        # 补水建议
        cups = self.stats['hydration']['cups']
        remaining = max(0, 8 - cups) * 300
        if remaining > 0:
            layout.addWidget(QLabel(f"回家需补水：{remaining} ml"))
            layout.addWidget(QLabel("💡 睡前 2 小时避免大量饮水"))

        layout.addStretch()

        # 按钮
        btn_layout = QHBoxLayout()
        close_btn = QPushButton("关闭")
        close_btn.clicked.connect(self.accept)
        btn_layout.addStretch()
        btn_layout.addWidget(close_btn)
        
        layout.addLayout(btn_layout)
        self.setLayout(layout)

    def _calc_rate(self, data):
        """计算达成率"""
        if data['triggered'] == 0:
            return 0
        return int(data['responded'] / data['triggered'] * 100)

    def _get_rate_color(self, rate):
        """根据达成率返回颜色"""
        if rate >= 80:
            return '#00ff00'
        elif rate >= 60:
            return '#ffcc00'
        else:
            return '#ff6666'
