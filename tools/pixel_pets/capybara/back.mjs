// 背面：从后面看坐着的水豚（2026-11-11 用户定三视图 = 侧面、正面、背面）。
// 头用正面那颗的剪影（同一颗头，从后面看是后脑勺：没有五官，只有两只耳朵和头顶的装扮），
// 身子上窄下圆像个梨，两侧一道阴影显得圆；屁股下面露两只后脚。头顶、地面和侧面坐姿对齐。
import { Grid, partMask } from './raster.mjs';
import { HEADWEAR } from './headwear.mjs';
import { FRONT_SIZE as N, frontHeadParts, frontHeadwearLayer, rect } from './front-head.mjs';

/** frontHeadParts(c) 的头顶在第 c - 8 行；背面的头顶和侧面坐姿的头顶（第 4 行）对齐 */
export const BACK_HEAD_ROW = 12;

const ellipse = (ink, cx, cy, rx, ry) => ({ shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0 });
const roundBox = (ink, cx, cy, w, h, r) => ({ shape: 'rbox', ink, cx, cy, w, h, r, rot: 0 });
const filled = (grid, part, tag, onlyOver = null) => grid.fill(part.ink, partMask(part, null), onlyOver, tag);

/** 背面坐姿（没戴装扮）：后脚先画，被屁股压住上半；再画梨形的身子；最后画头盖住脖子 */
function backBody(c) {
  const feet = [roundBox('shade', 10, 29.6, 4, 2.4, 1), roundBox('shade', 22, 29.6, 4, 2.4, 1)]
    .reduce((g, part) => filled(g, part, 'paw'), Grid.empty(N, N));
  const body = [ellipse('body', 16, 22.6, 11.6, 7.4), ellipse('body', 16, 18.5, 9.4, 6)]
    .reduce((g, part) => filled(g, part, 'body'), feet);
  const withHead = frontHeadParts(c).reduce((g, part) => filled(g, part, 'head'), body);
  // 身子两侧的阴影只盖在身子上
  return [ellipse('shade', 5.6, 24, 2.2, 5), ellipse('shade', 26.4, 24, 2.2, 5)]
    .reduce((g, part) => filled(g, part, null, 'body'), withHead)
    .outlined();
}

/** 屁股中缝、脚掌、头顶和背上的高光、耳朵里 */
function backDetails(grid, c) {
  return grid
    .dots('shade', [[16, 27], [16, 28]])
    .dots('dark', [...rect(9, 30, 11, 30), ...rect(21, 30, 23, 30)])
    .dots('light', [...rect(13, c - 6, 18, c - 6), [12, c + 10], [13, c + 10], [14, c + 9]])
    .dots('dark', [[9, c - 7], [22, c - 7]]);
}

/** 背面一帧；headwear 为 null 时不戴装扮（体型检查量头用） */
export function renderBack({ headwear = HEADWEAR[0] } = {}) {
  const c = BACK_HEAD_ROW;
  const bare = backDetails(backBody(c), c);
  return headwear ? bare.overlaid(frontHeadwearLayer(headwear, c)) : bare;
}
