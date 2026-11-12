// Agent 干活时的小场景：读文件翻书、改代码写字、跑命令吃饭（正面，从道具后面探出头），
// 派子 Agent 放小鸟是侧身（state-scenes.mjs），
// 搜索是侧身追球（chase.mjs，2026-11-08 用户要「追着球跑来跑去」）。
//
// 规则（2026-11-08 跟用户定的）：
// - 用贴边那颗正面的头（front-peek.mjs），三视图比例一致；
// - 道具大，挡住身体，只从道具后面探出头（没有道具的就不用正脸：正面干坐着光秃秃的）；
// - 眼珠扫、头微动，不会定住；每轮一个主动作，最后抬头看你一次。
// 每个场景是几张关键帧 + 一个播放顺序（关键帧下标，按 fps 走），写进 work/scenes.json 给 App 读。
import { Grid } from './raster.mjs';
import { DEFAULT_MODEL } from './model.mjs';
import { stateSceneDefinitions } from './state-scenes.mjs';
import { variantSceneDefinitions } from './variant-scenes.mjs';
import { chaseFrame, CHASE_BEATS } from './chase.mjs';
import { HEADWEAR } from './headwear.mjs';
import { frontFace, frontHead, frontHeadwearLayer, rect, FRONT_SIZE as N } from './front-head.mjs';

/** 场景里头中心那一行：头整体抬高，给下面的道具腾地方（道具挡住下巴，嘴和鼻头露在外面） */
const HEAD_ROW = 15;
/** 吃饭埋头时往下沉几格 */
const DIP = 3;

const ring = (x0, y0, x1, y1) => rect(x0, y0, x1, y1).filter(([x, y]) => x === x0 || x === x1 || y === y0 || y === y1);
const layer = () => Grid.empty(N, N);

// ---------------- 头 ----------------

/** 正面那颗头（和贴边同一颗）带表情和头顶装扮；eyes 见 front-head.mjs 的 frontFace */
function headAt(c, faceOptions, headwear) {
  return frontFace(frontHead(c), c, faceOptions).overlaid(frontHeadwearLayer(headwear, c));
}

// ---------------- 爪子 ----------------

/** 一只小爪子：左上角 (x, y)，5×4，自己描边，下排两个脚趾 */
const pawShape = ([x, y]) => [...rect(x + 1, y, x + 3, y), ...rect(x, y + 1, x + 4, y + 2), ...rect(x + 1, y + 3, x + 3, y + 3)];
function paws(...anchors) {
  return anchors.reduce((g, a) => g.dots('body', pawShape(a), 'paw'), layer()).outlined()
    .dots('light', anchors.map(([x, y]) => [x + 1, y + 1]))
    .dots('dark', anchors.flatMap(([x, y]) => [[x + 1, y + 3], [x + 3, y + 3]]));
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
  return headAt(HEAD_ROW, { eyes, look, glasses: true }, headwear)
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
  const base = headAt(HEAD_ROW, { eyes: thinking ? 'open' : eyes, look: thinking ? 1 : look, grass: !thinking }, headwear)
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

function eatingFrame({ level, dip = false, eyes = 'relaxed', grass = false, headwear }) {
  const c = dip ? HEAD_ROW + DIP : HEAD_ROW;
  return headAt(c, { eyes, grass, mouth: grass ? 'chew' : 'calm' }, headwear)
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
  // 派子 Agent 放小鸟、在等你 / 干完了 / 出错了、两段健康提醒：侧身坐姿（见 state-scenes.mjs）
  ...stateSceneDefinitions(),
  // 同一种状态的另几种演法（冲浪、拍按钮、翻箱子、啃纸、摔跤、在想、休息钓鱼），见 variant-scenes.mjs
  ...variantSceneDefinitions(),
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
  const scenes = Object.fromEntries(Object.entries(SCENE_DEFINITIONS).map(([name, { keys, order, fps, motion, once, hop, variantOf, side }]) => [
    name,
    {
      frames: keys.map((_, i) => `${name}_${i}.png`),
      order,
      ...(fps ? { fps } : {}),
      ...(motion ? { motion } : {}),
      ...(once ? { once } : {}),
      ...(hop ? { hop } : {}),
      ...(variantOf ? { variantOf } : {}),
      ...(side ? { side } : {}),
    },
  ]));
  return { fps: WORK_FPS, scenes };
}

/** 素材帧：`work/<场景>_<n>.png` */
export function workFrames(headwear = HEADWEAR[0], model = DEFAULT_MODEL) {
  return WORK_SCENES.flatMap((name) => workSceneFrames(name, headwear, model).map((grid, i) => [`work/${name}_${i}.png`, grid]));
}
