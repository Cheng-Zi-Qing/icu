"""使用 Hugging Face SDK 生成桌宠形象"""
import os
import json
from pathlib import Path
from huggingface_hub import InferenceClient
from PIL import Image

HF_TOKEN = os.getenv("HF_TOKEN", "")

client = InferenceClient(provider="hf-inference", api_key=HF_TOKEN)

def remove_white_background(image):
    """移除白色背景"""
    image = image.convert("RGBA")
    data = image.getdata()
    new_data = []
    for item in data:
        # 只移除纯白色
        if item[0] > 250 and item[1] > 250 and item[2] > 250:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    image.putdata(new_data)
    return image

def generate_image(prompt, output_path):
    """生成图片"""
    enhanced_prompt = f"{prompt}, solid white background, clean pixel edges, standalone character"

    print(f"生成中: {output_path.name}...")

    try:
        image = client.text_to_image(
            prompt=enhanced_prompt,
            model="stabilityai/stable-diffusion-xl-base-1.0"
        )

        # 先缩小到64x64像素风格
        image = image.resize((64, 64), Image.NEAREST)

        # 再放大回来保持像素感
        image = image.resize((256, 256), Image.NEAREST)

        # 移除白色背景
        print(f"  去除白底...")
        image = remove_white_background(image)

        # 最后缩小到64x64
        image = image.resize((64, 64), Image.NEAREST)

        # 保存
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
        return True

    except Exception as e:
        print(f"✗ 失败: {e}")
        return False

def main():
    avatars_dir = Path("assets/pets")

    for avatar_dir in avatars_dir.iterdir():
        if not avatar_dir.is_dir():
            continue

        config_file = avatar_dir / "config.json"
        if not config_file.exists():
            continue

        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)

        prompt = config.get('prompt', '')
        output_path = avatar_dir / "base.png"

        print(f"\n{'='*50}")
        print(f"形象: {config['name']}")
        print(f"Prompt: {prompt}")

        generate_image(prompt, output_path)

if __name__ == "__main__":
    main()
