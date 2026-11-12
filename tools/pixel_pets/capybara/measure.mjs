// 按部位量一帧：头、身体、腿、爪各占多少格、外框多大。
// 靠的是渲染时记下的部位标签（raster.mjs 的 TAGS），不看颜色：腿改深色、肚皮去掉、道具挡住都不会量错。
import { TAGS } from './raster.mjs';

/** 水豚本体的部位（道具、描边不算） */
export const FIGURE_TAGS = Object.freeze(['head', 'body', 'leg', 'paw']);

const emptyBox = () => ({ area: 0, left: Infinity, top: Infinity, right: -1, bottom: -1 });

function grown(box, x, y) {
  return {
    area: box.area + 1,
    left: Math.min(box.left, x),
    top: Math.min(box.top, y),
    right: Math.max(box.right, x),
    bottom: Math.max(box.bottom, y),
  };
}

/** 收尾：空的部位给 null，否则补上宽高 */
function finished(box) {
  if (box.area === 0) return null;
  return Object.freeze({ ...box, w: box.right - box.left + 1, h: box.bottom - box.top + 1 });
}

/**
 * 量一帧。返回 { head, body, leg, paw, figure }，每项是 { area, left, top, right, bottom, w, h } 或 null。
 * figure 是头 + 身体 + 腿 + 爪合在一起（整只水豚）
 */
export function measure(grid) {
  const boxes = Object.fromEntries([...TAGS, 'figure'].map((tag) => [tag, emptyBox()]));
  for (let y = 0; y < grid.height; y += 1) {
    for (let x = 0; x < grid.width; x += 1) {
      const tag = grid.tagAt(x, y);
      if (!tag) continue;
      boxes[tag] = grown(boxes[tag], x, y);
      if (FIGURE_TAGS.includes(tag)) boxes.figure = grown(boxes.figure, x, y);
    }
  }
  return Object.freeze(Object.fromEntries([...FIGURE_TAGS, 'figure'].map((tag) => [tag, finished(boxes[tag])])));
}
