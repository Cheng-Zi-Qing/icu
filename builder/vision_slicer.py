"""第三层：视觉屠宰场 (CV Auto Slicer)"""
import cv2
import numpy as np
from PIL import Image
from rembg import remove
from pathlib import Path


class VisionSlicer:
    def __init__(self, target_size=256, min_contour_area=2000):
        self.target_size = target_size
        self.min_area = min_contour_area
        self.padding_bottom = 20

    def process(self, input_path, expected_actions):
        """处理 Sprite Sheet"""
        print("🔪 开始切割...")
        
        # 工序 A：去底
        print("1. 🧹 去除背景...")
        raw_img = Image.open(input_path)
        transparent_img = remove(raw_img)
        
        # 工序 B：连通域侦测
        print("2. 🔍 连通域侦测...")
        img_array = np.array(transparent_img)
        alpha_channel = img_array[:, :, 3]
        _, thresh = cv2.threshold(alpha_channel, 20, 255, cv2.THRESH_BINARY)
        
        contours, _ = cv2.findContours(
            thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )
        
        # 过滤噪点
        bounding_boxes = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area > self.min_area:
                x, y, w, h = cv2.boundingRect(cnt)
                bounding_boxes.append((x, y, w, h))
        
        # 验证数量
        if len(bounding_boxes) != len(expected_actions):
            return {
                'success': False,
                'found': len(bounding_boxes),
                'expected': len(expected_actions),
                'message': '动作数量不匹配'
            }
        
        # 排序（从左到右）
        bounding_boxes.sort(key=lambda b: b[0])
        
        # 工序 C：归一化切割
        print("3. 📐 归一化...")
        frames = []
        for x, y, w, h in bounding_boxes:
            cropped = transparent_img.crop((x, y, x + w, y + h))
            
            # 创建标准画布
            canvas = Image.new("RGBA", (self.target_size, self.target_size), (0, 0, 0, 0))
            
            # 等比例缩放
            max_w = self.target_size - 40
            max_h = self.target_size - self.padding_bottom - 20
            if cropped.width > max_w or cropped.height > max_h:
                cropped.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
            
            new_w, new_h = cropped.size
            
            # 水平居中 + 底部对齐
            offset_x = (self.target_size - new_w) // 2
            offset_y = self.target_size - new_h - self.padding_bottom
            
            canvas.paste(cropped, (offset_x, offset_y), cropped)
            frames.append(canvas)
        
        print(f"✅ 切割完成：{len(frames)} 个动作帧")
        return {
            'success': True,
            'frames': frames,
            'actions': expected_actions
        }
