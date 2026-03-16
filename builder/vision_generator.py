"""第二层：躯体铸造 (Vision Generation)"""
import time
from pathlib import Path
from huggingface_hub import InferenceClient


class VisionGenerator:
    def __init__(self, checkpoint_dir="/tmp/icu_build", hf_token=None):
        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_file = self.checkpoint_dir / "step2_raw_sheet.png"
        self.hf_token = hf_token
        self.max_retries = 3

    def generate(self, prompt, force=False):
        """生成图像"""
        if not force and self.checkpoint_file.exists():
            print("📦 使用缓存的图像")
            return str(self.checkpoint_file)

        if not self.hf_token:
            print("❌ 错误：未设置 HF_TOKEN")
            print("💡 请设置环境变量：export HF_TOKEN=your_token")
            return None

        print("🎨 正在生成图像...")
        client = InferenceClient(token=self.hf_token)

        for attempt in range(self.max_retries):
            try:
                image = client.text_to_image(
                    prompt=prompt,
                    model="stabilityai/stable-diffusion-xl-base-1.0"
                )

                if image.size[0] < 512 or image.size[1] < 512:
                    raise ValueError("生成的图片尺寸过小")

                self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
                image.save(self.checkpoint_file)
                print(f"✅ 图像生成完成")
                return str(self.checkpoint_file)

            except Exception as e:
                print(f"⚠️ 第 {attempt + 1} 次尝试失败：{e}")
                if attempt < self.max_retries - 1:
                    wait_time = 5 * (2 ** attempt)
                    print(f"  等待 {wait_time} 秒后重试...")
                    time.sleep(wait_time)

        return None
