// 头顶装扮：默认戴橙子，衣柜里可以换成草帽。
//
// 每件装扮有三种画法：侧面（坐姿、被拎起、侧身探头，跟着头的锚点走）、正面（贴边探头和标题栏那只）、
// 衣柜格子里的 16×16 小图。都是单独一层、自己描边，再叠到头上。
import { Grid } from './raster.mjs';

/** 衣柜里能换的头顶装扮；第一个是默认 */
export const HEADWEAR = ['orange', 'straw_hat'];
/** 需要单独生成一整套帧的装扮（默认那件直接画在根目录的帧里） */
export const OUTFIT_HEADWEAR = HEADWEAR.slice(1);

const span = (x0, x1, y) => Array.from({ length: x1 - x0 + 1 }, (_, i) => [x0 + i, y]);
const shifted = ([ax, ay], points) => points.map(([x, y]) => [ax + x, ay + y]);

// ---------- 侧面（相对头顶锚点，脸朝左） ----------

const SIDE = {
  orange: {
    fill: { orange: [...span(0, 3, -1), ...span(-1, 4, 0), ...span(0, 3, 1)], white: [[0, 0]] },
    after: { grass: [[3, -2], [4, -3], [5, -3]] },
  },
  // 大草帽：扣在头上盖住头顶。帽檐在眼睛上面两行（头的局部 y -6），比 16 格的脑袋还宽，两头各往上翘一格。
  // 脸那边已经贴着画布左边、头顶上面也只剩一行（吸气时头还会抬高），所以往后脑勺那边加宽
  straw_hat: {
    fill: {
      straw: [...span(-3, 6, -1), ...span(-4, 7, 0), ...span(-4, 7, 1), ...span(-7, 12, 3), ...span(-9, -8, 2), ...span(13, 14, 2)],
      band: span(-4, 7, 2),
      strawShade: [[-2, 0], [1, 0], [4, 0], [7, 0], [-1, 1], [2, 1], [5, 1], [-5, 3], [-1, 3], [3, 3], [7, 3], [11, 3]],
    },
    after: {},
  },
};

// ---------- 正面（贴边探头 / 标题栏；ax、ay 是橙子的锚点） ----------

const FRONT = {
  orange: {
    fill: {
      orange: [...span(-1, 3, -2), ...span(-2, 4, -1), ...span(-2, 4, 0), ...span(-1, 3, 1)],
      white: [[-1, -1]],
    },
    after: { grass: [[2, -3], [3, -4], [4, -4]] },
  },
  // 大草帽：帽檐在第 19 行（眼睛正上方），左右各伸出脑袋 5 格，两头往上翘一格；帽身跟脑袋一样宽、5 行高
  straw_hat: {
    fill: {
      straw: [
        ...span(-5, 8, -4), ...span(-6, 9, -3), ...span(-6, 9, -2), ...span(-6, 9, -1), ...span(-6, 9, 0),
        ...span(-10, 13, 2), ...span(-12, -11, 1), ...span(14, 15, 1),
      ],
      band: span(-6, 9, 1),
      strawShade: [
        [-3, -3], [1, -3], [5, -3], [-5, -2], [-1, -2], [3, -2], [7, -2], [-3, -1], [1, -1], [5, -1], [-5, 0], [-1, 0], [3, 0], [7, 0],
        [-8, 2], [-4, 2], [0, 2], [4, 2], [8, 2], [12, 2],
      ],
    },
    after: {},
  },
};

// ---------- 衣柜格子里的小图 ----------

const ICONS = {
  orange: {
    fill: {
      orange: [...span(6, 9, 5), ...span(4, 11, 6), ...span(3, 12, 7), ...span(3, 12, 8), ...span(3, 12, 9), ...span(4, 11, 10), ...span(6, 9, 11)],
      white: [[5, 7], [6, 7]],
    },
    after: { grass: [[8, 4], [9, 3], [10, 3], [11, 2]] },
  },
  straw_hat: {
    fill: {
      straw: [...span(5, 10, 3), ...span(4, 11, 4), ...span(4, 11, 5), ...span(4, 11, 6), ...span(2, 13, 8), ...span(0, 1, 7), ...span(14, 15, 7)],
      band: span(4, 11, 7),
      strawShade: [[6, 4], [9, 4], [5, 5], [8, 5], [11, 5], [7, 6], [10, 6], ...span(3, 12, 9), [4, 8], [8, 8], [12, 8]],
    },
    after: {},
  },
};

function layer(shape, width, height, at) {
  const filled = Object.entries(shape.fill)
    .reduce((grid, [ink, points]) => grid.dots(ink, shifted(at, points)), Grid.empty(width, height));
  return Object.entries(shape.after)
    .reduce((grid, [ink, points]) => grid.dots(ink, shifted(at, points)), filled.outlined());
}

function known(kind) {
  if (!HEADWEAR.includes(kind)) throw new Error(`unknown headwear: ${kind}`);
  return kind;
}

/** 侧面头顶那一层；anchor 是头顶锚点在画布上的像素 */
export function sideHeadwear(kind, width, height, anchor) {
  return layer(SIDE[known(kind)], width, height, anchor);
}

/** 正面头顶那一层 */
export function frontHeadwear(kind, size, anchor) {
  return layer(FRONT[known(kind)], size, size, anchor);
}

/** 衣柜格子里的 16×16 小图 */
export function itemIcon(kind) {
  return layer(ICONS[known(kind)], 16, 16, [0, 0]);
}
