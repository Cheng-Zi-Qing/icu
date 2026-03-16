"""桌宠独立进程入口"""
import sys
import os
import fcntl


def main():
    # 单实例锁
    lock_file = '/tmp/icu_pet.lock'
    try:
        lock_fd = open(lock_file, 'w')
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.write(str(os.getpid()))
        lock_fd.flush()
    except IOError:
        print("桌宠已在运行")
        sys.exit(0)

    from PySide6.QtWidgets import QApplication
    from PySide6.QtCore import Qt
    from src.pet_widget import PetWidget
    from src.state_sync import StateSync

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    state_sync = StateSync()
    pet = PetWidget()

    # 监听状态变化
    def on_state_change(state_data):
        if state_data:
            pet.set_state(state_data.get('state', 'idle'))

    state_sync.watch_state(on_state_change)

    # 初始状态
    initial_state = state_sync.read_state()
    if initial_state:
        pet.set_state(initial_state.get('state', 'idle'))

    # 退出信号
    pet.quit_requested.connect(lambda: (
        state_sync.write_state('quit'),
        state_sync.stop_watch(),
        app.quit()
    ))

    pet.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()

    # 托盘菜单
    tray_menu = QMenu()
    show_action = tray_menu.addAction("显示/隐藏")
    quit_action = tray_menu.addAction("退出")

    show_action.triggered.connect(lambda: pet.setVisible(not pet.isVisible()))
    quit_action.triggered.connect(app.quit)

    tray_icon.setContextMenu(tray_menu)
    tray_icon.show()

    # 监听状态变化
    def on_state_change(state_data):
        if state_data:
            pet.set_state(state_data.get('state', 'idle'))

    state_sync.watch_state(on_state_change)

    # 初始状态
    initial_state = state_sync.read_state()
    if initial_state:
        pet.set_state(initial_state.get('state', 'idle'))

    # 退出信号
    pet.quit_requested.connect(lambda: (
        state_sync.write_state('quit'),
        state_sync.stop_watch(),
        app.quit()
    ))

    pet.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
