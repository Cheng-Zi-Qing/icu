"""自定义形象向导"""
from PySide6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel,
                                QPushButton, QRadioButton, QComboBox, QTextEdit,
                                QFileDialog, QLineEdit, QStackedWidget, QWidget)
from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap
from pathlib import Path
import json
import shutil


class AvatarWizard(QDialog):
    """自定义形象向导"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.selected_image = None
        self.setup_ui()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("新增自定义形象")
        self.setFixedSize(600, 500)

        layout = QVBoxLayout()

        # 步骤指示器
        self.step_label = QLabel("步骤 1/3：选择形象风格")
        self.step_label.setStyleSheet("font-size: 16px; font-weight: bold;")
        layout.addWidget(self.step_label)

        # 分页容器
        self.pages = QStackedWidget()
        self.pages.addWidget(self.create_step1())
        self.pages.addWidget(self.create_step2())
        self.pages.addWidget(self.create_step3())
        layout.addWidget(self.pages)

        # 按钮区域
        button_layout = QHBoxLayout()
        self.prev_btn = QPushButton("上一步")
        self.next_btn = QPushButton("下一步")
        self.cancel_btn = QPushButton("取消")

        self.prev_btn.clicked.connect(self.prev_step)
        self.next_btn.clicked.connect(self.next_step)
        self.cancel_btn.clicked.connect(self.reject)

        button_layout.addWidget(self.cancel_btn)
        button_layout.addStretch()
        button_layout.addWidget(self.prev_btn)
        button_layout.addWidget(self.next_btn)

        layout.addLayout(button_layout)
        self.setLayout(layout)

        self.current_step = 0
        self.update_buttons()

    def create_step1(self):
        """步骤1：选择提示词"""
        widget = QWidget()
        layout = QVBoxLayout()

        # 预设提示词
        self.preset_radio = QRadioButton("使用预设提示词（推荐）")
        self.preset_radio.setChecked(True)
        layout.addWidget(self.preset_radio)

        self.preset_combo = QComboBox()
        presets = self.load_presets()
        for preset in presets:
            self.preset_combo.addItem(preset['name'], preset['prompt'])
        layout.addWidget(self.preset_combo)

        layout.addSpacing(20)

        # 自定义提示词
        self.custom_radio = QRadioButton("自定义提示词")
        layout.addWidget(self.custom_radio)

        self.custom_prompt = QTextEdit()
        self.custom_prompt.setPlaceholderText("输入形象描述，例如：Pixel art of a cute cat...")
        self.custom_prompt.setMaximumHeight(100)
        layout.addWidget(self.custom_prompt)

        layout.addStretch()
        widget.setLayout(layout)
        return widget

    def create_step2(self):
        """步骤2：上传资源"""
        widget = QWidget()
        layout = QVBoxLayout()

        info = QLabel("请上传形象图片：")
        layout.addWidget(info)

        # 预览区域
        self.preview_label = QLabel()
        self.preview_label.setFixedSize(128, 128)
        self.preview_label.setAlignment(Qt.AlignCenter)
        self.preview_label.setStyleSheet("border: 2px dashed #ccc;")
        layout.addWidget(self.preview_label, alignment=Qt.AlignCenter)

        # 上传按钮
        upload_btn = QPushButton("上传 PNG 图片")
        upload_btn.clicked.connect(self.upload_image)
        layout.addWidget(upload_btn)

        requirement = QLabel("要求：透明背景，推荐 64x64 像素")
        requirement.setStyleSheet("color: gray;")
        layout.addWidget(requirement)

        layout.addStretch()
        widget.setLayout(layout)
        return widget

    def create_step3(self):
        """步骤3：预览保存"""
        widget = QWidget()
        layout = QVBoxLayout()

        # 形象名称
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("形象名称："))
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("例如：淡定水豚")
        name_layout.addWidget(self.name_input)
        layout.addLayout(name_layout)

        # 人设描述
        layout.addWidget(QLabel("人设描述："))
        self.persona_input = QTextEdit()
        self.persona_input.setPlaceholderText("例如：看透红尘，精神稳定，佛系处世")
        self.persona_input.setMaximumHeight(80)
        layout.addWidget(self.persona_input)

        # 预览
        layout.addWidget(QLabel("预览："))
        self.final_preview = QLabel()
        self.final_preview.setFixedSize(128, 128)
        self.final_preview.setAlignment(Qt.AlignCenter)
        self.final_preview.setStyleSheet("border: 1px solid #ccc;")
        layout.addWidget(self.final_preview, alignment=Qt.AlignCenter)

        layout.addStretch()
        widget.setLayout(layout)
        return widget

    def load_presets(self):
        """加载预设提示词"""
        presets = []
        pets_dir = Path("assets/pets")
        for pet_dir in pets_dir.iterdir():
            if pet_dir.is_dir():
                config_file = pet_dir / "config.json"
                if config_file.exists():
                    with open(config_file, 'r', encoding='utf-8') as f:
                        config = json.load(f)
                        presets.append({'name': config['name'], 'prompt': config['prompt']})
        return presets

    def upload_image(self):
        """上传图片"""
        file_path, _ = QFileDialog.getOpenFileName(self, "选择图片", "", "PNG Files (*.png)")
        if file_path:
            self.selected_image = file_path
            pixmap = QPixmap(file_path)
            scaled = pixmap.scaled(128, 128, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.preview_label.setPixmap(scaled)

    def prev_step(self):
        """上一步"""
        if self.current_step > 0:
            self.current_step -= 1
            self.pages.setCurrentIndex(self.current_step)
            self.update_buttons()

    def next_step(self):
        """下一步"""
        if self.current_step < 2:
            if not self.validate_step():
                return
            self.current_step += 1
            self.pages.setCurrentIndex(self.current_step)
            if self.current_step == 2:
                self.update_preview()
            self.update_buttons()
        else:
            self.save_avatar()

    def validate_step(self):
        """验证当前步骤"""
        if self.current_step == 1:
            if not self.selected_image:
                from PySide6.QtWidgets import QMessageBox
                QMessageBox.warning(self, "提示", "请先上传图片")
                return False
        return True

    def update_preview(self):
        """更新最终预览"""
        if self.selected_image:
            pixmap = QPixmap(self.selected_image)
            scaled = pixmap.scaled(128, 128, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.final_preview.setPixmap(scaled)

    def update_buttons(self):
        """更新按钮状态"""
        steps = ["选择形象风格", "上传形象资源", "预览并保存"]
        self.step_label.setText(f"步骤 {self.current_step + 1}/3：{steps[self.current_step]}")
        self.prev_btn.setEnabled(self.current_step > 0)
        self.next_btn.setText("保存并使用" if self.current_step == 2 else "下一步")

    def save_avatar(self):
        """保存自定义形象"""
        from PySide6.QtWidgets import QMessageBox

        name = self.name_input.text().strip()
        if not name:
            QMessageBox.warning(self, "提示", "请输入形象名称")
            return

        avatar_id = f"custom_{len(list(Path('assets/pets').iterdir()))}"
        avatar_dir = Path(f"assets/pets/{avatar_id}")
        avatar_dir.mkdir(exist_ok=True)

        shutil.copy(self.selected_image, avatar_dir / "base.png")

        prompt = self.preset_combo.currentData() if self.preset_radio.isChecked() else self.custom_prompt.toPlainText()

        config = {
            "id": avatar_id,
            "name": name,
            "style": "自定义",
            "prompt": prompt,
            "persona": {"traits": self.persona_input.toPlainText(), "tone": "", "example_dialogue": ""}
        }

        with open(avatar_dir / "config.json", 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        QMessageBox.information(self, "成功", f"形象 '{name}' 已保存！")
        self.accept()
