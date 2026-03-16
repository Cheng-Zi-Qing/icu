"""测试桌宠 UI"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from PySide6.QtWidgets import QApplication
from src.pet_widget import PetWidget


def test_pet_widget():
    """测试桌宠窗口"""
    app = QApplication(sys.argv)
    pet = PetWidget()
    pet.show()

    # 测试状态切换
    pet.set_state('working')
    assert pet.current_state == 'working'

    pet.set_state('idle')
    assert pet.current_state == 'idle'

    print("✅ 桌宠窗口测试通过")
    pet.close()


if __name__ == '__main__':
    test_pet_widget()
