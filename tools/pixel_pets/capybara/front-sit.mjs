// 正面坐姿（三视图里的正面）：和侧面坐姿同一个地面、同一行眼睛、同一个头顶装扮高度。
// 头用 front-head.mjs 那一颗（贴边、干活场景也是它），和面包身子连成一团；半眯眼、面无表情，嘴里叼着草（和侧面一样）。
// 现在用在转身那一下：侧面 → 正面 → 另一侧
import { Grid, partMask } from './raster.mjs';
import { HEADWEAR, frontHeadwear } from './headwear.mjs';
import { FRONT_ROWS, FRONT_SIZE, frontFace, frontHatAnchor, frontHeadDetails, frontHeadParts, rect } from './front-head.mjs';

const N = FRONT_SIZE;
// 形状按像素中心取样（x + 0.5），中心放在 16 才和 15 | 16 两列对称
const CX = 16;
/** 眼皮那一行（眼睛线在下一行），和侧面眼睛同一行 */
export const FRONT_EYE_ROW = 8;
/** 头中心那一行：眼睛对上侧面 */
const HEAD_CENTER = FRONT_EYE_ROW - FRONT_ROWS.eye;

/**
 * 头顶装扮的锚点。坐姿的眼睛要和侧面同一行，头顶上面只剩一格：
 * 草帽帽身 5 行高，再往下压一格，帽檐的描边压着眼皮（眼线还在），帽顶才不碰画布上沿
 */
const hatAnchor = (kind) => {
  const [x, y] = frontHatAnchor(kind, HEAD_CENTER);
  return kind === 'straw_hat' ? [x, y + 1] : [x, y];
};
const ellipse = (ink, cx, cy, rx, ry) => ({ shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0 });
const filled = (grid, part, onlyOver = null) => grid.fill(part.ink, partMask(part, null), onlyOver);
const drawn = (list, grid = Grid.empty(N, N)) => list.reduce((acc, part) => filled(acc, part), grid);

const BODY_PARTS = [
  ellipse('body', CX, 25.4, 11, 6.4),
  ellipse('body', CX, 20.6, 8.6, 4.4),
];

/** 头和身子一个轮廓（没有脖子那条线） */
const silhouette = () => drawn([...frontHeadParts(HEAD_CENTER), ...BODY_PARTS]).outlined();

/** 下巴：沿口鼻最底下一圈画一道阴影，把头从身子上托出来 */
function chin(grid) {
  const head = drawn(frontHeadParts(HEAD_CENTER));
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
  .dots('shade', [...rect(8, 24, 9, 25), ...rect(22, 24, 23, 25)])
  .dots('outline', [[8, 26], [9, 26], [22, 26], [23, 26]]);

function frontSitBody(eyeKind, look) {
  const body = paws(chin(filled(feet(silhouette()), ellipse('light', CX, 26.4, 5.6, 4), 'body')));
  return frontFace(frontHeadDetails(body, HEAD_CENTER), HEAD_CENTER, { eyes: eyeKind, look, grass: true });
}

/**
 * 正面坐姿一帧。eyes: relaxed（默认）/ closed / open / happy（见 front-head.mjs）；look 眼珠往左右挪一格。
 * 放小鸟的干活场景也是这个姿势
 */
export function renderFrontSit({ headwear = HEADWEAR[0], eyes: eyeKind = 'relaxed', look = 0 } = {}) {
  return frontSitBody(eyeKind, look).overlaid(frontHeadwear(headwear, N, hatAnchor(headwear)));
}
