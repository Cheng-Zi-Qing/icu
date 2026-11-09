// Agent 干活时的小场景：读文件翻书、改代码写字、跑命令吃饭、派子 Agent 放小鸟、在想（正面），
// 搜索是侧身追球（chase.mjs，2026-11-08 用户要「追着球跑来跑去」）。
//
// 规则（2026-11-08 跟用户定的）：
// - 用贴边那颗正面的头（front-peek.mjs），三视图比例一致；
// - 道具大，挡住身体，只从道具后面探出头（在想 / 放小鸟没有道具，就是正面坐着）；
// - 眼珠扫、头微动，不会定住；每轮一个主动作，最后抬头看你一次。
// 每个场景是几张关键帧 + 一个播放顺序（关键帧下标，按 fps 走），写进 work/scenes.json 给 App 读。
import { Grid } from './raster.mjs';
import { DEFAULT_MODEL } from './model.mjs';
import { chaseFrame, CHASE_BEATS } from './chase.mjs';
import { HEADWEAR } from './headwear.mjs';
import { frontHead, frontHeadwearAt, frontRow, rect, both, FRONT_SIZE as N } from './front-peek.mjs';

/** 场景里头整体往上抬多少格（贴边时下巴贴着画布底边，这里要给下面的道具腾地方） */
const DY = -9;

const ring = (x0, y0, x1, y1) => rect(x0, y0, x1, y1).filter(([x, y]) => x === x0 || x === x1 || y === y0 || y === y1);
const layer = () => Grid.empty(N, N);

// ---------------- 脸 ----------------

/**
 * eyes：open 睁眼（带高光）/ down 低头专注（没高光）/ closed 闭眼 / happy 眯眼笑（^ ^）
 * look：眼珠往左（-1）或往右（+1）挪一格
 */
function face(grid, dy, { eyes = 'open', look = 0, mouth = 'calm', glasses = false, grass = false } = {}) {
  const t = frontRow(-4, dy);
  const m = frontRow(2, dy);
  const lefts = [10 + look, 20 + look];
  const eyePixels = lefts.flatMap((x) => {
    switch (eyes) {
      case 'closed': return rect(x, t + 1, x + 1, t + 1);
      case 'happy': return [[x - 1, t + 1], [x, t], [x + 1, t], [x + 2, t + 1]];
      default: return rect(x, t, x + 1, t + 1);
    }
  });
  let g = grid.dots('outline', eyePixels);
  if (eyes === 'open') g = g.dots('white', lefts.map((x) => [x, t]));
  if (glasses) {
    // 圆框：去掉四个角，用比描边浅的深棕，眼睛和高光还看得见
    const rims = [10, 20].flatMap((x) => ring(x - 1, t - 1, x + 2, t + 2)
      .filter(([px, py]) => !((px === x - 1 || px === x + 2) && (py === t - 1 || py === t + 2))));
    g = g.dots('dark', [...rims, ...rect(13, t, 18, t)]);
  }
  g = g.dots('blush', both(rect(9, m - 1, 10, m - 1)));
  g = mouth === 'open'
    ? g.dots('outline', [[15, m - 1], [16, m - 1], [15, m], [16, m]]).dots('blush', [[15, m], [16, m]])
    : g.dots('outline', [[15, m - 1], [16, m - 1], [14, m], [17, m]]);
  // 嘴角叼着的草 / 菜叶
  if (grass) g = g.dots('grass', [[17, m + 1], [18, m + 1], [19, m + 2], [20, m + 2], [21, m + 3]]).dots('leaf', [[19, m + 1], [20, m + 3]]);
  return g;
}

function headAt(dy, faceOptions, headwear) {
  return face(frontHead(dy), dy, faceOptions).overlaid(frontHeadwearAt(headwear, dy));
}

// ---------------- 爪子 ----------------

/** 一只小爪子：左上角 (x, y)，5×4，自己描边，下排两个脚趾 */
const pawShape = ([x, y]) => [...rect(x + 1, y, x + 3, y), ...rect(x, y + 1, x + 4, y + 2), ...rect(x + 1, y + 3, x + 3, y + 3)];
function paws(...anchors) {
  return anchors.reduce((g, a) => g.dots('body', pawShape(a)), layer()).outlined()
    .dots('light', anchors.map(([x, y]) => [x + 1, y + 1]))
    .dots('dark', anchors.flatMap(([x, y]) => [[x + 1, y + 3], [x + 3, y + 3]]));
}

