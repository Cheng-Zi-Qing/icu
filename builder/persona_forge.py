"""第一层：灵魂锻造 (LLM Persona Expansion)"""
import json
import requests
from pathlib import Path


class PersonaForge:
    def __init__(self, checkpoint_dir="/tmp/icu_build"):
        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_file = self.checkpoint_dir / "step1_persona.json"
        self.ollama_url = "http://localhost:11434"

    def check_ollama(self):
        """检查 Ollama 是否运行"""
        try:
            response = requests.get(f"{self.ollama_url}/api/tags", timeout=2, proxies={'http': None, 'https': None})
            models = response.json().get('models', [])
            model_names = [m['name'] for m in models]

            # 优先使用 35b，其次 27b
            if 'qwen3.5:35b' in model_names:
                self.model = 'qwen3.5:35b'
                return True
            elif 'qwen2.5:27b' in model_names:
                self.model = 'qwen2.5:27b'
                return True
            else:
                print("❌ 错误：未找到 qwen 模型")
                print("💡 请先运行：ollama pull qwen2.5:27b")
                return False
        except:
            print("❌ 错误：Ollama 未启动")
            print("💡 请先运行：ollama serve")
            return False

    def forge(self, user_prompt, force=False):
        """锻造 persona"""
        if not force and self.checkpoint_file.exists():
            print("📦 使用缓存的 persona 配置")
            with open(self.checkpoint_file, 'r', encoding='utf-8') as f:
                return json.load(f)

        if not self.check_ollama():
            return None

        print("🔥 正在锻造灵魂...")

        system_prompt = """你是桌宠资产生成助手。
你的任务是将用户的简短描述扩展为完整的桌宠配置。

输出规则：
1. 必须严格遵循 JSON Schema
2. image_generation_prompt 必须是英文
3. 必须包含 "solid white background"
4. 必须包含 "3 distinct poses arranged in a grid"
5. expected_actions 只能从 ["idle", "working", "alert"] 中选择
"""

        user_message = f"""
用户输入：{user_prompt}

请生成标准配置 JSON，包含以下字段：
{{
  "pet_id": "英文ID（小写+下划线）",
  "display_name": "中文显示名",
  "image_generation_prompt": "详细的英文画图提示词",
  "ai_persona_system_prompt": "AI人设描述（中文）",
  "expected_actions": ["idle", "working", "alert"]
}}
"""

        response = requests.post(
            f"{self.ollama_url}/api/chat",
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ],
                "format": "json",
                "options": {"temperature": 0.3},
                "stream": False
            },
            proxies={'http': None, 'https': None}
        )

        result = response.json()
        content = result['message']['content']
        persona_data = json.loads(content)

        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
        with open(self.checkpoint_file, 'w', encoding='utf-8') as f:
            json.dump(persona_data, f, indent=2, ensure_ascii=False)

        print(f"✅ 灵魂锻造完成：{persona_data['display_name']}")
        return persona_data
