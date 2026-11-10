// 贴边探头（正面）：方脑袋 + 头顶橙子，两只爪子搭在屏幕边上。
// 先按「趴在一条横边上」画（边在画布底边），再逆时针转 90°：头顶朝屏幕里，爪子贴画布右边（= 屏幕边）。
// 贴左边时由 app 整张镜像。
import { Grid } from './raster.mjs';
import { HEADWEAR } from './headwear.mjs';
import { FRONT_SIZE, both, frontFace, frontHead, frontHeadwearLayer, rect } from './front-head.mjs';

const N = FRONT_SIZE;

// 正面那颗头在 front-head.mjs（和转身、干活场景同一颗）。画布第 ROW0 行是头中心：
// 下巴缩在屏幕边后面一格，只露出半截口鼻，探出来的长度和侧身探头差不多
const ROW0 = 25;

/** 头连同表情；dy 是整颗头往下挪多少（0 = 下巴贴着边） */
function head(dy, { blink, reach, flinch }) {
  const c = ROW0 + dy;
  // 平时和侧面一样半眯；往外探的那一下睁眼看你；被碰到挤成 > <
  const eyes = flinch ? 'squeeze' : blink ? 'closed' : reach ? 'open' : 'relaxed';
  return frontFace(frontHead(c), c, { eyes });
}

/** 两只爪子搭在边上（画布底边），在下巴两侧：单独描边，跟脸分开 */
function paws() {
  const paw = [...rect(6, N - 3, 10, N - 2), ...rect(7, N - 4, 9, N - 4), ...rect(7, N - 1, 9, N - 1)];
  return Grid.empty(N, N).dots('body', both(paw)).outlined()
    .dots('light', both(rect(7, N - 3, 8, N - 3)))
    .dots('dark', both([[8, N - 1]]));
}

/** 竖着的一帧（边在画布底边），用来跟侧面对照 */
export function renderFrontUpright({ blink = false, reach = false, flinch = false, headwear: kind = HEADWEAR[0] } = {}) {
  const dy = flinch ? 1 : reach ? -1 : 0;
  return head(dy, { blink, reach, flinch }).overlaid(paws()).overlaid(frontHeadwearLayer(kind, ROW0 + dy));
}

/** 逆时针转 90°：画布底边转到右边 */
const turnedTowardRightEdge = (grid) =>
  new Grid(N, N, Array.from({ length: N * N }, (_, i) => grid.get(N - 1 - Math.floor(i / N), i % N)));

/**
 * 正面贴边探头的一帧。
 * blink：闭眼；reach：头往屏幕里多探 1 格（爪子不动）；
 * flinch：被碰到吓一跳，眼睛挤成 > <，头往边后缩 1 格
 */
export function renderFrontPeek(options = {}) {
  return turnedTowardRightEdge(renderFrontUpright(options));
}

