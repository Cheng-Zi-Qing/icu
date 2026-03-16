"""AI 助手模块"""
import json
import random
import requests
from pathlib import Path
from src.logger import logger


class AIAssistant:
    """AI 助手"""

    def __init__(self):
        self.config = self._load_config()
        self.messages = self._load_messages()

    def _load_config(self):
        """加载 AI 配置"""
        config_path = Path('config/settings.json')
        if config_path.exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('ai', {})
        return {'mode': 'fixed'}

    def _load_messages(self):
        """加载固定文案"""
        path = Path('config/reminders.json')
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)

    def generate_reminder(self, reminder_type):
        """生成提醒文案"""
        if self.config.get('mode') == 'local' and self._ollama_available():
            try:
                return self._call_ollama(reminder_type)
            except Exception as e:
                logger.warning(f"Ollama 失败: {e}, 降级到固定文案")

        return self._get_fallback_message(reminder_type)

    def _ollama_available(self):
        """检查 Ollama 是否可用"""
        try:
            url = self.config.get('local_api', {}).get('url', 'http://localhost:11434')
            requests.get(url, timeout=1)
            return True
        except:
            return False

    def _call_ollama(self, reminder_type):
        """调用 Ollama API"""
        persona = self.messages.get('personas', {}).get('seal', {})
        prompt = f"你是{persona.get('name', '助手')}，性格：{persona.get('traits', '')}。用户触发了{reminder_type}提醒。输出1句话（不超过30字）。"

        url = self.config.get('local_api', {}).get('url', 'http://localhost:11434')
        response = requests.post(f'{url}/api/generate', json={
            'model': self.config.get('local_api', {}).get('model', 'qwen2.5:7b'),
            'prompt': prompt,
            'stream': False
        }, timeout=3)

        return response.json()['response']

    def _get_fallback_message(self, reminder_type):
        """降级到固定文案"""
        messages = self.messages.get(reminder_type, [])
        return random.choice(messages) if messages else "该休息了！"
