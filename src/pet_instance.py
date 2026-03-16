"""全局桌宠实例"""

_pet_instance = None


def set_pet_instance(pet):
    """设置桌宠实例"""
    global _pet_instance
    _pet_instance = pet


def get_pet_instance():
    """获取桌宠实例"""
    return _pet_instance