/** 正面坐着的身子（在想、放小鸟这两个没有道具的场景） */
function sittingBody() {
  const inside = (cx, cy, rx, ry) => (x, y) => ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1;
  const round = inside(15.5, 28, 11, 8.5);
  const belly = inside(15.5, 28, 6, 4.6);
  const body = layer().fill('body', (x, y) => y <= 30 && round(x, y)).outlined();
  return body
    .fill('light', belly, 'body')
    // 两只后脚踩在底下，前爪收在肚子两边
    .dots('shade', [...rect(8, 29, 11, 30), ...rect(20, 29, 23, 30)])
    .dots('outline', [...rect(8, 31, 11, 31), ...rect(20, 31, 23, 31)])
    .dots('shade', [...rect(9, 24, 10, 25), ...rect(21, 24, 22, 25)]);
}

// ---------------- 翻书（读文件） ----------------

function book({ lift = false, standing = false, falling = false } = {}) {
  const pages = [];
  for (let y = 21; y <= 28; y += 1) {
    const inset = y === 21 ? 1 : 0;
    pages.push(...rect(3 + inset, y, 14, y), ...rect(17, y, 28 - inset, y));
    if (y > 21) pages.push([15, y], [16, y]);
  }
  let g = layer().dots('white', pages).dots('dust', rect(3, 29, 28, 29)).dots('birdWing', rect(2, 30, 29, 30));
  if (lift) g = g.dots('clear', [[28, 22], [27, 21], [28, 21]]).dots('dust', [[27, 22], [26, 21]]);
  g = g.outlined();
  // 书脊折痕、每页三行字
  g = g.dots('dust', rect(15, 23, 16, 28).filter(([x]) => x === 15));
  for (const y of [23, 25, 27]) {
    g = g.dots('dust', [...rect(5, y, 13, y), ...rect(18, y, 26, y)].filter(([x]) => (x * 5 + y) % 7 !== 0));
  }
  if (standing) {
    const page = layer().dots('white', rect(15, 15, 16, 21)).outlined().dots('dust', [[16, 16], [16, 18]]);
    g = g.overlaid(page);
  }
  if (falling) {
    const page = layer().dots('white', [...rect(8, 19, 14, 20), ...rect(10, 18, 13, 18)]).outlined().dots('dust', rect(10, 20, 13, 20));
    g = g.overlaid(page);
  }
  return g;
}

function readingFrame({ look = -1, eyes = 'down', lift = false, standing = false, falling = false, headwear }) {
  const rightPaw = lift ? [22, 18] : [24, 19];
  return headAt(DY, { eyes, look, glasses: true }, headwear)
    .overlaid(book({ lift, standing, falling }))
    .overlaid(paws([3, 19], rightPaw));
}

const READ_KEYS = [
  { look: -1 }, { look: 1 }, { look: 1, lift: true }, { look: 0, standing: true },
  { look: -1, falling: true }, { eyes: 'happy', look: 0 }, { eyes: 'open', look: 0 }, { eyes: 'closed', look: 0 },
];
const READ_ORDER = [
  ...Array(6).fill(0), ...Array(6).fill(1), ...Array(4).fill(0), ...Array(4).fill(1),
  2, 2, 3, 4, ...Array(4).fill(5), ...Array(4).fill(6), 7, 6, 6, 6,
];

// ---------------- 写字（改代码） ----------------

const WRITING_ROWS = [23, 25, 27];
/** 纸上的字：每一行从左往右，词之间空一格 */
const WRITING_STROKES = WRITING_ROWS.flatMap((y) => rect(10, y, y === 27 ? 20 : 24, y).filter(([x]) => (x * 7 + y) % 5 !== 0));

function notebook(progress) {
  const paper = [];
  for (let y = 22; y <= 29; y += 1) {
    const grow = Math.floor((y - 22) / 3);
    paper.push(...rect(5 - grow, y, 26 + grow, y));
  }
  let g = layer().dots('white', paper).dots('star', rect(1, 30, 30, 30)).dots('strawShade', rect(1, 31, 30, 31)).outlined();
  g = g.dots('sweat', WRITING_ROWS.flatMap((y) => rect(5, y + 1, 26, y + 1)));
  g = g.dots('blush', rect(8, 23, 8, 29));
  g = g.dots('outline', rect(7, 22, 24, 22).filter(([x]) => x % 2 === 1));
  return g.dots('birdWing', WRITING_STROKES.slice(0, progress));
}

