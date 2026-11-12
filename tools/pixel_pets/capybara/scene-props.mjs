// 场景道具的小工具：按格子画道具层、细线，把一帧放进更宽的画布。
// 道具层自己描边后叠到水豚上；部位标签（raster.mjs 的 TAGS）默认是道具，盖住的格子不再算水豚。
import { Grid } from './raster.mjs';
import { CANVAS_HEIGHT } from './render.mjs';

/** 左上角 (x, y)、w × h 的一块格子 */
export const block = (x, y, w, h) => Array.from({ length: w * h }, (_, i) => [x + (i % w), y + Math.floor(i / w)]);

/** 两点之间一条一格宽的线 */
export function line([x0, y0], [x1, y1]) {
  const steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
  if (steps === 0) return [[x0, y0]];
  return Array.from({ length: steps + 1 }, (_, i) => [
    Math.round(x0 + ((x1 - x0) * i) / steps),
    Math.round(y0 + ((y1 - y0) * i) / steps),
  ]);
}

/**
 * 一层道具：先铺剪影（silhouette = [颜色, 格子]）再整体描边，details 里的 [颜色, 格子] 按顺序盖上去。
 * tag 给剪影标部位（道具默认 prop；画水豚的腿脚时传 leg / paw）
 */
export function prop(width, [ink, points], details = [], tag = null) {
  const outlined = Grid.empty(width, CANVAS_HEIGHT).dots(ink, points, tag).outlined();
  return details.reduce((grid, [detailInk, detailPoints]) => grid.dots(detailInk, detailPoints), outlined);
}

/** 不描边的细节：速度线、热气、碎屑 */
export function plain(width, items) {
  return items.reduce((grid, [ink, points]) => grid.dots(ink, points), Grid.empty(width, CANVAS_HEIGHT));
}

/** 放进 width 宽的画布，往右挪 dx 格 */
export const placed = (grid, width, dx = 0) => grid.windowed(-dx, 0, width, CANVAS_HEIGHT);

/** 依次叠上几层 */
export const stacked = (base, ...layers) => layers.reduce((grid, layer) => grid.overlaid(layer), base);
