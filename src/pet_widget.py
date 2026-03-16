"""桌宠窗口模块"""
from PySide6.QtWidgets import QWidget, QLabel, QMenu, QApplication
from PySide6.QtCore import Qt, QTimer, QPoint, Signal, QPropertyAnimation, QEasingCurve
from PySide6.QtGui import QPixmap, QPainter, QAction
import math
import time
import json


class PetWidget(QWidget):
    """桌宠窗口"""

    quit_requested = Signal()
    show_bubble_signal = Signal(str, str, int)  # 气泡信号(消息, 提醒类型, 持续时间)

    def __init__(self, pet_id=None):
        super().__init__()

        # 从配置读取形象ID
        if pet_id is None:
            try:
                with open('config/settings.json', 'r') as f:
                    config = json.load(f)
                pet_id = config.get('avatar', {}).get('current_id', 'seal')
            except:
                pet_id = 'seal'

        self.pet_id = pet_id
        self.start_time = time.time()
        self.drag_position = None
        self.edge_snap_enabled = True
        self.snap_distance = 20
        self.peek_width = 10
        self.is_hidden = False
        self.current_edge = None
        self.bubble = None

        # 窗口设置
        self.setWindowFlags(
            Qt.FramelessWindowHint |
            Qt.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating)
        self.setFixedSize(128, 128)

        # 初始位置（屏幕右下角）
        screen = QApplication.primaryScreen().geometry()
        self.move(screen.width() - 150, screen.height() - 150)

        # 加载形象
        self.label = QLabel(self)
        self.load_pet_image()

        # 动画定时器
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_animation)
        self.timer.start(33)  # 30 FPS

        # 自动隐藏定时器
        self.hide_timer = QTimer(self)
        self.hide_timer.timeout.connect(self._auto_hide)
        self.hide_timer.setSingleShot(True)

        # 鼠标检测定时器
        self.mouse_check_timer = QTimer(self)
        self.mouse_check_timer.timeout.connect(self._check_mouse_position)
        self.mouse_check_timer.start(100)

        self.current_state = 'idle'

        # 连接气泡信号
        self.show_bubble_signal.connect(self._show_bubble_slot)

    def load_pet_image(self):
        """加载桌宠图片"""
        pixmap = QPixmap(f'assets/pets/{self.pet_id}/base.png')
        if pixmap.isNull():
            pixmap = QPixmap(64, 64)
            pixmap.fill(Qt.gray)
        self.base_pixmap = pixmap.scaled(64, 64, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        self.label.setPixmap(self.base_pixmap)
        self.label.setGeometry(32, 32, 64, 64)
        self.label.setVisible(True)
        self.setWindowOpacity(1.0)
        self.current_state = 'idle'
        self.start_time = time.time()

    def update_animation(self):
        """更新动画"""
        t = time.time() - self.start_time

        animations = {
            'idle': lambda: self._animate_idle(t),
            'working': lambda: self._animate_working(t),
            'focus': lambda: self._animate_focus(t),
            'break': lambda: self._animate_break(t),
            'eye_care': lambda: self._animate_eye_care(t),
            'stretch': lambda: self._animate_stretch(t),
            'hydration': lambda: self._animate_hydration(t)
        }

        if self.current_state in animations:
            animations[self.current_state]()

    def _animate_idle(self, t):
        """待机 - 竖直浮动"""
        y_offset = int(math.sin(t * 2) * 5)
        self.label.move(32, 32 + y_offset)

    def _animate_working(self, t):
        """工作 - 水平摇晃"""
        x_offset = int(math.sin(t * 3) * 3)
        self.label.move(32 + x_offset, 32)

    def _animate_focus(self, t):
        """专注 - 缩小半透明"""
        scale = 0.8
        size = int(64 * scale)
        offset = (64 - size) // 2
        self.label.setGeometry(32 + offset, 32 + offset, size, size)
        self.setWindowOpacity(0.6)

    def _animate_break(self, t):
        """暂离 - 旋转摇摆"""
        rotation = int(math.sin(t) * 10)
        scale = 1.1
        size = int(64 * scale)
        offset = (64 - size) // 2
        self.label.setGeometry(32 + offset, 32 + offset, size, size)

    def _animate_eye_care(self, t):
        """护眼 - 眨眼效果"""
        blink = int(t * 3) % 3 == 0
        self.label.setVisible(not blink)

    def _animate_stretch(self, t):
        """拉伸 - 纵向拉伸"""
        scale_y = 1 + math.sin(t * 4) * 0.2
        height = int(64 * scale_y)
        y_offset = (64 - height) // 2
        self.label.setGeometry(32, 32 + y_offset, 64, height)

    def _animate_hydration(self, t):
        """补水 - 跳跃动画"""
        y_offset = int(abs(math.sin(t * 5)) * 20)
        self.label.move(32, 32 - y_offset)

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
        menu.setStyleSheet("""
            QMenu {
                background-color: #2b2b2b;
                color: #e0e0e0;
                border: 2px solid #4a4a4a;
                font-family: 'Courier New', monospace;
                font-size: 13px;
            }
            QMenu::item {
                padding: 8px 20px;
            }
            QMenu::item:selected {
                background-color: #3a3a3a;
                color: #00ff00;
            }
            QMenu::separator {
                height: 2px;
                background-color: #4a4a4a;
            }
        """)

        # 读取当前状态
        try:
            with open('data/current_state.json', 'r') as f:
                state_data = json.load(f)
                current_state = state_data.get('state', 'idle')
        except:
            current_state = 'idle'

        # 根据状态显示不同菜单
        start_work_action = None
        focus_action = None
        break_action = None
        stop_work_action = None
        resume_work_action = None

        if current_state == 'idle':
            start_work_action = menu.addAction("开始工作")
        elif current_state == 'working':
            focus_action = menu.addAction("进入专注")
            break_action = menu.addAction("暂离")
            stop_work_action = menu.addAction("下班")
        elif current_state in ['focus', 'break']:
            resume_work_action = menu.addAction("回来工作")
            stop_work_action = menu.addAction("下班")

        menu.addSeparator()
        change_avatar_action = menu.addAction("更换形象")
        user_config_action = menu.addAction("个人设置")
        ai_config_action = menu.addAction("AI 配置")
        quit_action = menu.addAction("退出")

        action = menu.exec(pos)

        if action == quit_action:
            self.quit_requested.emit()
        elif action == change_avatar_action:
            self.show_avatar_selector()
        elif action == user_config_action:
            self.show_user_config()
        elif action == ai_config_action:
            self.show_ai_config()
        elif action == start_work_action:
            self.trigger_state_change('working')
        elif action == resume_work_action:
            self.trigger_state_change('working')
        elif action == focus_action:
            self.trigger_state_change('focus')
        elif action == break_action:
            self.trigger_state_change('break')
        elif action == stop_work_action:
            self.trigger_state_change('idle')

    def mouseMoveEvent(self, event):
        """鼠标拖拽"""
        if event.buttons() == Qt.LeftButton and self.drag_position:
            self.move(event.globalPosition().toPoint() - self.drag_position)
            self.is_hidden = False
            self.current_edge = None

    def mouseReleaseEvent(self, event):
        """鼠标释放"""
        if event.button() == Qt.LeftButton:
            self._check_edge_snap()

    def _check_edge_snap(self):
        """检查是否靠近边缘"""
        if not self.edge_snap_enabled:
            return

        screen = QApplication.primaryScreen().geometry()
        pos = self.pos()

        if pos.x() < self.snap_distance:
            self._snap_to_edge('left')
        elif pos.x() + self.width() > screen.width() - self.snap_distance:
            self._snap_to_edge('right')
        elif pos.y() < self.snap_distance:
            self._snap_to_edge('top')
        elif pos.y() + self.height() > screen.height() - self.snap_distance:
            self._snap_to_edge('bottom')

    def _snap_to_edge(self, edge):
        """吸附到边缘"""
        screen = QApplication.primaryScreen().geometry()
        snap_pos = QPoint(self.pos())

        if edge == 'left':
            snap_pos.setX(0)
        elif edge == 'right':
            snap_pos.setX(screen.width() - self.width())
        elif edge == 'top':
            snap_pos.setY(0)
        elif edge == 'bottom':
            snap_pos.setY(screen.height() - self.height())

        self.snap_animation = QPropertyAnimation(self, b"pos")
        self.snap_animation.setDuration(300)
        self.snap_animation.setEasingCurve(QEasingCurve.OutCubic)
        self.snap_animation.setEndValue(snap_pos)
        self.snap_animation.start()

        self.current_edge = edge
        self.hide_timer.start(2000)

    def _auto_hide(self):
        """自动隐藏"""
        if not self.current_edge:
            return

        screen = QApplication.primaryScreen().geometry()
        hidden_pos = QPoint(self.pos())

        if self.current_edge == 'left':
            hidden_pos.setX(-self.width() + self.peek_width)
        elif self.current_edge == 'right':
            hidden_pos.setX(screen.width() - self.peek_width)
        elif self.current_edge == 'top':
            hidden_pos.setY(-self.height() + self.peek_width)
        elif self.current_edge == 'bottom':
            hidden_pos.setY(screen.height() - self.peek_width)

        self.hide_animation = QPropertyAnimation(self, b"pos")
        self.hide_animation.setDuration(500)
        self.hide_animation.setEasingCurve(QEasingCurve.InOutQuad)
        self.hide_animation.setEndValue(hidden_pos)
        self.hide_animation.start()

        self.is_hidden = True

    def enterEvent(self, event):
        """鼠标悬停唤醒"""
        if self.is_hidden:
            self._show_from_edge()

    def _check_mouse_position(self):
        """检测鼠标位置以唤醒隐藏的窗口"""
        if not self.is_hidden or not self.current_edge:
            return

        cursor_pos = QApplication.primaryScreen().availableGeometry().topLeft()
        from PySide6.QtGui import QCursor
        cursor_pos = QCursor.pos()
        screen = QApplication.primaryScreen().geometry()

        # 检测鼠标是否在边缘区域
        trigger_zone = 5
        should_show = False

        if self.current_edge == 'left' and cursor_pos.x() < trigger_zone:
            should_show = True
        elif self.current_edge == 'right' and cursor_pos.x() > screen.width() - trigger_zone:
            should_show = True
        elif self.current_edge == 'top' and cursor_pos.y() < trigger_zone:
            should_show = True
        elif self.current_edge == 'bottom' and cursor_pos.y() > screen.height() - trigger_zone:
            should_show = True

        if should_show:
            self._show_from_edge()

    def _show_from_edge(self):
        """从边缘滑出"""
        if not self.current_edge:
            return

        screen = QApplication.primaryScreen().geometry()
        show_pos = QPoint(self.pos())

        if self.current_edge == 'left':
            show_pos.setX(0)
        elif self.current_edge == 'right':
            show_pos.setX(screen.width() - self.width())
        elif self.current_edge == 'top':
            show_pos.setY(0)
        elif self.current_edge == 'bottom':
            show_pos.setY(screen.height() - self.height())

        self.show_animation = QPropertyAnimation(self, b"pos")
        self.show_animation.setDuration(300)
        self.show_animation.setEasingCurve(QEasingCurve.OutCubic)
        self.show_animation.setEndValue(show_pos)
        self.show_animation.start()

        self.is_hidden = False
        self.hide_timer.start(2000)

    def show_avatar_selector(self):
        """显示形象选择器"""
        import json
        from src.avatar_manager import AvatarManager
        from src.avatar_selector import AvatarSelector

        # 读取当前形象
        with open('config/settings.json', 'r') as f:
            config = json.load(f)
        current_id = config.get('avatar', {}).get('current_id', 'seal')

        # 显示选择器
        manager = AvatarManager()
        selector = AvatarSelector(manager, current_id, self)

        if selector.exec():
            # 保存选择
            config['avatar']['current_id'] = selector.selected_id
            with open('config/settings.json', 'w') as f:
                json.dump(config, f, indent=2)

            # 重新加载形象
            self.pet_id = selector.selected_id
            self.load_pet_image()

    def show_user_config(self):
        """显示个人设置"""
        from src.user_config_dialog import UserConfigDialog
        dialog = UserConfigDialog(self)
        dialog.exec()

    def show_ai_config(self):
        """显示 AI 配置"""
        from src.ai_config_dialog import AIConfigDialog
        dialog = AIConfigDialog(self)
        dialog.exec()

    def trigger_state_change(self, new_state):
        """触发状态切换"""
        old_state = None
        try:
            with open('data/current_state.json', 'r') as f:
                old_state = json.load(f).get('state')
        except:
            pass

        with open('data/current_state.json', 'w') as f:
            json.dump({'state': new_state, 'timestamp': int(time.time())}, f)

        # 下班时弹出每日报告
        if old_state == 'working' and new_state == 'idle':
            self.show_daily_report()

    def show_daily_report(self):
        """显示每日报告"""
        from src.daily_report import DailyReportDialog
        from src.daily_stats import DailyStats

        stats = DailyStats()
        today_stats = stats.get_today_stats()

        dialog = DailyReportDialog(today_stats, self)
        dialog.exec()

    def show_bubble(self, message, reminder_type='info', duration=10000):
        """显示气泡提示（线程安全）"""
        self.show_bubble_signal.emit(message, reminder_type, duration)

    def _show_bubble_slot(self, message, reminder_type, duration):
        """气泡显示槽函数（主线程）"""
        from src.bubble_label import BubbleLabel

        if self.bubble:
            self.bubble.hide()

        self.bubble = BubbleLabel(message, reminder_type, self)
        self.bubble.completed.connect(self._on_reminder_completed)
        self.bubble.ignored.connect(self._on_reminder_ignored)

        # 气泡位置：桌宠上方
        bubble_x = self.x() + (self.width() - self.bubble.width()) // 2
        bubble_y = self.y() - self.bubble.height() - 10
        self.bubble.move(bubble_x, bubble_y)

        self.bubble.show_bubble(duration)

    def _on_reminder_completed(self, reminder_type):
        """提醒完成"""
        from src.daily_stats import DailyStats
        stats = DailyStats()
        stats.log_reminder_response(reminder_type, True)

    def _on_reminder_ignored(self, reminder_type):
        """提醒忽略"""
        from src.daily_stats import DailyStats
        stats = DailyStats()
        stats.log_reminder_response(reminder_type, False)

