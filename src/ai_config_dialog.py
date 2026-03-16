"""AI 配置界面 - 带选项卡版本"""
from PySide6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
                                QLineEdit, QComboBox, QTabWidget, QWidget, QListWidget,
                                QMessageBox)
from PySide6.QtCore import Qt
import json
import requests
from pathlib import Path


class AIConfigDialog(QDialog):
    """AI 配置对话框"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Dialog)
        self.config_file = Path('config/settings.json')
        self.setup_ui()
        self.load_config()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("AI 配置")
        self.setFixedSize(700, 550)

        # 像素风格样式
        self.setStyleSheet("""
            QDialog {
                background-color: #2b2b2b;
            }
            QLabel {
                color: #e0e0e0;
                font-family: 'Courier New', monospace;
            }
            QLineEdit, QComboBox {
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
            QTabWidget::pane {
                border: 3px solid #5a5a5a;
            }
            QTabBar::tab {
                background-color: #3a3a3a;
                color: #e0e0e0;
                padding: 8px 15px;
                font-family: 'Courier New', monospace;
            }
            QTabBar::tab:selected {
                background-color: #4a4a4a;
                color: #00ff00;
            }
        """)

        layout = QVBoxLayout()

        # 标题
        title = QLabel("AI 模型配置")
        title.setStyleSheet("font-size: 16px; font-weight: bold; color: #00ff00;")
        layout.addWidget(title)

        # 选项卡
        self.tabs = QTabWidget()
        self.tabs.addTab(self.create_local_tab(), "本地模型")
        self.tabs.addTab(self.create_remote_tab(), "远端文本模型")
        self.tabs.addTab(self.create_image_tab(), "图像生成模型")
        layout.addWidget(self.tabs)

        # 保存按钮
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

    def create_local_tab(self):
        """本地模型选项卡"""
        widget = QWidget()
        layout = QVBoxLayout()

        layout.addWidget(QLabel("Ollama 配置："))
        
        url_layout = QHBoxLayout()
        url_layout.addWidget(QLabel("API 地址："))
        self.local_url = QLineEdit("http://localhost:11434")
        url_layout.addWidget(self.local_url)
        layout.addLayout(url_layout)

        model_layout = QHBoxLayout()
        model_layout.addWidget(QLabel("模型："))
        self.local_model = QComboBox()
        self.local_model.setEditable(True)
        model_layout.addWidget(self.local_model)

        refresh_btn = QPushButton("刷新")
        refresh_btn.clicked.connect(self.load_local_models)
        model_layout.addWidget(refresh_btn)
        layout.addLayout(model_layout)

        layout.addStretch()
        widget.setLayout(layout)
        return widget

    def create_remote_tab(self):
        """远端文本模型选项卡"""
        widget = QWidget()
        layout = QVBoxLayout()

        layout.addWidget(QLabel("远端文本模型列表："))
        self.remote_list = QListWidget()
        self.remote_list.currentRowChanged.connect(self.on_remote_selected)
        layout.addWidget(self.remote_list)

        form = QVBoxLayout()
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("名称："))
        self.remote_name = QLineEdit()
        name_layout.addWidget(self.remote_name)
        form.addLayout(name_layout)

        url_layout = QHBoxLayout()
        url_layout.addWidget(QLabel("API URL："))
        self.remote_url = QLineEdit()
        url_layout.addWidget(self.remote_url)
        form.addLayout(url_layout)

        key_layout = QHBoxLayout()
        key_layout.addWidget(QLabel("API Key："))
        self.remote_key = QLineEdit()
        self.remote_key.setEchoMode(QLineEdit.Password)
        key_layout.addWidget(self.remote_key)
        form.addLayout(key_layout)

        layout.addLayout(form)

        btn_layout = QHBoxLayout()
        add_btn = QPushButton("新增")
        save_btn = QPushButton("保存")
        del_btn = QPushButton("删除")
        add_btn.clicked.connect(self.add_remote)
        save_btn.clicked.connect(self.save_remote)
        del_btn.clicked.connect(self.delete_remote)
        btn_layout.addWidget(add_btn)
        btn_layout.addWidget(save_btn)
        btn_layout.addWidget(del_btn)
        layout.addLayout(btn_layout)

        widget.setLayout(layout)
        return widget

    def create_image_tab(self):
        """图像生成模型选项卡"""
        widget = QWidget()
        layout = QVBoxLayout()

        layout.addWidget(QLabel("图像生成模型列表："))
        self.image_list = QListWidget()
        self.image_list.currentRowChanged.connect(self.on_image_selected)
        layout.addWidget(self.image_list)

        form = QVBoxLayout()
        name_layout = QHBoxLayout()
        name_layout.addWidget(QLabel("名称："))
        self.image_name = QLineEdit()
        name_layout.addWidget(self.image_name)
        form.addLayout(name_layout)

        url_layout = QHBoxLayout()
        url_layout.addWidget(QLabel("模型ID/URL："))
        self.image_url = QLineEdit()
        url_layout.addWidget(self.image_url)
        form.addLayout(url_layout)

        token_layout = QHBoxLayout()
        token_layout.addWidget(QLabel("Token："))
        self.image_token = QLineEdit()
        self.image_token.setEchoMode(QLineEdit.Password)
        token_layout.addWidget(self.image_token)
        form.addLayout(token_layout)

        layout.addLayout(form)

        btn_layout = QHBoxLayout()
        add_btn = QPushButton("新增")
        save_btn = QPushButton("保存")
        del_btn = QPushButton("删除")
        add_btn.clicked.connect(self.add_image)
        save_btn.clicked.connect(self.save_image)
        del_btn.clicked.connect(self.delete_image)
        btn_layout.addWidget(add_btn)
        btn_layout.addWidget(save_btn)
        btn_layout.addWidget(del_btn)
        layout.addLayout(btn_layout)

        widget.setLayout(layout)
        return widget

    def load_config(self):
        """加载配置"""
        if not self.config_file.exists():
            return

        with open(self.config_file, 'r') as f:
            config = json.load(f)

        # 加载本地模型配置
        local_api = config.get('ai', {}).get('local_api', {})
        if local_api.get('url'):
            self.local_url.setText(local_api['url'])
        self.load_local_models()
        if local_api.get('model'):
            self.local_model.setCurrentText(local_api['model'])

        # 加载远端模型
        self.remote_models = config.get('ai', {}).get('remote_models', [])
        self.remote_list.clear()
        for model in self.remote_models:
            self.remote_list.addItem(model['name'])

        # 加载图像模型
        self.image_models = config.get('ai', {}).get('image_models', [])
        self.image_list.clear()
        for model in self.image_models:
            self.image_list.addItem(model['name'])

    def load_local_models(self):
        """加载本地模型列表"""
        self.local_model.clear()
        try:
            url = self.local_url.text().rstrip('/')
            response = requests.get(f"{url}/api/tags", timeout=2, proxies={'http': None, 'https': None})
            if response.status_code == 200:
                models = response.json().get('models', [])
                for model in models:
                    self.local_model.addItem(model['name'])
        except:
            pass

    def on_remote_selected(self, index):
        """选中远端模型"""
        if index >= 0 and index < len(self.remote_models):
            model = self.remote_models[index]
            self.remote_name.setText(model['name'])
            self.remote_url.setText(model['url'])
            self.remote_key.setText(model.get('key', ''))

    def add_remote(self):
        """新增远端模型"""
        self.remote_name.clear()
        self.remote_url.clear()
        self.remote_key.clear()
        self.remote_list.setCurrentRow(-1)

    def save_remote(self):
        """保存远端模型"""
        name = self.remote_name.text().strip()
        url = self.remote_url.text().strip()
        key = self.remote_key.text().strip()

        if not name or not url:
            QMessageBox.warning(self, "提示", "请填写名称和URL")
            return

        model = {"name": name, "url": url, "key": key}
        current_row = self.remote_list.currentRow()
        if current_row >= 0:
            self.remote_models[current_row] = model
        else:
            self.remote_models.append(model)

        self.remote_list.clear()
        for m in self.remote_models:
            self.remote_list.addItem(m['name'])

    def delete_remote(self):
        """删除远端模型"""
        current_row = self.remote_list.currentRow()
        if current_row >= 0:
            del self.remote_models[current_row]
            self.remote_list.clear()
            for m in self.remote_models:
                self.remote_list.addItem(m['name'])

    def on_image_selected(self, index):
        """选中图像模型"""
        if index >= 0 and index < len(self.image_models):
            model = self.image_models[index]
            self.image_name.setText(model['name'])
            self.image_url.setText(model['url'])
            self.image_token.setText(model.get('token', ''))

    def add_image(self):
        """新增图像模型"""
        self.image_name.clear()
        self.image_url.clear()
        self.image_token.clear()
        self.image_list.setCurrentRow(-1)

    def save_image(self):
        """保存图像模型"""
        name = self.image_name.text().strip()
        url = self.image_url.text().strip()
        token = self.image_token.text().strip()

        if not name or not url:
            QMessageBox.warning(self, "提示", "请填写名称和模型ID/URL")
            return

        model = {"name": name, "url": url, "token": token}
        current_row = self.image_list.currentRow()
        if current_row >= 0:
            self.image_models[current_row] = model
        else:
            self.image_models.append(model)

        self.image_list.clear()
        for m in self.image_models:
            self.image_list.addItem(m['name'])

    def delete_image(self):
        """删除图像模型"""
        current_row = self.image_list.currentRow()
        if current_row >= 0:
            del self.image_models[current_row]
            self.image_list.clear()
            for m in self.image_models:
                self.image_list.addItem(m['name'])

    def save_config(self):
        """保存配置"""
        config = {}
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                config = json.load(f)

        if 'ai' not in config:
            config['ai'] = {}

        config['ai']['local_api'] = {
            'enabled': True,
            'url': self.local_url.text(),
            'model': self.local_model.currentText()
        }
        config['ai']['remote_models'] = self.remote_models
        config['ai']['image_models'] = self.image_models

        with open(self.config_file, 'w') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        QMessageBox.information(self, "成功", "配置已保存")
        self.accept()
