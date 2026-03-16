#!/usr/bin/env python3
"""桌宠启动器 - 隐藏 Dock 图标"""
import sys
import os

# 设置 LSUIElement
os.environ['PYTHONEXECUTABLE'] = sys.executable

# 启动桌宠
if __name__ == '__main__':
    from src.pet_main import main
    main()