/** 握着铅笔的右爪：笔尖在 tip，笔往右上斜 */
function pencilInPaw([tx, ty]) {
  const pencil = layer()
    .dots('dark', [[tx, ty]])
    .dots('star', [[tx + 1, ty - 1], [tx + 2, ty - 2], [tx + 3, ty - 3], [tx + 4, ty - 4]])
    .dots('blush', [[tx + 5, ty - 5]]);
  return pencil.overlaid(paws([tx + 1, ty - 3]));
}

function writingFrame({ progress, thinking = false, eyes = 'down', headwear }) {
  const done = WRITING_STROKES[Math.max(0, Math.min(progress, WRITING_STROKES.length) - 1)] ?? [10, 23];
  const tip = [done[0] + 1, done[1]];
  const look = tip[0] < 14 ? -1 : tip[0] > 18 ? 1 : 0;
  const base = headAt(DY, { eyes: thinking ? 'open' : eyes, look: thinking ? 1 : look, grass: !thinking }, headwear)
    .overlaid(notebook(progress))
    .overlaid(paws([2, 21]));
  // 想一想：用笔头点下巴
  return base.overlaid(thinking ? pencilInPaw([19, 21]) : pencilInPaw(tip));
}

const WRITE_STEP = 3;
const WRITE_PROGRESS = Array.from({ length: Math.ceil(WRITING_STROKES.length / WRITE_STEP) + 1 }, (_, i) => Math.min(i * WRITE_STEP, WRITING_STROKES.length));
const WRITE_KEYS = [
  ...WRITE_PROGRESS.map((progress) => ({ progress })),
  { progress: WRITE_PROGRESS[6], thinking: true },
  { progress: WRITING_STROKES.length, eyes: 'happy' },
  { progress: WRITING_STROKES.length, eyes: 'open' },
];
const THINK_INDEX = WRITE_PROGRESS.length;
const WRITE_ORDER = [
  ...WRITE_PROGRESS.slice(0, 7).flatMap((_, i) => [i, i]),
  ...Array(5).fill(THINK_INDEX),
  ...WRITE_PROGRESS.slice(7).flatMap((_, i) => [i + 7, i + 7]),
  ...Array(4).fill(THINK_INDEX + 1), ...Array(4).fill(THINK_INDEX + 2),
];

// ---------------- 吃饭（跑命令） ----------------

function bowl(level) {
  const shape = [];
  for (let y = 23; y <= 30; y += 1) shape.push(...rect(2 + Math.floor((y - 23) * 0.9), y, 29 - Math.floor((y - 23) * 0.9), y));
  let g = layer().dots('sweat', [...shape, ...rect(11, 31, 20, 31)]);
  // 菜堆：level 0–3，越吃越低
  if (level > 0) {
    const greens = [];
    for (let y = 23 - level; y <= 22; y += 1) {
      const shrink = (y - (23 - level)) === 0 ? 4 : (y - (23 - level)) === 1 ? 2 : 0;
      greens.push(...rect(4 + shrink, y, 27 - shrink, y));
    }
    g = g.dots('grass', greens);
  }
  g = g.outlined();
  g = g.dots('white', rect(4, 24, 27, 24).filter(([x]) => x % 3 === 0));
  g = g.dots('birdWing', [...rect(8, 30, 23, 30), ...rect(11, 31, 20, 31)].filter(([, y]) => y === 30));
  if (level > 0) g = g.dots('leaf', rect(4, 23 - level, 27, 22).filter(([x, y]) => (x * 3 + y * 5) % 7 === 0));
  return g;
}

function eatingFrame({ level, dip = false, eyes = 'open', grass = false, headwear }) {
  const dy = dip ? DY + 3 : DY;
  return headAt(dy, { eyes, grass, mouth: dip ? 'calm' : 'calm' }, headwear)
    .overlaid(bowl(level))
    .overlaid(paws([1, 21], [26, 21]));
}

