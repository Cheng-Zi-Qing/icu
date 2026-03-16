"""
I.C.U. - Intelligent Care Unit
基于 FSM 的健康状态管理桌宠
"""
from src.menu_bar import ICUMenuBar
from src.logger import logger


def main():
    logger.info("启动 I.C.U. 应用")
    app = ICUMenuBar()
    app.pet.quit_requested.connect(app.quit_application)
    app.run()


if __name__ == "__main__":
    main()
