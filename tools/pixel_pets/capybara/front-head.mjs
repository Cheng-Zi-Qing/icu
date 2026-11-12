// 正面的水豚头：贴边探头、标题栏、干活场景都用这一颗，保证正面和侧面是同一只。
// 正脸只从道具后面或屏幕边探出来，不单独正面坐着（2026-11-11 用户：正面干坐着光秃秃的不可爱）。
//
// 跟侧面对齐的特征（2026-11-10 统一，2026-11-11 用户觉得「还是不太像豚鼠」后改成面包脸）：
// - 方方的大脑袋，耳朵是头顶两角的小圆疙瘩（竖在头顶就成了小熊）；
// - 腮帮下颌比脑壳还宽一点，整张脸像一块面包；口鼻是钝钝的一大块直着下来，不往外凸（凸出来、下巴收尖就是熊和狗）；
// - 鼻头是一块圆圆的深色鼻垫，下沿两边是鼻孔；底下三瓣嘴「人」字；
// - 小眼睛长在脑袋两侧偏上，平时半眯（上面一行眼皮、下面一行眼线），和侧面一样慢悠悠的；
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
// 正面头的每一块都标成头（体型检查按部位量）
const filled = (grid, part, onlyOver = null) => grid.fill(part.ink, partMask(part, null), onlyOver, 'head');

/** 相对头中心的各行（局部 y） */
export const FRONT_ROWS = Object.freeze({ top: -8, eye: -3, nose: 2, cheek: 1, mouth: 5, chin: 7, hat: -8 });
/** 左眼最左那一列（右眼镜像） */
export const EYE_LEFT = 9;

/**
 * 头的剪影（没描边）：上面的脑壳 + 下面更宽的腮帮和口鼻 + 两个小耳朵。
 * 水豚正面是一块「面包」：腮帮下颌最宽、口鼻钝钝的一大块直着下来；上宽下窄、口鼻凸出一块就成了熊和狗
 */
export function frontHeadParts(c) {
  return [
    ellipse('shade', CX - 7.2, c - 6.6, 1.6, 1.5),
    ellipse('shade', CX + 7.2, c - 6.6, 1.6, 1.5),
    roundBox('body', CX, c - 2.5, 16, 10, 4),
    roundBox('body', CX, c + 3.5, 18, 9, 3.4),
  ];
}

/** 已经描好边的剪影上，画口鼻的深色块、宽鼻头和两个鼻孔、耳朵里和头顶高光 */
export function frontHeadDetails(grid, c) {
  const nose = c + FRONT_ROWS.nose;
  // 鼻头：一块圆圆的深色鼻垫，下沿两边是鼻孔
  // 口鼻深色那块到下巴上面一行为止：贴边探头时下巴缩在屏幕边后面，深色块还是整块露着
  return filled(grid, roundBox('muzzle', CX, c + 3.6, 12, 6, 2.4), 'body')
    .dots('dark', [...rect(14, nose, 17, nose), ...rect(13, nose + 1, 18, nose + 1)])
    .dots('outline', [[13, nose + 1], [18, nose + 1]])
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
    g = swirlGlasses(g, lefts, t);
  }
  const cheek = c + FRONT_ROWS.cheek;
  const m = c + FRONT_ROWS.mouth;
  g = g.dots('blush', both(rect(8, cheek, 9, cheek)));
  g = mouth === 'open'
    ? g.dots('outline', rect(15, m, 16, m + 1)).dots('blush', [[15, m + 1], [16, m + 1]])
    : mouth === 'chew'
      ? g.dots('dark', [[14, m], [15, m + 1], [16, m + 1], [17, m]])
      // 平时：三瓣嘴「人」字，人中从鼻头底下分开
      : g.dots('dark', [[15, m - 1], [16, m - 1], [14, m], [17, m]]);
  // 叼着的草：从嘴角越过左脸颊往下垂（和侧面一样往脸前那边垂）
  if (grass) {
    g = g.dots('grass', [...rect(10, m, 14, m), [9, m + 1], [8, m + 2]])
      .dots('leaf', [[11, m - 1], [8, m + 3]]);
  }
  return g;
}

/** 去掉四角的方框一圈（像素圆） */
const ring = (x0, y0, x1, y1) => rect(x0, y0, x1, y1)
  .filter(([px, py]) => px === x0 || px === x1 || py === y0 || py === y1)
  .filter(([px, py]) => !((px === x0 || px === x1) && (py === y0 || py === y1)));

/** 像素圆的一圈：(x0,y0)–(x1,y1) 框里离圆心约等于半径的格子（大圈去四角太方，按距离取才圆） */
const circle = (x0, y0, x1, y1) => {
  const cx = (x0 + x1) / 2;
  const cy = (y0 + y1) / 2;
  const r = (x1 - x0) / 2;
  return rect(x0, y0, x1, y1).filter(([px, py]) => Math.abs(Math.hypot(px - cx, py - cy) - r) < 0.7);
};

/**
 * 读书时的圈圈眼镜（2026-11-11 用户定：老学究那种，夸张、大、透明镜片、一圈圈圈）：
 * 10×10 的像素圆粗框，比脸还宽；镜片透明，看得见脸和眼睛，眼睛外面一圈浅蓝的圈圈，左上角一点反光
 */
function swirlGlasses(grid, lefts, t) {
  let g = grid;
  for (const x of lefts) {
    g = g.dots('sweat', ring(x - 1, t - 1, x + 2, t + 2))
      .dots('white', [[x - 2, t - 2], [x - 3, t - 1]])
      .dots('outline', circle(x - 4, t - 4, x + 5, t + 5));
  }
  return g.dots('outline', rect(lefts[0] + 6, t - 1, lefts[1] - 5, t - 1));
}

/** 头顶装扮的锚点：橙子坐在头顶；正面草帽帽身高，往下压到帽檐的描边正好在眼皮上面一行 */
export function frontHatAnchor(kind, c) {
  return kind === 'straw_hat' ? [14, c - 7] : [14, c + FRONT_ROWS.hat];
}

export function frontHeadwearLayer(kind = HEADWEAR[0], c) {
  return frontHeadwear(kind, N, frontHatAnchor(kind, c));
}