const EAT_KEYS = [];
const EAT_ORDER = [];
for (const level of [3, 2, 1]) {
  const at = EAT_KEYS.length;
  EAT_KEYS.push({ level, dip: true, eyes: 'happy' }, { level, grass: true, eyes: 'closed' }, { level, grass: true, eyes: 'happy' });
  EAT_ORDER.push(at, at, at, at + 1, at + 1, at + 2, at + 2, at + 1, at + 1);
}
EAT_KEYS.push({ level: 0, eyes: 'open' }, { level: 3, eyes: 'open' });
EAT_ORDER.push(9, 9, 9, 9, 10, 10);

// ---------------- 放小鸟（派子 Agent） ----------------

function bird([x, y], wingUp) {
  return layer()
    .dots('bird', [...rect(x, y, x + 2, y + 1), [x - 1, y]])
    .dots('birdWing', wingUp ? [[x + 1, y - 1], [x + 2, y - 1]] : [[x + 1, y + 2], [x + 2, y + 2]])
    .outlined()
    .dots('star', [[x - 2, y]])
    .dots('outline', [[x, y]]);
}

const BIRD_PATH = [null, [20, 5], [23, 3], [26, 2], [28, 1], null, null, [28, 1], [26, 2], [23, 3], [20, 5], null];
function delegateFrame({ step, headwear }) {
  const spot = BIRD_PATH[step];
  const look = spot ? 1 : 0;
  const eyes = step === BIRD_PATH.length - 1 ? 'happy' : 'open';
  const scene = sittingBody().overlaid(headAt(DY, { eyes, look, grass: true }, headwear));
  return spot ? scene.overlaid(bird(spot, step % 2 === 0)) : scene;
}

const DELEGATE_KEYS = BIRD_PATH.map((_, step) => ({ step }));
const DELEGATE_ORDER = [0, 0, 0, 1, 2, 3, 4, 5, 5, 6, 6, 7, 8, 9, 10, 11, 11, 11];

// ---------------- 汇总 ----------------

/** 场景名（App 用同样的名字）→ 关键帧画法、关键帧参数、播放顺序 */
const SCENE_DEFINITIONS = {
  read: { render: readingFrame, keys: READ_KEYS, order: READ_ORDER },
  write: { render: writingFrame, keys: WRITE_KEYS, order: WRITE_ORDER },
  eat: { render: eatingFrame, keys: EAT_KEYS, order: EAT_ORDER },
  // 侧身小跑，8 帧/秒；motion: chase 让 App 把窗口左右来回挪
  search: {
    render: ({ beat, headwear, model }) => chaseFrame(model, beat, { headwear }),
    // 用到时才读 CHASE_BEATS：从 chase.mjs 进入时它还没初始化（chase → render → front-work → chase）
    get keys() { return Array.from({ length: CHASE_BEATS }, (_, beat) => ({ beat })); },
    get order() { return Array.from({ length: CHASE_BEATS * 6 }, (_, i) => i % CHASE_BEATS); },
    fps: 8,
    motion: 'chase',
  },
  // 在想事情（还没调用工具）没有专门的场景：保持平时侧身坐着嚼草（用户 2026-11-08 定，正面干坐着太丑）
  delegate: { render: delegateFrame, keys: DELEGATE_KEYS, order: DELEGATE_ORDER },
};

export const WORK_SCENES = Object.keys(SCENE_DEFINITIONS);
export const WORK_FPS = 4;

/** 某个场景的全部关键帧（侧身追球要用侧面模型） */
export function workSceneFrames(name, headwear = HEADWEAR[0], model = DEFAULT_MODEL) {
  const { render, keys } = SCENE_DEFINITIONS[name];
  return keys.map((options) => render({ ...options, headwear, model }));
}

/** work/scenes.json：每个场景的帧率和播放顺序（关键帧下标） */
export function workSceneManifest() {
  const scenes = Object.fromEntries(Object.entries(SCENE_DEFINITIONS).map(([name, { keys, order, fps, motion }]) => [
    name,
    { frames: keys.map((_, i) => `${name}_${i}.png`), order, ...(fps ? { fps } : {}), ...(motion ? { motion } : {}) },
  ]));
  return { fps: WORK_FPS, scenes };
}

/** 素材帧：`work/<场景>_<n>.png` */
export function workFrames(headwear = HEADWEAR[0], model = DEFAULT_MODEL) {
  return WORK_SCENES.flatMap((name) => workSceneFrames(name, headwear, model).map((grid, i) => [`work/${name}_${i}.png`, grid]));
}
