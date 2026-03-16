"""形象选择器UI模块"""
from PySide6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout,
                                QListWidget, QLabel, QPushButton,
                                QFileDialog, QMessageBox)
from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap


class AvatarSelector(QDialog):
    """形象选择器对话框"""
    def __init__(self, avatar_manager, current_id=None, parent=None):
        super().__init__(parent)
        self.avatar_manager = avatar_manager
        self.selected_id = current_id
        self.setup_ui()
        self.load_avatars()

    def setup_ui(self):
        """设置UI"""
        self.setWindowTitle("选择你的桌宠形象")
        self.setFixedSize(500, 600)

        layout = QVBoxLayout()

        # 标题
        title = QLabel("选择你的桌宠形象")
        title.setStyleSheet("font-size: 16px; font-weight: bold;")

        # 形象列表
        self.avatar_list = QListWidget()
        self.avatar_list.currentRowChanged.connect(self.on_avatar_selected)

        # 预览区域
        preview_layout = QHBoxLayout()
        self.preview_label = QLabel()
        self.preview_label.setFixedSize(128, 128)
        self.preview_label.setAlignment(Qt.AlignCenter)
        self.preview_label.setStyleSheet("border: 1px solid #ccc;")

        self.info_label = QLabel()
        self.info_label.setWordWrap(True)
        self.info_label.setAlignment(Qt.AlignTop)

        preview_layout.addWidget(self.preview_label)
        preview_layout.addWidget(self.info_label, 1)

        # 按钮
        button_layout = QHBoxLayout()
        self.custom_btn = QPushButton("+ 新增自定义形象")
        self.cancel_btn = QPushButton("取消")
        self.select_btn = QPushButton("选择")

        self.select_btn.clicked.connect(self.accept)
        self.custom_btn.clicked.connect(self.add_custom_avatar)
        self.cancel_btn.clicked.connect(self.reject)

        button_layout.addWidget(self.custom_btn)
        button_layout.addStretch()
        button_layout.addWidget(self.cancel_btn)
        button_layout.addWidget(self.select_btn)

        layout.addWidget(title)
        layout.addWidget(self.avatar_list)
        layout.addLayout(preview_layout)
        layout.addLayout(button_layout)

        self.setLayout(layout)

    def load_avatars(self):
        """加载形象列表"""
        avatars = self.avatar_manager.list_avatars()
        for i, avatar in enumerate(avatars):
            self.avatar_list.addItem(f"{avatar.name} ({avatar.style})")
            if avatar.id == self.selected_id:
                self.avatar_list.setCurrentRow(i)

    def on_avatar_selected(self, index):
        """形象选中事件"""
        avatars = self.avatar_manager.list_avatars()
        if 0 <= index < len(avatars):
            avatar = avatars[index]
            self.selected_id = avatar.id

            # 更新预览
            pixmap = avatar.pixmap.scaled(128, 128, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            self.preview_label.setPixmap(pixmap)

            # 更新信息
            info = f"<b>{avatar.name}</b><br>"
            info += f"风格：{avatar.style}<br><br>"
            if avatar.persona:
                info += f"性格：{avatar.persona.get('traits', '')}<br>"
                info += f"语气：{avatar.persona.get('tone', '')}"
            self.info_label.setText(info)

    def add_custom_avatar(self):
        """添加自定义形象"""
        from src.avatar_wizard import AvatarWizard
        wizard = AvatarWizard(self)
        if wizard.exec():
            # 重新加载形象列表
            self.avatar_list.clear()
            self.load_avatars()
