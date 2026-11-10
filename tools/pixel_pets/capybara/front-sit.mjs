// 正面坐姿（三视图里的正面，用户 2026-11-09 定稿）：和侧面坐姿同一个地面、同一行眼睛、同一个头顶装扮高度。
// 头和面包身子连成一团；大鼻头、竖着的两个鼻孔、托出来的下巴；半眯眼、面无表情，嘴里叼着草（往左垂，和侧面一样）。
// 现在用在转身那一下：侧面 → 正面 → 另一侧
import { Grid, partMask } from './raster.mjs';
import { HEADWEAR, frontHeadwear } from './headwear.mjs';

const N = 32;
// 形状按像素中心取样（x + 0.5），中心放在 16 才和 15 | 16 两列对称
const CX = 16;
/** 头的中心行：头顶、眼睛和侧面坐姿对齐 */
const HEAD_CENTER = 11.5;
/** 眼皮那一行（眼睛线在下一行），和侧面眼睛同一行 */
export const FRONT_EYE_ROW = 8;

const r = (local) => Math.round(HEAD_CENTER + local);
/** 头顶装扮的锚点。正面草帽的帽身有 5 行高（侧面只有 3 行），往下压到帽檐压着眼皮，帽顶才不碰画布上沿 */
const HAT_ANCHOR = { orange: [14, r(-8.5)], straw_hat: [14, r(-6.5)] };
const rect = (x0, y0, x1, y1) => {
  const out = [];
  for (let y = y0; y <= y1; y += 1) for (let x = x0; x <= x1; x += 1) out.push([x, y]);
  return out;
};
const both = (points) => [...points, ...points.map(([x, y]) => [N - 1 - x, y])];
const ellipse = (ink, cx, cy, rx, ry) => ({ shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0 });
const roundBox = (ink, cx, cy, w, h, radius) => ({ shape: 'rbox', ink, cx, cy, w, h, r: radius, rot: 0 });
const filled = (grid, part, onlyOver = null) => grid.fill(part.ink, partMask(part, null), onlyOver);
const drawn = (list, grid = Grid.empty(N, N)) => list.reduce((acc, part) => filled(acc, part), grid);

const HEAD_PARTS = [
  // 小耳朵贴在两侧（竖在头顶就像小熊）
  ellipse('shade', CX - 7.1, HEAD_CENTER - 3.8, 1.1, 1.3),
  ellipse('shade', CX + 7.1, HEAD_CENTER - 3.8, 1.1, 1.3),
  // 脑壳上窄，脸颊和口鼻下宽
  roundBox('body', CX, HEAD_CENTER - 1.4, 13.6, 10.4, 5.4),
  ellipse('body', CX, HEAD_CENTER + 2.8, 7.8, 4.4),
];
const BODY_PARTS = [
  ellipse('body', CX, 25.4, 11, 6.4),
  ellipse('body', CX, 19.8, 8.4, 4.2),
];

/** 头和身子一个轮廓（没有脖子那条线） */
const silhouette = () => drawn([...HEAD_PARTS, ...BODY_PARTS]).outlined();

/** 下巴：沿下颌最底下一圈画一道阴影，把下巴从身子上托出来 */
function chin(grid) {
  const head = drawn(HEAD_PARTS);
  const points = [];
  for (let x = 0; x < N; x += 1) {
    let lowest = -1;
    for (let y = 0; y < N; y += 1) if (head.get(x, y) !== 'clear') lowest = y;
    if (lowest >= 0 && grid.get(x, lowest + 1) === 'body') points.push([x, lowest + 1]);
  }
  return grid.dots('shade', points);
}

function feet(grid) {
  return grid
    .dots('outline', [...rect(8, 31, 12, 31), ...rect(19, 31, 23, 31)])
    .dots('shade', [...rect(9, 30, 11, 30), ...rect(20, 30, 22, 30)])
    .dots('dark', [[9, 31], [11, 31], [20, 31], [22, 31]]);
}

/** 两只前爪：肚皮两边的小圆疙瘩 */
const paws = (grid) => grid
  .dots('shade', [...rect(8, 23, 9, 24), ...rect(22, 23, 23, 24)])
  .dots('outline', [[8, 25], [9, 25], [22, 25], [23, 25]]);

const EYE_LEFTS = [11, 19];

/** relaxed = 半眯（眼皮压一行）；closed = 一道线 */
function eyes(grid, kind) {
  const t = FRONT_EYE_ROW;
  const lines = EYE_LEFTS.flatMap((x) => rect(x, t + 1, x + 1, t + 1));
  const withLines = grid.dots('outline', lines);
  if (kind === 'closed') return withLines;
  return withLines.dots('shade', EYE_LEFTS.flatMap((x) => rect(x, t, x + 1, t)));
}

function face(grid) {
  const nostril = r(1.6);
  const mouth = r(5);
  return grid
    .dots('light', rect(14, r(0.6), 17, r(0.6)))
    .dots('light', rect(14, r(-6), 17, r(-6)))
    .dots('dark', [[13, nostril], [13, nostril + 1], [18, nostril], [18, nostril + 1]])
    .dots('blush', both(rect(9, r(2), 10, r(2))))
    // 嘴：一道短平线，面无表情
    .dots('dark', [[15, mouth], [16, mouth]])
    // 嘴里叼的草，越过左脸颊往下垂
    .dots('grass', [...rect(5, mouth, 14, mouth), [4, mouth + 1], [3, mouth + 1], [3, mouth + 2]])
    .dots('leaf', [[6, mouth - 1], [4, mouth + 2], [2, mouth + 3]])
    .dots('light', rect(14, r(6.6), 17, r(6.6)));
}

function frontSitBody(eyeKind) {
  const base = paws(chin(filled(
    filled(feet(silhouette()), ellipse('light', CX, 26.2, 5.6, 4.2), 'body'),
    ellipse('muzzle', CX, HEAD_CENTER + 3, 5.2, 3.4),
    'body',
  )));
  return eyes(face(base), eyeKind);
}

/** 正面坐姿一帧。eyes: relaxed（默认）/ closed */
export function renderFrontSit({ headwear = HEADWEAR[0], eyes: eyeKind = 'relaxed' } = {}) {
  return frontSitBody(eyeKind).overlaid(frontHeadwear(headwear, N, HAT_ANCHOR[headwear]));
}
