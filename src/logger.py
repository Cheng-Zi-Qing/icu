"""日志模块"""
import logging
import sys
from pathlib import Path


def setup_logger(name='icu', level=logging.DEBUG):
    """配置日志"""
    logger = logging.getLogger(name)
    logger.setLevel(level)

    # 控制台输出
    console = logging.StreamHandler(sys.stdout)
    console.setLevel(level)
    console.setFormatter(logging.Formatter(
        '%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        datefmt='%H:%M:%S'
    ))
    logger.addHandler(console)

    # 文件输出
    log_dir = Path('logs')
    log_dir.mkdir(exist_ok=True)
    file_handler = logging.FileHandler(log_dir / 'icu.log')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s [%(levelname)s] %(name)s:%(lineno)d - %(message)s'
    ))
    logger.addHandler(file_handler)

    return logger


# 全局 logger
logger = setup_logger()
