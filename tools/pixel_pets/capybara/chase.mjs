// 搜索时侧身追球：水豚撒腿小跑，前面滚着一个小球。
// 用侧面那套模型（头和配色和坐姿一样，头缩到 0.85 倍配横过来的身体），四条腿交替；脸朝左，往右跑时 App 整张镜像。
// 画面本身原地跑，App 把窗口左右来回挪，看起来就是追着球跑来跑去。
import { HEADWEAR } from './headwear.mjs';
import { renderPose } from './render.mjs';
import { Grid } from './raster.mjs';

const ell = (id, ink, cx, cy, rx, ry, extra = {}) => ({ id, label: id, shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0, ...extra });
const cap = (id, ink, x1, y1, x2, y2, r, extra = {}) => ({ id, label: id, shape: 'capsule', ink, x1, y1, x2, y2, r, ...extra });
const HEAD = { id: 'head', label: '头（整体）', shape: 'head' };

/**
 * 小跑的四拍：腿伸开 → 交叉 → 收拢（身子腾起一格）→ 交叉。
 * 每条腿是 [肩/胯的位置, 脚的位置]；bob 是身体上下起伏
 */
const GAIT = [
  { bob: 0, nearFront: [7, 30], farFront: [9, 30], nearHind: [28, 30], farHind: [26, 30] },
  { bob: -1, nearFront: [11, 30], farFront: [13, 29], nearHind: [23, 30], farHind: [25, 29] },
  { bob: -1, nearFront: [14, 29], farFront: [12, 29], nearHind: [20, 29], farHind: [22, 29] },
  { bob: 0, nearFront: [12, 29], farFront: [10, 30], nearHind: [25, 29], farHind: [23, 30] },
];

function runPose({ bob, nearFront, farFront, nearHind, farHind }) {
  const shoulder = [13, 24 + bob];
  const hip = [25, 24 + bob];
  const leg = (id, ink, [x0, y0], [x1, y1]) => cap(id, ink, x0, y0, x1, y1 - 0.5, 1.1);
  const paw = (id, ink, [x, y], onlyOver) => ell(id, 'dark', x, y, 1.3, 0.9, { onlyOver });
  return {
    width: 32,
    // 身体横过来没有坐姿厚，头照原尺寸会显得头大身小：头略缩、身体加厚加长（屁股已到画布右边缘），头身比接近坐姿
    head: { x: 8.5, y: 15.5 + bob, rot: -4, scale: 0.85 },
    yuzu: true,
    parts: [
      leg('farFrontLeg', 'shade', shoulder, farFront),
      leg('farHindLeg', 'shade', hip, farHind),
      ell('barrel', 'body', 19.5, 19.6 + bob, 10.6, 6.9),
      // 屁股和背连成一条顺的线，不单独鼓成一个球
      ell('rump', 'body', 25, 19.8 + bob, 5.9, 6.3),
      ell('chest', 'body', 12.5, 19.6 + bob, 5.8, 6.4),
      ell('nape', 'body', 14, 14.4 + bob, 4.6, 4.6),
      ell('tummy', 'light', 18, 24.8 + bob, 6.2, 2.4, { onlyOver: 'body' }),
      HEAD,
      leg('nearFrontLeg', 'body', shoulder, nearFront),
      leg('nearHindLeg', 'body', hip, nearHind),
      paw('nearFrontPaw', 'dark', nearFront, 'body'),
      paw('nearHindPaw', 'dark', nearHind, 'body'),
      paw('farFrontPaw', 'dark', farFront, 'shade'),
      paw('farHindPaw', 'dark', farHind, 'shade'),
    ],
    marks: [{ ink: 'light', points: [[21, 14 + bob], [22, 14 + bob], [23, 14 + bob], [24, 14 + bob]] }],
  };
}

const BALL_INKS = ['blush', 'white', 'sweat', 'star'];
/** 跑在前面的小球（5×5），滚一拍转一格 */
function ball(spin, lift) {
  const top = 26 - lift;
  const shape = [[1, 0], [2, 0], [3, 0], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4]];
  const g = shape.reduce((grid, [x, y]) => grid.dots(BALL_INKS[(Math.floor((x + spin) / 2) % 4 + 4) % 4], [[x, top + y]]), Grid.empty(32, 32));
  return g.outlined().dots('white', [[1, top + 1]]);
}

/** 第 beat 拍：腿按四拍走，球一路滚、偶尔被鼻子拱得弹起来一格 */
export function chaseFrame(model, beat, { headwear = HEADWEAR[0] } = {}) {
  const gait = GAIT[beat % GAIT.length];
  const withRun = { ...model, poses: { ...model.poses, run: runPose(gait) } };
  const pet = renderPose(withRun, 'run', { headwear, chewPhase: beat % 2, blink: false });
  const lift = beat % 4 === 2 ? 1 : 0;
  return pet.overlaid(ball(beat, lift));
}

export const CHASE_BEATS = 4;
