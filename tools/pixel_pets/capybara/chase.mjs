// 搜索时侧身追球：水豚撒腿小跑，前面滚着一个小球。
// 用侧面那套模型（头和坐姿一样大，不缩放），身子横过来比坐着长，画布加宽到 CHASE_WIDTH；四条腿交替；脸朝左，往右跑时 App 整张镜像。
// 画面本身原地跑，App 把窗口左右来回挪，看起来就是追着球跑来跑去。
import { HEADWEAR } from './headwear.mjs';
import { renderPose } from './render.mjs';
import { Grid } from './raster.mjs';

const ell = (id, ink, cx, cy, rx, ry, extra = {}) => ({ id, label: id, shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0, ...extra });
const cap = (id, ink, x1, y1, x2, y2, r, extra = {}) => ({ id, label: id, shape: 'capsule', ink, x1, y1, x2, y2, r, ...extra });
const HEAD = { id: 'head', label: '头（整体）', shape: 'head' };

/** 小跑的画布宽：身子横过来比坐着长，32 格放不下（头不缩，2026-11-11 用户定加宽） */
export const CHASE_WIDTH = 38;

/**
 * 小跑的四拍：腿伸开 → 交叉 → 收拢（身子腾起一格）→ 交叉。
 * 每条腿是 [肩/胯的位置, 脚的位置]；bob 是身体上下起伏
 */
const GAIT = [
  { bob: 0, nearFront: [8, 30], farFront: [11, 30], nearHind: [35, 30], farHind: [32, 30] },
  { bob: -1, nearFront: [12, 30], farFront: [14, 29], nearHind: [30, 30], farHind: [33, 29] },
  { bob: -1, nearFront: [15, 29], farFront: [12, 29], nearHind: [27, 29], farHind: [30, 29] },
  { bob: 0, nearFront: [13, 29], farFront: [10, 30], nearHind: [32, 29], farHind: [29, 30] },
];

/**
 * 站着小跑：照真水豚的体态——背是一条平的线（屁股略高于肩），头往前伸、略低于背，腿露出 5 格左右。
 * 头和坐姿一样大（不缩放），身子一整条长桶
 */
function runPose({ bob, nearFront, farFront, nearHind, farHind }) {
  const shoulder = [13, 24 + bob];
  const hip = [31, 24 + bob];
  const leg = (id, ink, [x0, y0], [x1, y1]) => cap(id, ink, x0, y0, x1, y1 - 0.5, 1.4);
  const paw = (id, [x, y], onlyOver) => ell(id, 'dark', x, y, 1.4, 0.9, { onlyOver });
  return {
    width: CHASE_WIDTH,
    head: { x: 9.5, y: 17.5 + bob, rot: -6, scale: 1 },
    yuzu: true,
    parts: [
      leg('farFrontLeg', 'body', shoulder, farFront),
      leg('farHindLeg', 'body', hip, farHind),
      ell('barrel', 'body', 22.5, 19.4 + bob, 13.6, 7),
      ell('rump', 'body', 30.6, 18.8 + bob, 6.6, 7.6),
      ell('chest', 'body', 14, 20 + bob, 6.8, 6.6),
      ell('nape', 'body', 15, 15.5 + bob, 4.6, 4.4),
      HEAD,
      leg('nearFrontLeg', 'body', shoulder, nearFront),
      leg('nearHindLeg', 'body', hip, nearHind),
      paw('nearFrontPaw', nearFront, 'body'),
      paw('nearHindPaw', nearHind, 'body'),
      paw('farFrontPaw', farFront, 'body'),
      paw('farHindPaw', farHind, 'body'),
    ],
    marks: [{ ink: 'light', points: [[23, 13 + bob], [24, 13 + bob], [25, 13 + bob], [26, 13 + bob]] }],
  };
}

const BALL_INKS = ['blush', 'white', 'sweat', 'star'];
/** 跑在前面的小球（5×5），滚一拍转一格 */
function ball(spin, lift) {
  const top = 26 - lift;
  const shape = [[1, 0], [2, 0], [3, 0], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4]];
  const g = shape.reduce((grid, [x, y]) => grid.dots(BALL_INKS[(Math.floor((x + spin) / 2) % 4 + 4) % 4], [[x, top + y]]), Grid.empty(CHASE_WIDTH, 32));
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
