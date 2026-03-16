"""第四层：资产总装 (Asset Packer)"""
import json
from pathlib import Path


class AssetPacker:
    def pack(self, pet_id, display_name, frames, actions, persona):
        """打包资产"""
        print("📦 正在打包资产...")
        
        asset_dir = Path(f"assets/pets/{pet_id}")
        asset_dir.mkdir(parents=True, exist_ok=True)
        
        # 保存帧图片
        for frame, action in zip(frames, actions):
            action_dir = asset_dir / action
            action_dir.mkdir(exist_ok=True)
            frame.save(action_dir / "0.png")
        
        # 生成 config.json
        config = {
            "id": pet_id,
            "name": display_name,
            "style": "AI生成",
            "persona": {
                "traits": persona,
                "tone": "",
                "messages": {
                    "eye_care": [],
                    "stretch": [],
                    "hydration": []
                }
            }
        }
        
        with open(asset_dir / "config.json", 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        
        print(f"✨ 造物完成！资产已保存至: {asset_dir}")
        return str(asset_dir)
