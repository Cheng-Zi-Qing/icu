"""桌宠窗口模块"""
from PySide6.QtWidgets import QWidget, QLabel, QMenu
from PySide6.QtCore import Qt, QTimer, QPoint, Signal
from PySide6.QtGui import QPixmap, QPainter, QAction
import math
import time


class PetWidget(QWidget):
    """桌宠窗口"""

    quit_requested = Signal()

    def __init__(self, pet_id='seal'):
        super().__init__()
        self.pet_id = pet_id
        self.start_time = time.time()
        self.drag_position = None

        # 窗口设置
        self.setWindowFlags(
            Qt.FramelessWindowHint |
            Qt.WindowStaysOnTopHint |
            Qt.Tool
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setFixedSize(128, 128)

        # 加载形象
        self.label = QLabel(self)
        self.load_pet_image()

        # 动画定时器
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_animation)
        self.timer.start(33)  # 30 FPS

        self.current_state = 'idle'

    def load_pet_image(self):
        """加载桌宠图片"""
        pixmap = QPixmap(f'assets/pets/{self.pet_id}/base.png')
        if pixmap.isNull():
            pixmap = QPixmap(64, 64)
            pixmap.fill(Qt.gray)
        self.base_pixmap = pixmap.scaled(64, 64, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self.label.setPixmap(self.base_pixmap)
        self.label.setGeometry(32, 32, 64, 64)

    def update_animation(self):
        """更新动画"""
        t = time.time() - self.start_time

        if self.current_state == 'idle':
            y_offset = int(math.sin(t * 2) * 5)
            self.label.move(32, 32 + y_offset)
        elif self.current_state == 'working':
            x_offset = int(math.sin(t * 3) * 3)
            self.label.move(32 + x_offset, 32)

    def set_state(self, state):
        """设置动画状态"""
        self.current_state = state

    def mousePressEvent(self, event):
        """鼠标按下"""
        if event.button() == Qt.LeftButton:
            self.drag_position = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
        elif event.button() == Qt.RightButton:
            self.show_context_menu(event.globalPosition().toPoint())

    def show_context_menu(self, pos):
        """显示右键菜单"""
        menu = QMenu(self)
        quit_action = menu.addAction("退出")
        action = menu.exec(pos)
        if action == quit_action:
            self.quit_requested.emit()

    def mouseMoveEvent(self, event):
        """鼠标拖拽"""
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPosition().toPoint() - self.drag_position)
