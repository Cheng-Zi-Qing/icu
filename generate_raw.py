"""生成原图并保存"""
import os
import json
from pathlib import Path
from huggingface_hub import InferenceClient

HF_TOKEN = os.getenv("HF_TOKEN", "")
client = InferenceClient(provider="hf-inference", api_key=HF_TOKEN)

def generate_raw_image(prompt, output_path):
    """生成原图"""
    enhanced_prompt = f"{prompt}, solid white background, clean pixel edges, standalone character"
    print(f"生成: {output_path.name}...")

    try:
        image = client.text_to_image(
            prompt=enhanced_prompt,
            model="stabilityai/stable-diffusion-xl-base-1.0"
        )
        image.save(output_path)
        print(f"✓ 已保存原图: {output_path}")
        return True
    except Exception as e:
        print(f"✗ 失败: {e}")
        return False

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
    output_path = avatar_dir / "raw.png"

    print(f"\n{'='*50}")
    print(f"形象: {config['name']}")
    generate_raw_image(prompt, output_path)
