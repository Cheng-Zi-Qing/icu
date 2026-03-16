"""AI 助手模块"""
import json
from pathlib import Path
from src.ollama_client import OllamaClient
from src.logger import logger


class AIAssistant:
    """AI 助手"""

    def __init__(self):
        self.config = self._load_config()
        self.ollama = None
        if self.config.get('mode') == 'local':
            local_api = self.config.get('local_api', {})
            self.ollama = OllamaClient(
                local_api.get('url', 'http://localhost:11434'),
                local_api.get('model', 'qwen2.5:7b')
            )

    def _load_config(self):
        """加载 AI 配置"""
        config_path = Path('config/settings.json')
        if config_path.exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('ai', {})
        return {'mode': 'fixed'}

    def generate_reminder(self, reminder_type):
        """生成提醒文案"""
        if self.ollama:
            try:
                return self.ollama.generate_reminder(reminder_type)
            except Exception as e:
                logger.warning(f"AI 生成失败: {e}")

        # 降级到 OllamaClient 的默认文案
        if not self.ollama:
            self.ollama = OllamaClient()
        return self.ollama.generate_reminder(reminder_type)
