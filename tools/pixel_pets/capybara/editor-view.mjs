// 编辑器的画布绘制（浏览器专用）
import { PALETTE } from './model.mjs';

/** 画像素网格；fadeFrom 之后的列半透明（表示伸出屏幕外的部分） */
export function drawGrid(ctx, grid, { zoom, ox = 0, oy = 0, mirror = false, fadeFrom = Infinity } = {}) {
  for (let y = 0; y < grid.height; y += 1) {
    for (let x = 0; x < grid.width; x += 1) {
      const ink = grid.get(mirror ? grid.width - 1 - x : x, y);
      if (ink === 'clear') continue;
      ctx.globalAlpha = x >= fadeFrom ? 0.22 : 1;
      ctx.fillStyle = PALETTE[ink] ?? '#FF00FF';
      ctx.fillRect(ox + x * zoom, oy + y * zoom, zoom, zoom);
    }
  }
  ctx.globalAlpha = 1;
}

export function drawPixelLines(ctx, width, height, zoom) {
  ctx.strokeStyle = 'rgba(128,128,128,0.18)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let x = 0; x <= width; x += 1) {
    ctx.moveTo(x * zoom + 0.5, 0);
    ctx.lineTo(x * zoom + 0.5, height * zoom);
  }
  for (let y = 0; y <= height; y += 1) {
    ctx.moveTo(0, y * zoom + 0.5);
    ctx.lineTo(width * zoom, y * zoom + 0.5);
  }
  ctx.stroke();
}

/** 选中部件的覆盖范围：半透明青色 + 虚线框 */
export function drawMask(ctx, mask, width, height, zoom) {
  ctx.fillStyle = 'rgba(0, 200, 255, 0.28)';
  let minX = Infinity; let minY = Infinity; let maxX = -Infinity; let maxY = -Infinity;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (!mask(x, y)) continue;
      ctx.fillRect(x * zoom, y * zoom, zoom, zoom);
      minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
    }
  }
  if (minX === Infinity) return;
  ctx.setLineDash([4, 3]);
  ctx.strokeStyle = '#00A8E0';
  ctx.strokeRect(minX * zoom + 0.5, minY * zoom + 0.5, (maxX - minX + 1) * zoom, (maxY - minY + 1) * zoom);
  ctx.setLineDash([]);
}

export function drawPoint(ctx, [x, y], zoom, color = '#00A8E0') {
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(x * zoom, y * zoom, zoom * 0.7, 0, Math.PI * 2);
  ctx.stroke();
  ctx.lineWidth = 1;
}

export function drawVerticalLine(ctx, x, height, color, label) {
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(x, 0);
  ctx.lineTo(x, height);
  ctx.stroke();
  ctx.lineWidth = 1;
  if (!label) return;
  ctx.fillStyle = color;
  ctx.font = '12px -apple-system, sans-serif';
  ctx.fillText(label, x + 4, 14);
}

/** 参考照片：按偏移 / 缩放 / 翻转画在像素层后面或前面 */
export function drawReference(ctx, image, ref, zoom) {
  if (!image || !ref.visible) return;
  const width = image.naturalWidth * ref.scale * zoom / 16;
  const height = image.naturalHeight * ref.scale * zoom / 16;
  ctx.save();
  ctx.globalAlpha = ref.opacity;
  ctx.translate(ref.x * zoom, ref.y * zoom);
  if (ref.flip) {
    ctx.translate(width, 0);
    ctx.scale(-1, 1);
  }
  ctx.imageSmoothingEnabled = true;
  ctx.drawImage(image, 0, 0, width, height);
  ctx.restore();
}

/** 给 canvas 设置逻辑尺寸并适配 Retina */
export function sizeCanvas(canvas, width, height) {
  const ratio = window.devicePixelRatio || 1;
  canvas.width = Math.round(width * ratio);
  canvas.height = Math.round(height * ratio);
  canvas.style.width = `${width}px`;
  canvas.style.height = `${height}px`;
  const ctx = canvas.getContext('2d');
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
  ctx.imageSmoothingEnabled = false;
  return ctx;
}
