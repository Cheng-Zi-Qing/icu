// 桌宠上的像素手型光标：和桌宠同一套调色板、同样的深棕描边。
//
//   pat       头上：平放的小手 + 粉色小爱心（摸摸）
//   grab      身上：张开的手（可以拎起来）
//   grabbing  拖着走时：握拳
//
// 16×16 像素，按 CURSOR_SCALE 倍导出（Retina 下 1 像素 = 1.5pt，光标 24pt 见方）。
import { Grid } from './raster.mjs';

export const CURSOR_SIZE = 16;
export const CURSOR_SCALE = 3;
/** 光标在屏幕上的边长（pt）：16px × 1.5pt */
export const CURSOR_POINT_SIZE = 24;

const rect = (x0, y0, x1, y1) => {
  const points = [];
  for (let y = y0; y <= y1; y += 1) for (let x = x0; x <= x1; x += 1) points.push([x, y]);
  return points;
};

const without = (points, removed) => {
  const keys = new Set(removed.map(([x, y]) => `${x},${y}`));
  return points.filter(([x, y]) => !keys.has(`${x},${y}`));
};

/** 张开的手：四根手指 + 手掌 + 左下方的大拇指；手指之间的空隙描边后成为分隔线 */
function openHandFill() {
  const fingers = [rect(3, 3, 4, 9), rect(6, 1, 7, 9), rect(9, 2, 10, 9), rect(12, 4, 13, 10)];
  const palm = without(rect(3, 9, 13, 13), [[3, 13], [13, 13]]);
  const thumb = [...rect(0, 6, 1, 9), [2, 9], [2, 10]];
  // 整体右移一格，给大拇指左边留出描边的位置
  return [...fingers.flat(), ...palm, ...thumb].map(([x, y]) => [x + 1, y]);
}

/** 握拳：指节一排小鼓包，手指弯下来的折线，大拇指横在前面 */
function fistFill() {
  const knuckles = [rect(3, 4, 4, 5), rect(6, 4, 7, 5), rect(9, 4, 10, 5), rect(12, 4, 13, 5)];
  const body = without(rect(3, 6, 13, 13), [[3, 13], [13, 13]]);
  const thumb = rect(1, 8, 2, 10);
  return [...knuckles.flat(), ...body, ...thumb];
}

const FIST_CREASES = [
  // 指节之间往下延伸一格，像弯着的手指
  [5, 6], [8, 6], [11, 6],
  // 大拇指压在手指前面的边
  [3, 11], [4, 11], [5, 11], [6, 11], [7, 11],
];

const HEART = [[0, 0], [2, 0], [0, 1], [1, 1], [2, 1], [1, 2]];

function draw(fill, extras = (grid) => grid) {
  return extras(Grid.empty(CURSOR_SIZE, CURSOR_SIZE).dots('white', fill).outlined());
}

/** 光标定义：网格 + 热点（像素坐标，左上角原点） */
export function cursorDefinitions() {
  return {
    grab: { grid: draw(openHandFill()), hotSpot: [9, 9] },
    grabbing: { grid: draw(fistFill(), (g) => g.dots('outline', FIST_CREASES)), hotSpot: [8, 9] },
    // 手平放着往前摸（张开的手逆时针转 90°，手指朝左，和桌宠脸的方向一致）
    pat: {
      grid: draw(openHandFill()).rotatedQuarter(-1).overlaid(
        Grid.empty(CURSOR_SIZE, CURSOR_SIZE).dots('blush', HEART.map(([x, y]) => [x + 12, y + 1])).outlined(),
      ),
      hotSpot: [7, 8],
    },
  };
}

/** 光标元数据（Swift 端按它设热点），热点按像素给，scale 是导出倍数 */
export function cursorManifest() {
  const definitions = cursorDefinitions();
  return {
    pixelSize: CURSOR_SIZE,
    pointSize: CURSOR_POINT_SIZE,
    cursors: Object.fromEntries(Object.entries(definitions).map(([name, { hotSpot }]) => [name, { file: `${name}.png`, hotSpot }])),
  };
}
