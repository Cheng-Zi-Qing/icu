"""处理原图：像素化 + 去背景"""
from pathlib import Path
from PIL import Image
import cv2
import numpy as np

def remove_background(image):
    """使用 FloodFill 移除背景"""
    # PIL -> OpenCV
    img_array = np.array(image.convert('RGB'))
    img_bgr = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)

    h, w = img_bgr.shape[:2]
    mask = np.zeros((h + 2, w + 2), np.uint8)

    # 从四角开始填充
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    tolerance = 15  # 降低容差，保护实体
    lo_diff = up_diff = (tolerance, tolerance, tolerance)

    for corner in corners:
        cv2.floodFill(
            img_bgr, mask, seedPoint=corner, newVal=0,
            loDiff=lo_diff, upDiff=up_diff,
            flags=(255 << 8) | cv2.FLOODFILL_MASK_ONLY
        )

    # 反转 mask：背景透明，前景不透明
    alpha = cv2.bitwise_not(mask[1:-1, 1:-1])

    # 合并 RGBA
    b, g, r = cv2.split(img_bgr)
    bgra = cv2.merge([b, g, r, alpha])

    # OpenCV -> PIL
    rgba = cv2.cvtColor(bgra, cv2.COLOR_BGRA2RGBA)
    return Image.fromarray(rgba)

avatars_dir = Path("assets/pets")
for avatar_dir in avatars_dir.iterdir():
    if not avatar_dir.is_dir():
        continue

    raw_path = avatar_dir / "raw.png"
    if not raw_path.exists():
        continue

    print(f"处理: {avatar_dir.name}")

    # 读取原图
    image = Image.open(raw_path)

    # 像素化
    image = image.resize((64, 64), Image.NEAREST)
    image = image.resize((256, 256), Image.NEAREST)

    # 去背景
    image = remove_background(image)

    # 缩小到最终尺寸
    image = image.resize((64, 64), Image.NEAREST)

    # 保存
    output_path = avatar_dir / "base.png"
    image.save(output_path)
    print(f"✓ 已保存: {output_path}")
