// 正面的水豚头：贴边探头、标题栏、转身、干活场景都用这一颗，保证正面和侧面是同一只。
//
// 跟侧面对齐的特征（2026-11-10 统一）：
// - 方方的大脑袋，耳朵是头顶两角的小圆疙瘩（竖在头顶就成了小熊）；
// - 口鼻是一整块往下伸的宽方块，比脑袋窄一圈，鼻垫是口鼻顶上一道深色横条（侧面那颗大黑鼻头从正面看）；
// - 眼睛长在脑袋两侧，平时半眯（上面一行眼皮、下面一行眼线），和侧面一样慢悠悠的；
// - 腮红在脸颊上，头顶一道高光，配色全用侧面那套。
// 坐标：画布 32×32，c 是头中心那一行；头横向以 15 | 16 两列为中线对称。
import { Grid, partMask } from './raster.mjs';
import { HEADWEAR, frontHeadwear } from './headwear.mjs';

export const FRONT_SIZE = 32;
const N = FRONT_SIZE;
const CX = 16;

export const rect = (x0, y0, x1, y1) => {
  const out = [];
  for (let y = y0; y <= y1; y += 1) for (let x = x0; x <= x1; x += 1) out.push([x, y]);
  return out;
};
const mirror = (points) => points.map(([x, y]) => [N - 1 - x, y]);
export const both = (points) => [...points, ...mirror(points)];
const ellipse = (ink, cx, cy, rx, ry) => ({ shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0 });
const roundBox = (ink, cx, cy, w, h, r) => ({ shape: 'rbox', ink, cx, cy, w, h, r, rot: 0 });
const filled = (grid, part, onlyOver = null) => grid.fill(part.ink, partMask(part, null), onlyOver);

/** 相对头中心的各行（局部 y） */
export const FRONT_ROWS = Object.freeze({ top: -8, eye: -3, nose: 2, cheek: 1, mouth: 5, chin: 7, hat: -8 });
/** 左眼最左那一列（右眼镜像） */
export const EYE_LEFT = 10;

/** 头的剪影（没描边）：脑壳 + 脸颊 + 往下伸的口鼻 + 两个小耳朵 */
export function frontHeadParts(c) {
  return [
    ellipse('shade', CX - 6.9, c - 6.4, 1.7, 1.6),
    ellipse('shade', CX + 6.9, c - 6.4, 1.7, 1.6),
    roundBox('body', CX, c - 2, 15, 11, 4),
    roundBox('body', CX, c + 3.6, 10.2, 6.6, 2.6),
  ];
}

/** 已经描好边的剪影上，画口鼻的深色块、鼻垫、耳朵里和头顶高光 */
export function frontHeadDetails(grid, c) {
  const nose = c + FRONT_ROWS.nose;
  return filled(grid, roundBox('muzzle', CX, c + 3.6, 8.2, 5.4, 2.2), 'body')
    .dots('dark', [...rect(13, nose, 18, nose), ...rect(14, nose + 1, 17, nose + 1)])
    .dots('outline', [[14, nose], [17, nose]])
    .dots('dark', both([[9, c - 7]]))
    .dots('light', rect(13, c - 6, 18, c - 6));
}

/** 单独一颗头（自己描边），叠到别的东西上面用 */
export function frontHead(c) {
  const silhouette = frontHeadParts(c).reduce((g, part) => filled(g, part), Grid.empty(N, N)).outlined();
  return frontHeadDetails(silhouette, c);
}

/**
 * 脸：眼睛、腮红、嘴、可选叼着的草。
 * eyes: relaxed 半眯（默认，和侧面一样）/ open 睁大（看你、发现东西）/ down 低头看手上 /
 *       closed 闭眼 / happy 眯眼笑 ^ ^ / squeeze 挤成 > <
 * look: 眼珠往左（-1）/ 右（+1）挪一格；mouth: calm 一道线 / open 张嘴 / chew 嚼
 */
export function frontFace(grid, c, { eyes = 'relaxed', look = 0, mouth = 'calm', grass = false, glasses = false } = {}) {
  const t = c + FRONT_ROWS.eye;
  const lefts = [EYE_LEFT + look, N - 2 - EYE_LEFT + look];
  let g = grid;
  for (const x of lefts) {
    const right = x === lefts[1];
    switch (eyes) {
      case 'closed':
        g = g.dots('outline', rect(x, t + 1, x + 1, t + 1));
        break;
      case 'happy':
        g = g.dots('outline', [[x - 1, t + 1], [x, t], [x + 1, t], [x + 2, t + 1]]);
        break;
      case 'squeeze':
        g = g.dots('outline', right ? [[x + 1, t - 1], [x, t], [x + 1, t + 1]] : [[x, t - 1], [x + 1, t], [x, t + 1]]);
        break;
      case 'open':
        g = g.dots('outline', rect(x, t, x + 1, t + 1)).dots('white', [[x, t]]);
        break;
      case 'down':
        // 低头看手上：眼线压到下面一行，眼皮盖两行
        g = g.dots('shade', rect(x, t, x + 1, t + 1)).dots('outline', rect(x, t + 2, x + 1, t + 2));
        break;
      default:
        // 半眯：眼皮压下来一行，眼线在下面
        g = g.dots('shade', rect(x, t, x + 1, t)).dots('outline', rect(x, t + 1, x + 1, t + 1));
    }
  }
  if (glasses) {
    // 圆框：去掉四个角，用比描边浅的深棕，眼睛还看得见
    const rims = lefts.flatMap((x) => rect(x - 1, t - 1, x + 2, t + 2)
      .filter(([px, py]) => px === x - 1 || px === x + 2 || py === t - 1 || py === t + 2)
      .filter(([px, py]) => !((px === x - 1 || px === x + 2) && (py === t - 1 || py === t + 2))));
    g = g.dots('dark', [...rims, ...rect(lefts[0] + 3, t, lefts[1] - 2, t)]);
  }
  const cheek = c + FRONT_ROWS.cheek;
  const m = c + FRONT_ROWS.mouth;
  g = g.dots('blush', both(rect(9, cheek, 10, cheek)));
  g = mouth === 'open'
    ? g.dots('outline', rect(15, m, 16, m + 1)).dots('blush', [[15, m + 1], [16, m + 1]])
    : mouth === 'chew'
      ? g.dots('dark', [[14, m], [15, m + 1], [16, m + 1], [17, m]])
      : g.dots('dark', rect(15, m, 16, m));
  // 叼着的草：从嘴角越过左脸颊往下垂（和侧面一样往脸前那边垂）
  if (grass) {
    g = g.dots('grass', [...rect(10, m, 14, m), [9, m + 1], [8, m + 2]])
      .dots('leaf', [[11, m - 1], [8, m + 3]]);
  }
  return g;
}

/** 头顶装扮的锚点：橙子坐在头顶；正面草帽帽身高，往下压到帽檐的描边正好在眼皮上面一行 */
export function frontHatAnchor(kind, c) {
  return kind === 'straw_hat' ? [14, c - 7] : [14, c + FRONT_ROWS.hat];
}

export function frontHeadwearLayer(kind = HEADWEAR[0], c) {
  return frontHeadwear(kind, N, frontHatAnchor(kind, c));
}
