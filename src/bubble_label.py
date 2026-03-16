"""桌宠气泡提示"""
from PySide6.QtWidgets import QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout
from PySide6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, Signal


class BubbleLabel(QWidget):
    """气泡提示窗口"""

    completed = Signal(str)  # 完成信号(提醒类型)
    ignored = Signal(str)    # 忽略信号(提醒类型)

    def __init__(self, text, reminder_type, parent=None):
        super().__init__(parent)
        self.reminder_type = reminder_type
        self.setWindowFlags(Qt.ToolTip | Qt.FramelessWindowHint)
        self.setAttribute(Qt.WA_TranslucentBackground)

        layout = QVBoxLayout()
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(10)

        # 消息文本
        self.label = QLabel(text)
        self.label.setStyleSheet("""
            color: #00ff00;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            font-weight: bold;
        """)
        self.label.setWordWrap(True)
        layout.addWidget(self.label)

        # 按钮
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(8)

        self.complete_btn = QPushButton("完成")
        self.ignore_btn = QPushButton("忽略")

        for btn in [self.complete_btn, self.ignore_btn]:
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #3a3a3a;
                    color: #e0e0e0;
                    border: 2px solid #5a5a5a;
                    padding: 5px 15px;
                    font-family: 'Courier New', monospace;
                }
                QPushButton:hover {
                    background-color: #4a4a4a;
                }
            """)

        self.complete_btn.clicked.connect(self._on_complete)
        self.ignore_btn.clicked.connect(self._on_ignore)

        btn_layout.addWidget(self.complete_btn)
        btn_layout.addWidget(self.ignore_btn)
        layout.addLayout(btn_layout)

        self.setLayout(layout)
        self.setStyleSheet("QWidget { background-color: rgba(43, 43, 43, 240); }")

        # 自动默认完成定时器
        self.auto_timer = QTimer(self)
        self.auto_timer.timeout.connect(self._on_complete)
        self.auto_timer.setSingleShot(True)

    def show_bubble(self, duration=10000):
        """显示气泡"""
        self.setWindowOpacity(1.0)
        self.adjustSize()
        self.show()
        self.auto_timer.start(duration)

    def _on_complete(self):
        """完成按钮"""
        self.auto_timer.stop()
        self.completed.emit(self.reminder_type)
        self.fade_out()

    def _on_ignore(self):
        """忽略按钮"""
        self.auto_timer.stop()
        self.ignored.emit(self.reminder_type)
        self.fade_out()

    def fade_out(self):
        """淡出动画"""
        self.animation = QPropertyAnimation(self, b"windowOpacity")
        self.animation.setDuration(300)
        self.animation.setStartValue(1.0)
        self.animation.setEndValue(0.0)
        self.animation.finished.connect(self.hide)
        self.animation.start()
