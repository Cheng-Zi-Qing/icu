"""提示词优化器"""
import requests


class PromptOptimizer:
    def __init__(self, ollama_url="http://localhost:11434"):
        self.ollama_url = ollama_url
        self.model = None

    def check_ollama(self):
        """检查并选择模型"""
        try:
            response = requests.get(f"{self.ollama_url}/api/tags", timeout=2, proxies={'http': None, 'https': None})
            models = response.json().get('models', [])
            model_names = [m['name'] for m in models]

            if 'qwen3.5:35b' in model_names:
                self.model = 'qwen3.5:35b'
                return True
            elif 'qwen2.5:27b' in model_names:
                self.model = 'qwen2.5:27b'
                return True
            return False
        except:
            return False

    def optimize(self, user_input):
        """优化提示词"""
        if not self.check_ollama():
            return None

        system_prompt = """你是图像生成提示词专家。
将用户的简短描述扩展为详细的英文图像生成提示词。

关键要求：
1. 单个角色，居中构图
2. 纯白色背景（solid white background）
3. 高对比度，边缘清晰
4. 像素风格（pixel art, 16-bit style）
5. 描述具体动作姿势
6. 简洁明确，适合 Stable Diffusion

输出格式：只输出英文提示词，不要解释"""

        user_message = f"用户描述：{user_input}\n\n请生成图像提示词："

        response = requests.post(
            f"{self.ollama_url}/api/chat",
            json={
                "model": self.model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ],
                "options": {"temperature": 0.7},
                "stream": False
            },
            proxies={'http': None, 'https': None}
        )

        result = response.json()
        return result['message']['content']
