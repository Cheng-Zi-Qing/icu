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
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        self.selected_image = None
        self.setup_ui()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("新增自定义形象")
        self.setFixedSize(700, 600)

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
            QTextEdit, QLineEdit {
                background-color: #3a3a3a;
                color: #00ff00;
                border: 3px solid #5a5a5a;
                border-style: inset;
                padding: 5px;
                font-family: 'Courier New', monospace;
            }
            QComboBox {
                background-color: #3a3a3a;
                color: #e0e0e0;
                border: 3px solid #5a5a5a;
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
            QPushButton:disabled {
                color: #666;
            }
        """)

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
        """步骤1：输入并优化提示词"""
        widget = QWidget()
        layout = QVBoxLayout()

        # 用户输入
        layout.addWidget(QLabel("描述你想要的桌宠形象："))
        self.user_input = QTextEdit()
        self.user_input.setPlaceholderText("例如：一只淡定的卡皮巴拉")
        self.user_input.setMaximumHeight(60)
        layout.addWidget(self.user_input)

        # 优化按钮
        self.optimize_btn = QPushButton("优化提示词")
        self.optimize_btn.clicked.connect(self.optimize_prompt)
        layout.addWidget(self.optimize_btn)

        layout.addSpacing(10)

        # 优化后的提示词
        layout.addWidget(QLabel("优化后的提示词（可编辑）："))
        self.optimized_prompt = QTextEdit()
        self.optimized_prompt.setPlaceholderText("点击上方按钮生成...")
        self.optimized_prompt.setMaximumHeight(100)
        layout.addWidget(self.optimized_prompt)

        layout.addStretch()
        widget.setLayout(layout)
        return widget

    def optimize_prompt(self):
        """优化提示词"""
        user_text = self.user_input.toPlainText().strip()
        if not user_text:
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.warning(self, "提示", "请先输入描述")
            return

        self.optimize_btn.setEnabled(False)
        self.optimize_btn.setText("优化中...")

        from PySide6.QtCore import QThread, Signal

        class OptimizerThread(QThread):
            finished = Signal(str)
            error = Signal(str)

            def __init__(self, text):
                super().__init__()
                self.text = text

            def run(self):
                try:
                    import sys
                    sys.path.insert(0, 'builder')
                    from prompt_optimizer import PromptOptimizer
                    optimizer = PromptOptimizer()
                    result = optimizer.optimize(self.text)
                    if result:
                        self.finished.emit(result)
                    else:
                        self.error.emit("Ollama 未运行或模型未找到")
                except Exception as e:
                    self.error.emit(str(e))

        self.opt_thread = OptimizerThread(user_text)
        self.opt_thread.finished.connect(self.on_optimize_finished)
        self.opt_thread.error.connect(self.on_optimize_error)
        self.opt_thread.start()

    def on_optimize_finished(self, result):
        """优化完成"""
        self.optimized_prompt.setText(result)
        self.optimize_btn.setEnabled(True)
        self.optimize_btn.setText("优化提示词")

    def on_optimize_error(self, error):
        """优化失败"""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.critical(self, "错误", f"优化失败：{error}")
        self.optimize_btn.setEnabled(True)
        self.optimize_btn.setText("优化提示词")

    def create_step2(self):
        """步骤2：选择模型并生成图像"""
        widget = QWidget()
        layout = QVBoxLayout()

        # 模型选择
        model_layout = QHBoxLayout()
        model_layout.addWidget(QLabel("选择模型："))
        self.model_combo = QComboBox()
        self.load_image_models()
        model_layout.addWidget(self.model_combo)

        config_btn = QPushButton("配置模型")
        config_btn.clicked.connect(self.open_model_config)
        model_layout.addWidget(config_btn)
        layout.addLayout(model_layout)

        layout.addSpacing(10)

        # 当前生成状态
        self.gen_status = QLabel("准备生成 idle 状态图")
        layout.addWidget(self.gen_status)

        # 预览
        self.image_preview = QLabel()
        self.image_preview.setFixedSize(256, 256)
        self.image_preview.setAlignment(Qt.AlignCenter)
        self.image_preview.setStyleSheet("border: 2px dashed #ccc;")
        layout.addWidget(self.image_preview, alignment=Qt.AlignCenter)

        # 按钮
        btn_layout = QHBoxLayout()
        self.gen_btn = QPushButton("生成")
        self.regen_btn = QPushButton("重新生成")
        self.confirm_btn = QPushButton("确认")

        self.gen_btn.clicked.connect(self.generate_image)
        self.regen_btn.clicked.connect(self.regenerate_image)
        self.confirm_btn.clicked.connect(self.confirm_image)

        self.regen_btn.setEnabled(False)
        self.confirm_btn.setEnabled(False)

        btn_layout.addWidget(self.gen_btn)
        btn_layout.addWidget(self.regen_btn)
        btn_layout.addWidget(self.confirm_btn)
        layout.addLayout(btn_layout)

        layout.addStretch()
        widget.setLayout(layout)

        # 初始化生成状态
        self.current_action_index = 0
        self.actions = ['idle', 'working', 'alert']
        self.generated_images = {}

        return widget

    def create_step3(self):
        """步骤3：生成人设和消息"""
        widget = QWidget()
        layout = QVBoxLayout()

        # 形象名称
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("形象名称："))
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("例如：淡定水豚")
        name_layout.addWidget(self.name_input)
        layout.addLayout(name_layout)

        # 生成人设按钮
        self.gen_persona_btn = QPushButton("生成人设和消息")
        self.gen_persona_btn.clicked.connect(self.generate_persona)
        layout.addWidget(self.gen_persona_btn)

        # 人设描述
        layout.addWidget(QLabel("人设描述（可编辑）："))
        self.persona_input = QTextEdit()
        self.persona_input.setPlaceholderText("点击上方按钮生成...")
        self.persona_input.setMaximumHeight(100)
        layout.addWidget(self.persona_input)

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

    def start_generation(self):
        """开始AI生成"""
        if self.ai_radio.isChecked():
            prompt = self.ai_prompt.toPlainText().strip()
            if not prompt:
                from PySide6.QtWidgets import QMessageBox
                QMessageBox.warning(self, "提示", "请输入描述")
                return

            self.generate_btn.setEnabled(False)
            self.status_label.setText("🔥 正在生成...")

            # 在后台线程运行
            from PySide6.QtCore import QThread, Signal

            class GeneratorThread(QThread):
                finished = Signal(dict)
                error = Signal(str)

                def __init__(self, prompt):
                    super().__init__()
                    self.prompt = prompt

                def run(self):
                    try:
                        import sys
                        sys.path.insert(0, 'builder')
                        from persona_forge import PersonaForge
                        from vision_generator import VisionGenerator
                        from vision_slicer import VisionSlicer
                        import os

                        # 第一层
                        forge = PersonaForge()
                        persona_data = forge.forge(self.prompt, force=True)
                        if not persona_data:
                            self.error.emit("灵魂锻造失败")
                            return

                        # 第二层
                        hf_token = os.getenv('HF_TOKEN')
                        generator = VisionGenerator(hf_token=hf_token)
                        image_path = generator.generate(persona_data['image_generation_prompt'], force=True)
                        if not image_path:
                            self.error.emit("图像生成失败")
                            return

                        # 第三层
                        slicer = VisionSlicer()
                        result = slicer.process(image_path, persona_data['expected_actions'])
                        if not result['success']:
                            self.error.emit(f"切割失败：{result['message']}")
                            return

                        self.finished.emit({
                            'persona': persona_data,
                            'frames': result['frames'],
                            'actions': result['actions']
                        })
                    except Exception as e:
                        self.error.emit(str(e))

            self.thread = GeneratorThread(prompt)
            self.thread.finished.connect(self.on_generation_finished)
            self.thread.error.connect(self.on_generation_error)
            self.thread.start()
        else:
            self.upload_image()

    def on_generation_finished(self, data):
        """生成完成"""
        self.generated_data = data
        self.status_label.setText("✅ 生成完成")
        self.generate_btn.setEnabled(True)

        # 显示第一帧预览
        frame = data['frames'][0]
        from PySide6.QtGui import QImage
        import numpy as np

        img_array = np.array(frame)
        height, width, channel = img_array.shape
        bytes_per_line = channel * width
        q_image = QImage(img_array.data, width, height, bytes_per_line, QImage.Format_RGBA8888)
        pixmap = QPixmap.fromImage(q_image)
        self.preview_label.setPixmap(pixmap.scaled(128, 128, Qt.KeepAspectRatio, Qt.SmoothTransformation))

        # 自动填充名称和人设
        self.name_input.setText(data['persona']['display_name'])
        self.persona_input.setText(data['persona']['ai_persona_system_prompt'])

    def on_generation_error(self, error):
        """生成失败"""
        from PySide6.QtWidgets import QMessageBox
        self.status_label.setText(f"❌ {error}")
        self.generate_btn.setEnabled(True)
        QMessageBox.critical(self, "错误", f"生成失败：{error}")


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
        if self.current_step == 0:
            if not self.optimized_prompt.toPlainText().strip():
                from PySide6.QtWidgets import QMessageBox
                QMessageBox.warning(self, "提示", "请先优化提示词")
                return False
        elif self.current_step == 1:
            if len(self.generated_images) < len(self.actions):
                from PySide6.QtWidgets import QMessageBox
                QMessageBox.warning(self, "提示", "请生成所有动作图像")
                return False
        elif self.current_step == 2:
            if not self.name_input.text().strip():
                from PySide6.QtWidgets import QMessageBox
                QMessageBox.warning(self, "提示", "请输入形象名称")
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
        steps = ["优化提示词", "生成图像", "生成人设"]
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

        # 生成 pet_id
        import re
        pet_id = re.sub(r'[^a-z0-9_]', '_', name.lower())
        avatar_dir = Path(f"assets/pets/{pet_id}")
        avatar_dir.mkdir(parents=True, exist_ok=True)

        # 保存图像
        for action, image in self.generated_images.items():
            action_dir = avatar_dir / action
            action_dir.mkdir(exist_ok=True)
            image.save(action_dir / "0.png")

        # 保存配置
        config = {
            "id": pet_id,
            "name": name,
            "style": "AI生成",
            "persona": {
                "traits": self.persona_input.toPlainText(),
                "tone": "",
                "messages": {
                    "eye_care": [],
                    "stretch": [],
                    "hydration": []
                }
            }
        }

        with open(avatar_dir / "config.json", 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        QMessageBox.information(self, "成功", f"形象 '{name}' 已保存！")
        self.accept()

    def generate_image(self):
        """生成当前动作的图像"""
        prompt = self.optimized_prompt.toPlainText().strip()
        if not prompt:
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.warning(self, "提示", "请先优化提示词")
            return

        action = self.actions[self.current_action_index]
        self.gen_btn.setEnabled(False)
        self.gen_status.setText(f"正在生成 {action} 状态图...")

        from PySide6.QtCore import QThread, Signal

        class ImageGenThread(QThread):
            finished = Signal(object)
            error = Signal(str)

            def __init__(self, prompt, model, action):
                super().__init__()
                self.prompt = prompt
                self.model = model
                self.action = action

            def run(self):
                try:
                    import sys
                    sys.path.insert(0, 'builder')
                    from vision_generator import VisionGenerator
                    import os

                    # 获取模型配置
                    model_config = self.model
                    hf_token = model_config.get('token', '')

                    if not hf_token:
                        hf_token = os.getenv('HF_TOKEN')
                        if not hf_token:
                            try:
                                with open('.env', 'r') as f:
                                    for line in f:
                                        if line.startswith('HF_TOKEN='):
                                            hf_token = line.split('=', 1)[1].strip()
                                            break
                            except:
                                pass

                    generator = VisionGenerator(hf_token=hf_token)
                    full_prompt = f"{self.prompt}, {self.action} pose, single character, centered, solid white background, high contrast, clean edges"

                    # 打印提示词用于调试
                    print(f"[生成提示词] {full_prompt}")

                    image_path = generator.generate(full_prompt, force=True)

                    if image_path:
                        from PIL import Image
                        img = Image.open(image_path)
                        self.finished.emit(img)
                    else:
                        self.error.emit("生成失败")
                except Exception as e:
                    self.error.emit(str(e))

        model = self.model_combo.currentData()
        self.gen_thread = ImageGenThread(prompt, model, action)
        self.gen_thread.finished.connect(self.on_image_generated)
        self.gen_thread.error.connect(self.on_image_error)
        self.gen_thread.start()

    def regenerate_image(self):
        """重新生成当前图像"""
        self.generate_image()

    def confirm_image(self):
        """确认当前图像"""
        action = self.actions[self.current_action_index]
        self.generated_images[action] = self.current_image

        self.current_action_index += 1
        if self.current_action_index < len(self.actions):
            next_action = self.actions[self.current_action_index]
            self.gen_status.setText(f"准备生成 {next_action} 状态图")
            self.image_preview.clear()
            self.gen_btn.setEnabled(True)
            self.regen_btn.setEnabled(False)
            self.confirm_btn.setEnabled(False)
        else:
            self.gen_status.setText("✅ 所有图像生成完成")

    def on_image_generated(self, image):
        """图像生成完成"""
        self.current_image = image

        from PySide6.QtGui import QImage
        import numpy as np

        img_array = np.array(image)
        height, width = img_array.shape[:2]
        channel = img_array.shape[2] if len(img_array.shape) > 2 else 1

        if channel == 4:
            q_image = QImage(img_array.data, width, height, channel * width, QImage.Format_RGBA8888)
        else:
            q_image = QImage(img_array.data, width, height, channel * width, QImage.Format_RGB888)

        pixmap = QPixmap.fromImage(q_image)
        self.image_preview.setPixmap(pixmap.scaled(256, 256, Qt.KeepAspectRatio, Qt.SmoothTransformation))

        self.gen_btn.setEnabled(True)
        self.regen_btn.setEnabled(True)
        self.confirm_btn.setEnabled(True)
        self.gen_status.setText(f"✅ {self.actions[self.current_action_index]} 状态图已生成")

    def on_image_error(self, error):
        """图像生成失败"""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.critical(self, "错误", f"生成失败：{error}")
        self.gen_btn.setEnabled(True)
        self.gen_status.setText("❌ 生成失败")

    def generate_persona(self):
        """生成人设和消息"""
        user_text = self.user_input.toPlainText().strip()
        if not user_text:
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.warning(self, "提示", "请先输入描述")
            return

        self.gen_persona_btn.setEnabled(False)
        self.gen_persona_btn.setText("生成中...")

        from PySide6.QtCore import QThread, Signal

        class PersonaGenThread(QThread):
            finished = Signal(str)
            error = Signal(str)

            def __init__(self, text):
                super().__init__()
                self.text = text

            def run(self):
                try:
                    import sys
                    sys.path.insert(0, 'builder')
                    from persona_forge import PersonaForge
                    forge = PersonaForge()
                    
                    if not forge.check_ollama():
                        self.error.emit("Ollama 未运行")
                        return

                    system_prompt = "你是桌宠人设生成助手。根据用户描述生成简短的人设描述（2-3句话）。"
                    user_message = f"用户描述：{self.text}\n\n请生成人设描述："

                    import requests
                    response = requests.post(
                        f"{forge.ollama_url}/api/chat",
                        json={
                            "model": forge.model,
                            "messages": [
                                {"role": "system", "content": system_prompt},
                                {"role": "user", "content": user_message}
                            ],
                            "options": {"temperature": 0.7},
                            "stream": False
                        },
                        proxies={'http': None, 'https': None}
                    )

                    result = response.json()
                    self.finished.emit(result['message']['content'])
                except Exception as e:
                    self.error.emit(str(e))

        self.persona_thread = PersonaGenThread(user_text)
        self.persona_thread.finished.connect(self.on_persona_generated)
        self.persona_thread.error.connect(self.on_persona_error)
        self.persona_thread.start()

    def on_persona_generated(self, result):
        """人设生成完成"""
        self.persona_input.setText(result)
        self.gen_persona_btn.setEnabled(True)
        self.gen_persona_btn.setText("生成人设和消息")

    def on_persona_error(self, error):
        """人设生成失败"""
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.critical(self, "错误", f"生成失败：{error}")
        self.gen_persona_btn.setEnabled(True)
        self.gen_persona_btn.setText("生成人设和消息")

    def load_image_models(self):
        """加载图像模型列表"""
        config_file = Path('config/settings.json')

        if config_file.exists():
            with open(config_file, 'r') as f:
                config = json.load(f)
                models = config.get('ai', {}).get('image_models', [])
        else:
            models = []

        if not models:
            models = [{"name": "Stable Diffusion XL", "url": "stabilityai/stable-diffusion-xl-base-1.0", "token": ""}]

        self.model_combo.clear()
        for model in models:
            self.model_combo.addItem(model['name'], model)

    def open_model_config(self):
        """打开模型配置对话框"""
        from ai_config_dialog import AIConfigDialog
        dialog = AIConfigDialog(self)
        if dialog.exec():
            self.load_image_models()
