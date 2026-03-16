"""图像模型配置对话框"""
from PySide6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel,
                                QPushButton, QListWidget, QLineEdit, QTextEdit)
from PySide6.QtCore import Qt
import json
from pathlib import Path


class ModelConfigDialog(QDialog):
    """图像模型配置对话框"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        self.config_file = Path('config/image_models.json')
        self.setup_ui()
        self.load_models()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("图像模型配置")
        self.setFixedSize(600, 500)

        # 像素风格
        self.setStyleSheet("""
            QDialog {
                background-color: #2b2b2b;
            }
            QLabel {
                color: #e0e0e0;
                font-family: 'Courier New', monospace;
            }
            QLineEdit, QTextEdit {
                background-color: #3a3a3a;
                color: #00ff00;
                border: 3px solid #5a5a5a;
                padding: 5px;
                font-family: 'Courier New', monospace;
            }
            QPushButton {
                background-color: #3a3a3a;
                color: #e0e0e0;
                border: 3px solid #5a5a5a;
                border-style: outset;
                padding: 8px 15px;
                font-family: 'Courier New', monospace;
            }
            QPushButton:hover {
                background-color: #4a4a4a;
            }
            QListWidget {
                background-color: #3a3a3a;
                color: #e0e0e0;
                border: 3px solid #5a5a5a;
                font-family: 'Courier New', monospace;
            }
        """)

        layout = QVBoxLayout()

        # 标题
        title = QLabel("图像生成模型配置")
        title.setStyleSheet("font-size: 16px; font-weight: bold; color: #00ff00;")
        layout.addWidget(title)

        # 模型列表
        layout.addWidget(QLabel("已配置模型："))
        self.model_list = QListWidget()
        self.model_list.currentRowChanged.connect(self.on_model_selected)
        layout.addWidget(self.model_list)

        # 编辑区域
        form_layout = QVBoxLayout()
        
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("名称："))
        self.name_input = QLineEdit()
        name_layout.addWidget(self.name_input)
        form_layout.addLayout(name_layout)

        url_layout = QHBoxLayout()
        url_layout.addWidget(QLabel("API URL："))
        self.url_input = QLineEdit()
        url_layout.addWidget(self.url_input)
        form_layout.addLayout(url_layout)

        token_layout = QHBoxLayout()
        token_layout.addWidget(QLabel("Token："))
        self.token_input = QLineEdit()
        self.token_input.setEchoMode(QLineEdit.Password)
        token_layout.addWidget(self.token_input)
        form_layout.addLayout(token_layout)

        layout.addLayout(form_layout)

        # 按钮
        btn_layout = QHBoxLayout()
        self.add_btn = QPushButton("新增")
        self.save_btn = QPushButton("保存")
        self.delete_btn = QPushButton("删除")
        close_btn = QPushButton("关闭")

        self.add_btn.clicked.connect(self.add_model)
        self.save_btn.clicked.connect(self.save_model)
        self.delete_btn.clicked.connect(self.delete_model)
        close_btn.clicked.connect(self.accept)

        btn_layout.addWidget(self.add_btn)
        btn_layout.addWidget(self.save_btn)
        btn_layout.addWidget(self.delete_btn)
        btn_layout.addStretch()
        btn_layout.addWidget(close_btn)
        layout.addLayout(btn_layout)

        self.setLayout(layout)

    def load_models(self):
        """加载模型配置"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self.models = json.load(f)
        else:
            # 默认配置
            self.models = [
                {
                    "name": "Stable Diffusion XL",
                    "url": "stabilityai/stable-diffusion-xl-base-1.0",
                    "token": "",
                    "type": "huggingface"
                }
            ]
        
        self.model_list.clear()
        for model in self.models:
            self.model_list.addItem(model['name'])

    def on_model_selected(self, index):
        """选中模型"""
        if index >= 0:
            model = self.models[index]
            self.name_input.setText(model['name'])
            self.url_input.setText(model['url'])
            self.token_input.setText(model.get('token', ''))

    def add_model(self):
        """新增模型"""
        self.name_input.clear()
        self.url_input.clear()
        self.token_input.clear()
        self.model_list.setCurrentRow(-1)

    def save_model(self):
        """保存模型"""
        name = self.name_input.text().strip()
        url = self.url_input.text().strip()
        token = self.token_input.text().strip()

        if not name or not url:
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.warning(self, "提示", "请填写名称和URL")
            return

        model = {"name": name, "url": url, "token": token, "type": "huggingface"}
        
        current_row = self.model_list.currentRow()
        if current_row >= 0:
            self.models[current_row] = model
        else:
            self.models.append(model)

        self.config_file.parent.mkdir(exist_ok=True)
        with open(self.config_file, 'w') as f:
            json.dump(self.models, f, indent=2)

        self.load_models()

    def delete_model(self):
        """删除模型"""
        current_row = self.model_list.currentRow()
        if current_row >= 0:
            del self.models[current_row]
            with open(self.config_file, 'w') as f:
                json.dump(self.models, f, indent=2)
            self.load_models()
