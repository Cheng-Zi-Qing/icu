"""Auto-Builder 主入口"""
import sys
import os
import argparse
from pathlib import Path
from persona_forge import PersonaForge
from vision_generator import VisionGenerator
from vision_slicer import VisionSlicer
from asset_packer import AssetPacker


def main():
    parser = argparse.ArgumentParser(description='I.C.U. Auto-Builder')
    parser.add_argument('prompt', nargs='?', help='一句话描述')
    parser.add_argument('--force', '-f', action='store_true', help='强制重新生成')
    parser.add_argument('--rescue', help='救援模式：pet_id')
    args = parser.parse_args()

    if args.rescue:
        print(f"🚑 救援模式：{args.rescue}")
        # TODO: 实现救援逻辑
        return

    if not args.prompt:
        print("❌ 请提供描述")
        print("用法：python builder.py '一只淡定的卡皮巴拉'")
        sys.exit(1)

    # 第一层：灵魂锻造
    forge = PersonaForge()
    persona_data = forge.forge(args.prompt, args.force)
    if not persona_data:
        sys.exit(1)

    # 第二层：躯体铸造
    hf_token = os.getenv('HF_TOKEN')
    generator = VisionGenerator(hf_token=hf_token)
    image_path = generator.generate(
        persona_data['image_generation_prompt'],
        args.force
    )
    if not image_path:
        sys.exit(1)

    # 第三层：视觉屠宰场
    slicer = VisionSlicer()
    result = slicer.process(image_path, persona_data['expected_actions'])
    
    if not result['success']:
        print(f"❌ 切割失败：{result['message']}")
        print(f"   发现 {result['found']} 个动作，期望 {result['expected']} 个")
        
        # 保存到救援目录
        rescue_dir = Path(f"_needs_rescue/{persona_data['pet_id']}")
        rescue_dir.mkdir(parents=True, exist_ok=True)
        
        import shutil
        shutil.copy(image_path, rescue_dir / "raw_sheet.png")
        
        print(f"\n⚠️ 流水线已挂起：动作识别失败")
        print(f"救援方法：")
        print(f"1. 用图像编辑器打开 {rescue_dir}/raw_sheet.png")
        print(f"2. 手动裁剪出动作帧")
        print(f"3. 运行：python builder.py --rescue {persona_data['pet_id']}")
        sys.exit(1)

    # 第四层：资产总装
    packer = AssetPacker()
    packer.pack(
        persona_data['pet_id'],
        persona_data['display_name'],
        result['frames'],
        result['actions'],
        persona_data['ai_persona_system_prompt']
    )

    print("\n🎉 全部完成！")


if __name__ == '__main__':
    main()
