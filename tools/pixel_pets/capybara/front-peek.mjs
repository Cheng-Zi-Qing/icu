// 贴边探头（正面）：方脑袋 + 头顶橙子，两只爪子搭在屏幕边上。
// 先按「趴在一条横边上」画（边在画布底边），再逆时针转 90°：头顶朝屏幕里，爪子贴画布右边（= 屏幕边）。
// 贴左边时由 app 整张镜像。
import { Grid, partMask } from './raster.mjs';
import { HEADWEAR, frontHeadwear } from './headwear.mjs';

const N = 32;

const rect = (x0, y0, x1, y1) => {
  const out = [];
  for (let y = y0; y <= y1; y += 1) for (let x = x0; x <= x1; x += 1) out.push([x, y]);
  return out;
};
const mirrored = (points) => points.map(([x, y]) => [N - 1 - x, y]);
const both = (points) => [...points, ...mirrored(points)];
const ellipse = (ink, cx, cy, rx, ry) => ({ shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0 });
const roundBox = (ink, cx, cy, w, h, r) => ({ shape: 'rbox', ink, cx, cy, w, h, r, rot: 0 });
const filled = (grid, part, onlyOver = null) => grid.fill(part.ink, partMask(part, null), onlyOver);

// 正面跟侧面用同一套头部尺寸（model.mjs 里 head 的局部坐标，y 向下，0 = 头的中心）：
//   耳朵 -6（正面贴在两侧）、头顶 -6.5、眼睛 -4、鼻垫 -2、嘴和腮红 +2、下巴 +6，头顶的橙子坐在 -9。
// 正面头宽 16 格（侧面头长也是 16 格）。画布第 ROW0 行 = 局部 y 0，下巴正好落在边上。
const ROW0 = 25;
const row = (localY, dy) => Math.round(localY + ROW0 + dy);

/** 头的剪影、口鼻、鼻头、耳朵；dy 是整颗头往下挪多少（0 = 下巴贴着边） */
function head(dy) {
  const silhouette = [
    // 耳朵小，贴在头两侧偏上（不竖在头顶，否则像小熊）
    ellipse('shade', 7.6, -5.6 + ROW0 + dy, 1.4, 1.4),
    ellipse('shade', 23.4, -5.6 + ROW0 + dy, 1.4, 1.4),
    roundBox('body', 15.5, -0.25 + ROW0 + dy, 16, 12.5, 4.5),
    // 下半张脸：脸颊往两边鼓一点
    ellipse('body', 15.5, 2.6 + ROW0 + dy, 7.6, 3.6),
  ].reduce((grid, part) => filled(grid, part), Grid.empty(N, N)).outlined();
  const muzzle = filled(silhouette, roundBox('muzzle', 15.5, 0.8 + ROW0 + dy, 8, 7, 2.6), 'body');
  return muzzle
    .dots('dark', rect(13, row(-2, dy), 18, row(-2, dy)))
    .dots('dark', rect(14, row(-1, dy), 17, row(-1, dy)))
    .dots('dark', both([[7, row(-6, dy)]]))
    .dots('light', both(rect(11, row(-5.5, dy), 12, row(-5.5, dy))));
}

/** 挤成 > < 的眼睛：左眼尖朝右、右眼尖朝左（镜像正好对上） */
const squeezedEye = (eyeTop) => [[10, eyeTop - 1], [11, eyeTop], [10, eyeTop + 1]];

function face(grid, dy, blink, flinch = false) {
  const eyeTop = row(-4, dy);
  const openEye = rect(10, eyeTop, 11, eyeTop + 1);
  const eye = flinch ? squeezedEye(eyeTop) : blink ? rect(10, eyeTop + 1, 11, eyeTop + 1) : openEye;
  const withEyes = grid.dots('outline', both(eye));
  const highlighted = blink || flinch ? withEyes : withEyes.dots('white', [[10, eyeTop], [20, eyeTop]]);
  const mouth = row(2, dy);
  return highlighted
    .dots('blush', both(rect(9, mouth - 1, 10, mouth - 1)))
    .dots('outline', [[15, mouth - 1], [16, mouth - 1], [14, mouth], [17, mouth]]);
}

/** 头顶装扮（默认橙子），锚点跟着头上下走 */
const headwear = (kind, dy) => frontHeadwear(kind, N, [14, row(-8.5, dy)]);

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
  return face(head(dy), dy, blink, flinch).overlaid(paws()).overlaid(headwear(kind, dy));
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
