"""Ollama API 客户端"""
import json
import os
import random
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import ProxyHandler, Request, build_opener


class OllamaClient:
    """Ollama 本地 API 客户端"""

    def __init__(self, base_url="http://localhost:11434", model="qwen2.5:7b"):
        self.base_url = base_url
        self.model = model
        self._opener = build_opener(ProxyHandler({}))
        self.discovery_timeout_seconds = float(os.getenv("ICU_OLLAMA_DISCOVERY_TIMEOUT_SECONDS", "10"))
        self.chat_timeout_seconds = float(os.getenv("ICU_OLLAMA_CHAT_TIMEOUT_SECONDS", "120"))

    def _get_current_persona(self):
        """获取当前形象的人设"""
        try:
            with open('config/settings.json', 'r') as f:
                config = json.load(f)
            avatar_id = config.get('avatar', {}).get('current_id', 'seal')

            avatar_config_path = Path(f'assets/pets/{avatar_id}/config.json')
            if avatar_config_path.exists():
                with open(avatar_config_path, 'r', encoding='utf-8') as f:
                    avatar_config = json.load(f)
                return avatar_config.get('persona', {})
        except:
            pass
        return {}

    def is_available(self):
        """检测 Ollama 是否可用"""
        try:
            self._request_json("/api/tags", timeout=self.discovery_timeout_seconds)
            return True
        except Exception:
            return False

    def generate_reminder(self, reminder_type, context=None):
        """生成个性化提醒文案"""
        persona = self._get_current_persona()

        # 尝试 AI 生成
        if self.is_available() and persona:
            try:
                name = persona.get('name', '助手')
                traits = persona.get('traits', '')
                tone = persona.get('tone', '')

                system_prompt = f"""你是 {name}，性格：{traits}。
语气：{tone}。
要求：简短、一针见血，不超过30字。"""

                user_prompt = f"用户需要 {reminder_type} 提醒。请生成1句提醒文案。"

                status_code, result = self._request_json(
                    "/api/chat",
                    payload={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": system_prompt},
                            {"role": "user", "content": user_prompt}
                        ],
                        "stream": False,
                        "options": {"temperature": 0.7}
                    },
                    timeout=self.chat_timeout_seconds,
                )

                if status_code == 200:
                    return result['message']['content'].strip()
            except Exception as e:
                print(f"Ollama 调用失败: {e}")

        # 降级到默认文案
        return self._get_default_reminder(reminder_type, persona)

    def _get_default_reminder(self, reminder_type, persona):
        """默认提醒文案（从当前形象的人设库随机选择）"""
        messages = persona.get('messages', {}).get(reminder_type, [])

        if messages:
            return random.choice(messages)

        # 最终兜底
        defaults = {
            'eye_care': '👁️ 该休息眼睛了，看看远处吧',
            'stretch': '🤸 起来活动一下筋骨',
            'hydration': '💧 记得喝水哦'
        }
        return defaults.get(reminder_type, '该休息了')

    def _request_json(self, path, payload=None, timeout=5):
        data = None
        headers = {}
        method = "GET"
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
            method = "POST"

        request = Request(
            f"{self.base_url}{path}",
            data=data,
            headers=headers,
            method=method,
        )

        try:
            with self._opener.open(request, timeout=timeout) as response:
                body = response.read().decode("utf-8")
                return response.status, json.loads(body)
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(detail or str(error)) from error
        except URLError as error:
            raise RuntimeError(str(error.reason)) from error
