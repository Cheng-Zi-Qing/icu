"""用户配置对话框"""
from PySide6.QtWidgets import (QDialog, QVBoxLayout, QLabel, QPushButton,
                                QLineEdit, QHBoxLayout, QSpinBox)
from PySide6.QtCore import Qt
import json
from pathlib import Path


class UserConfigDialog(QDialog):
    """用户配置对话框"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        self.config_file = Path('config/settings.json')
        self.setup_ui()
        self.load_config()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("个人设置")
        self.setFixedSize(500, 350)

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
            QSpinBox {
                background-color: #3a3a3a;
                color: #00ff00;
                border: 3px solid #5a5a5a;
                border-style: inset;
                padding: 5px;
                font-family: 'Courier New', monospace;
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
        title = QLabel("个人健康配置")
        title.setStyleSheet("font-size: 16px; font-weight: bold;")
        layout.addWidget(title)

        layout.addSpacing(20)

        # 体重
        weight_layout = QHBoxLayout()
        weight_layout.addWidget(QLabel("体重 (kg)："))
        self.weight_input = QSpinBox()
        self.weight_input.setRange(30, 200)
        self.weight_input.setValue(70)
        weight_layout.addWidget(self.weight_input)
        layout.addLayout(weight_layout)

        # 杯子容量
        cup_layout = QHBoxLayout()
        cup_layout.addWidget(QLabel("杯子容量 (ml)："))
        self.cup_input = QSpinBox()
        self.cup_input.setRange(100, 1000)
        self.cup_input.setSingleStep(50)
        self.cup_input.setValue(300)
        cup_layout.addWidget(self.cup_input)
        layout.addLayout(cup_layout)

        # 工作时长
        hours_layout = QHBoxLayout()
        hours_layout.addWidget(QLabel("工作时长 (小时)："))
        self.hours_input = QSpinBox()
        self.hours_input.setRange(1, 16)
        self.hours_input.setValue(8)
        hours_layout.addWidget(self.hours_input)
        layout.addLayout(hours_layout)

        layout.addSpacing(20)

        # 计算预览
        self.preview_label = QLabel("")
        self.preview_label.setStyleSheet("color: #666; font-size: 12px;")
        layout.addWidget(self.preview_label)

        # 连接信号更新预览
        self.weight_input.valueChanged.connect(self.update_preview)
        self.cup_input.valueChanged.connect(self.update_preview)
        self.hours_input.valueChanged.connect(self.update_preview)

        layout.addStretch()

        # 按钮
        btn_layout = QHBoxLayout()
        save_btn = QPushButton("保存")
        cancel_btn = QPushButton("取消")
        save_btn.clicked.connect(self.save_config)
        cancel_btn.clicked.connect(self.reject)
        btn_layout.addStretch()
        btn_layout.addWidget(cancel_btn)
        btn_layout.addWidget(save_btn)
        layout.addLayout(btn_layout)

        self.setLayout(layout)

    def load_config(self):
        """加载配置"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                config = json.load(f)
                user_config = config.get('user', {})

                self.weight_input.setValue(user_config.get('body_weight', 70))
                self.cup_input.setValue(user_config.get('cup_volume', 300))
                self.hours_input.setValue(user_config.get('work_hours', 8))

        self.update_preview()

    def update_preview(self):
        """更新计算预览"""
        from src.hydration import HydrationCalculator

        calc = HydrationCalculator(
            self.weight_input.value(),
            self.cup_input.value(),
            self.hours_input.value()
        )
        result = calc.calculate()

        interval_min = int(result['interval'] / 60)
        self.preview_label.setText(
            f"💧 预计每 {interval_min} 分钟提醒一次，"
            f"工作期间需喝 {result['cups_needed']} 杯水"
        )

    def save_config(self):
        """保存配置"""
        with open(self.config_file, 'r') as f:
            config = json.load(f)

        config['user'] = {
            'body_weight': self.weight_input.value(),
            'cup_volume': self.cup_input.value(),
            'work_hours': self.hours_input.value()
        }

        with open(self.config_file, 'w') as f:
            json.dump(config, f, indent=2)

        self.accept()
