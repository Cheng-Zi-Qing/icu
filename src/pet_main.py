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
    from src.pet_instance import set_pet_instance

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    state_sync = StateSync()
    pet = PetWidget()
    set_pet_instance(pet)  # 注册全局实例

    # 启动提醒系统
    from src.reminder import ReminderSystem
    reminder = ReminderSystem()

    # 初始状态设为 idle（在监听前设置）
    state_sync.write_state('idle')
    pet.set_state('idle')

    # 监听状态变化
    def on_state_change(state_data):
        if state_data:
            new_state = state_data.get('state', 'idle')
            pet.set_state(new_state)

            # 根据状态控制提醒系统
            if new_state in ['working', 'focus']:
                reminder.start()
            else:
                reminder.stop()

    state_sync.watch_state(on_state_change)

    # 检查是否需要显示周报
    from src.weekly_check import WeeklyCheck
    weekly = WeeklyCheck()
    if weekly.should_show_report():
        from src.weekly_report import WeeklyReportDialog
        from src.daily_stats import DailyStats

        stats = DailyStats()
        week_data = stats.get_week_stats()

        dialog = WeeklyReportDialog(week_data, pet)
        dialog.exec()
        weekly.mark_shown()  # 无论如何都标记已显示

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
