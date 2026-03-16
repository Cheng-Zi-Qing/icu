"""
I.C.U. - Intelligent Care Unit
基于 FSM 的健康状态管理桌宠
"""
import sys
import os
import fcntl
from src.menu_bar import ICUMenuBar
from src.logger import logger


def main():
    # 单实例锁
    lock_file = '/tmp/icu_menu.lock'
    try:
        lock_fd = open(lock_file, 'w')
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.write(str(os.getpid()))
        lock_fd.flush()
    except IOError:
        logger.error("菜单栏已在运行")
        sys.exit(0)

    logger.info("启动 I.C.U. 应用")
    app = ICUMenuBar()
    app.run()


if __name__ == "__main__":
    main()
