"""形象管理器模块"""
import json
from pathlib import Path
from PySide6.QtGui import QPixmap


class Avatar:
    """形象类"""
    def __init__(self, avatar_id, config, pixmap):
        self.id = avatar_id
        self.name = config['name']
        self.style = config.get('style', '')
        self.persona = config.get('persona', {})
        self.pixmap = pixmap


class AvatarManager:
    """形象管理器"""
    def __init__(self, avatars_dir='assets/pets'):
        self.avatars_dir = Path(avatars_dir)
        self.avatars = {}
        self._load_all_avatars()

    def _load_all_avatars(self):
        """加载所有形象"""
        if not self.avatars_dir.exists():
            return

        for avatar_dir in self.avatars_dir.iterdir():
            if avatar_dir.is_dir():
                avatar = self._load_avatar(avatar_dir.name)
                if avatar:
                    self.avatars[avatar.id] = avatar

    def _load_avatar(self, avatar_id):
        """加载单个形象"""
        avatar_path = self.avatars_dir / avatar_id
        config_file = avatar_path / 'config.json'
        image_file = avatar_path / 'base.png'

        if not config_file.exists() or not image_file.exists():
            return None

        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)

            pixmap = QPixmap(str(image_file))
            if pixmap.isNull():
                return None

            return Avatar(avatar_id, config, pixmap)
        except Exception:
            return None

    def get_avatar(self, avatar_id):
        """获取指定形象"""
        return self.avatars.get(avatar_id)

    def list_avatars(self):
        """列出所有形象"""
        return list(self.avatars.values())
