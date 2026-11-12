// 参数 → 像素帧。浏览器编辑器和命令行构建共用这一份渲染逻辑。
import { Grid, SIDES, canvasPixel, partMask, partTag } from './raster.mjs';
import { renderFrontPeek, renderFrontUpright } from './front-peek.mjs';
import { HEADWEAR, itemIcon, sideHeadwear } from './headwear.mjs';
import { workFrames } from './front-work.mjs';
import { pokeFrames } from './poke-reactions.mjs';
import { IDLE_EXTRA_RENDER, idleExtraOptions } from './idle-extras.mjs';

export const CANVAS_HEIGHT = 32;

// 小图案（相对锚点像素的整数偏移，不随头旋转，避免小图案被旋转打散）
const PATTERNS = {
  eyeOpen: { shade: [[0, 0], [1, 0]], outline: [[0, 1], [1, 1]] },
  eyeClosed: { outline: [[0, 1], [1, 1]] },
  eyeSqueeze: { outline: [[0, -1], [1, 0], [0, 1]] },
  eyeDizzy: { outline: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]] },
  // 抬眼往上看（看头顶的柚子、背上的小鸟）：眼珠挪到上面一行
  eyeUp: { outline: [[0, 0], [1, 0]], shade: [[0, 1], [1, 1]] },
  // 被摸头时眯成一道往上弯的缝（^）
  eyeHappy: { outline: [[0, 1], [1, 0], [2, 1]] },
  // 不耐烦地斜着眼（¬_¬）：眼皮压下来一道粗线，底下只露一点眼珠
  eyeFlat: { outline: [[-1, 0], [0, 0], [1, 0], [2, 0], [1, 1]] },
  blush: [[0, 0], [1, 0], [0, 1], [1, 1]],
  highlight: [[0, 0], [1, 0], [2, 0], [3, 0]],
  mouth: [[[0, 0], [1, 0]], [[0, 0], [1, 1]]],
  // 哈哈大笑 / 打喷嚏时张开的嘴
  mouthOpen: [[0, 0], [1, 0], [0, 1], [1, 1]],
  grass: [
    [[0, 0], [0, 1], [-1, 2], [-1, 3], [-2, 4], [0, 3]],
    [[0, 0], [-1, 1], [-1, 2], [-2, 3], [-2, 2], [0, 2]],
  ],
};

const OVERLAYS = {
  sweat: [[25, 9], [24, 10], [25, 10], [26, 10], [24, 11], [25, 11], [26, 11], [25, 12]],
  stars: [
    [[8, 0], [7, 1], [8, 1], [9, 1], [8, 2], [25, 3]],
    [[25, 2], [24, 3], [25, 3], [26, 3], [25, 4], [8, 1]],
  ],
  dust: [
    [[6, 30], [7, 30], [7, 29], [31, 29], [30, 30], [31, 30]],
    [[4, 30], [5, 29], [5, 30], [4, 28], [6, 28]],
  ],
};

// 飘在背上方空白处的小记号（各自描边，深色浅色桌面上都看得清）
const STAMPS = {
  heart: { ink: 'blush', points: [[0, 0], [2, 0], [0, 1], [1, 1], [2, 1], [1, 2]] },
  bigHeart: { ink: 'blush', points: [[1, 0], [3, 0], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [1, 2], [2, 2], [3, 2], [2, 3]] },
  z: { ink: 'white', points: [[0, 0], [1, 0], [2, 0], [3, 0], [2, 1], [1, 2], [0, 3], [1, 3], [2, 3], [3, 3]] },
  bigZ: {
    ink: 'white',
    points: [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [3, 1], [2, 2], [1, 3], [0, 4], [1, 4], [2, 4], [3, 4], [4, 4]],
  },
  bang: { ink: 'white', points: [[0, 0], [0, 1], [0, 2], [0, 4]] },
  // 出错时头顶的问号（3×6）
  question: { ink: 'white', points: [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [2, 2], [1, 3], [1, 5]] },
  // 干完了冒的小星星（十字）
  sparkle: { ink: 'star', points: [[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]] },
};

/** 摸头时爱心从背上冒出来往上飘（左上角坐标） */
const HEART_PATH = [
  { stamp: 'heart', at: [24, 7] },
  { stamp: 'heart', at: [24, 5] },
  { stamp: 'bigHeart', at: [23, 2] },
  { stamp: 'bigHeart', at: [24, 0] },
];

/** 睡着时 z 从背上往右上飘：小 z 变大 Z */
const ZZZ_PATH = [
  { stamp: 'z', at: [23, 5] },
  { stamp: 'z', at: [24, 3] },
  { stamp: 'bigZ', at: [25, 1] },
  { stamp: 'bigZ', at: [26, 0] },
];

const BANG_AT = [24, 1];
/** 问号先冒在背上方低一格，再升到位 */
// 下面这几个记号都放在背的右上方：草帽的帽檐比橙子往右伸得远，太靠左会压在帽檐上
const QUESTION_PATH = [
  { stamp: 'question', at: [28, 5] },
  { stamp: 'question', at: [28, 3] },
];
/** 在等你：背上方一闪一闪的「!」 */
const ALERT_AT = [27, 3];
/** 干完了：两颗小星星一前一后亮 */
const SPARKLE_PATH = [
  [{ stamp: 'sparkle', at: [25, 8] }],
  [{ stamp: 'sparkle', at: [25, 8] }, { stamp: 'sparkle', at: [28, 3] }],
];

// 小鸟（脸朝左，和水豚同向）：按颜色分组的像素，左上角为原点
const BIRD_SHAPES = {
  sit: {
    bird: [[1, 0], [2, 0], [2, 1], [3, 1], [1, 2], [2, 2], [3, 2], [4, 2]],
    birdWing: [[3, 2]],
    star: [[0, 1]],
    outline: [[1, 1]],
    dark: [[2, 3], [3, 3]],
  },
  wingsUp: {
    bird: [[1, 1], [2, 1], [2, 2], [3, 2], [4, 2], [5, 2]],
    birdWing: [[3, 0], [3, 1], [4, 0]],
    star: [[0, 2]],
    outline: [[1, 2]],
  },
  wingsDown: {
    bird: [[1, 0], [2, 0], [2, 1], [3, 1], [4, 1], [5, 1]],
    birdWing: [[3, 2], [4, 2], [3, 3]],
    star: [[0, 1]],
    outline: [[1, 1]],
  },
};

const offsetPoints = (anchor, points) => points.map(([dx, dy]) => [anchor[0] + dx, anchor[1] + dy]);

// ---------- 姿势解析 ----------

function shiftPart(part, dx, dy) {
  if (part.shape === 'capsule') {
    return { ...part, x1: part.x1 + dx, x2: part.x2 + dx, y1: part.y1 + dy, y2: part.y2 + dy };
  }
  if (part.shape === 'head') return part;
  return { ...part, cx: part.cx + dx, cy: part.cy + dy };
}

/**
 * 姿势的部件和头位置（派生姿势返回它的底姿势）。
 * 派生姿势不在这里平移：它是把底姿势整张画好以后再旋转 / 平移 / 裁切（见 renderDerived）。
 */
export function resolvePose(model, name) {
  const pose = model.poses[name];
  if (!pose) throw new Error(`unknown pose: ${name}`);
  return pose.from ? model.poses[pose.from] : pose;
}

/** 帧变体对部件的影响：呼吸鼓起、爪子往外扒 */
function adjustedPart(part, opts, pose) {
  let next = part;
  if (opts.inhale && part.breathe) {
    next = { ...next, cy: next.cy - 0.5, ry: next.ry + 0.5 };
  }
  if (opts.reach && part.reach && pose.reachPixels) {
    next = shiftPart(next, -pose.reachPixels, 0);
    if (part.shape === 'capsule') next = { ...next, x2: next.x2, x1: part.x1 };
  }
  return next;
}

// ---------- 绘制 ----------

function drawPart(grid, part, transform, tag = partTag(part.id)) {
  const mask = partMask(part, transform);
  const filled = grid.fill(part.ink, mask, part.onlyOver ?? null, tag);
  if (!part.edge) return filled;
  return filled.edged(mask, SIDES[part.edge] ?? SIDES.below);
}

function drawHead(grid, head, transform, opts) {
  const parts = head.parts.map((part) => (part.id === 'ear' && opts.earTwitch ? { ...part, cx: part.cx + 1 } : part));
  const filled = parts.reduce((g, part) => drawPart(g, part, transform, 'head'), grid);
  return drawFaceMarks(filled, head.marks, transform, opts);
}

function drawFaceMarks(grid, marks, transform, opts) {
  const at = (mark) => canvasPixel(transform, mark.x, mark.y);
  const eyeAnchor = at(marks.eye);
  const eye = {
    squeeze: PATTERNS.eyeSqueeze,
    dizzy: PATTERNS.eyeDizzy,
    happy: PATTERNS.eyeHappy,
    flat: PATTERNS.eyeFlat,
  }[opts.face] ?? (opts.blink ? PATTERNS.eyeClosed : opts.eyes === 'up' ? PATTERNS.eyeUp : PATTERNS.eyeOpen);
  const earInner = at(marks.earInner);

  return grid
    .dots('light', offsetPoints(at(marks.highlight), PATTERNS.highlight))
    .dots('dark', [opts.earTwitch ? [earInner[0] + 1, earInner[1]] : earInner])
    .dots('blush', offsetPoints(at(marks.blush), PATTERNS.blush))
    .dots('outline', [at(marks.nostril)])
    .dots('outline', offsetPoints(at(marks.mouth), opts.mouth === 'open' ? PATTERNS.mouthOpen : PATTERNS.mouth[opts.chewPhase === 1 ? 1 : 0]))
    .dots('shade', offsetPoints(eyeAnchor, eye.shade ?? []))
    .dots('outline', offsetPoints(eyeAnchor, eye.outline ?? []));
}

/** 小记号单独一层：自己描边后叠上去 */
function stampLayer(width, { stamp, at }) {
  const { ink, points } = STAMPS[stamp];
  return Grid.empty(width, CANVAS_HEIGHT).dots(ink, offsetPoints(at, points)).outlined();
}

/** 小鸟一层：先画身体再整体描边，眼睛 / 嘴 / 脚按自己的颜色覆盖上去。faceRight 时左右镜像 */
function birdLayer(width, { pose, at, faceRight = false }) {
  const base = BIRD_SHAPES[pose];
  const right = Math.max(...Object.values(base).flat().map(([x]) => x));
  const shape = faceRight
    ? Object.fromEntries(Object.entries(base).map(([ink, points]) => [ink, points.map(([x, y]) => [right - x, y])]))
    : base;
  const silhouette = Object.values(shape).flat();
  const outlined = Grid.empty(width, CANVAS_HEIGHT).dots('bird', offsetPoints(at, silhouette)).outlined();
  return Object.entries(shape).reduce((g, [ink, points]) => g.dots(ink, offsetPoints(at, points)), outlined);
}

/** 头顶装扮单独一层（默认橙子）：自己描边后叠到头顶，底边描边和头顶描边重合 */
function headwearLayer(width, transform, anchorMark, kind) {
  const anchor = canvasPixel(transform, anchorMark.x, anchorMark.y);
  return sideHeadwear(kind ?? HEADWEAR[0], width, CANVAS_HEIGHT, anchor);
}

/**
 * 渲染一帧。opts:
 *   blink, inhale, earTwitch, chewPhase(0|1), face('squeeze'|'dizzy'|'happy'|'flat'), mouth('open'),
 *   grassOffset([dx, dy] 嘴里的草挪开几格), squeezeSweat(false 时眯紧眼不带汗),
 *   tilt(-2...2), twinkle(0|1), dust(0|1), reach, props(柚子 + 草，默认跟姿势走), grass(false 时不叼草),
 *   nod(打盹低头一格), heart(HEART_PATH 下标), zzz(ZZZ_PATH 下标), bang(醒来的感叹号),
 *   eyes('up' 抬眼), yuzuShift(头顶装扮左右偏几格), bird({ pose: 'sit'|'wingsUp'|'wingsDown', at: [x, y] }),
 *   headwear(头顶戴什么，见 headwear.mjs；默认橙子), yuzuLift(头顶装扮比头高出几格),
 *   alert(在等你的「!」), question(QUESTION_PATH 下标，出错时的问号), sparkle(SPARKLE_PATH 下标，干完了的小星星)
 */
export function renderPose(model, name, opts = {}) {
  const pose = model.poses[name];
  if (!pose) throw new Error(`unknown pose: ${name}`);
  return pose.from ? renderDerived(model, pose, opts) : renderBase(model, pose, opts);
}

/**
 * 派生姿势（贴边探头）：底姿势整张画好 → 按 90° 旋转 → 可选上下翻转 → 平移 → 裁成 width × 32。
 * 画布右边就是屏幕边。headOnly 时只画头（身体藏在屏幕外）；reach 帧整个往屏幕里多探 reachPixels。
 */
function renderDerived(model, pose, opts) {
  const source = model.poses[pose.from];
  const kept = new Set(pose.keepParts ?? []);
  // extraParts 画在头下面（比如探头时伸进屏幕边的脖子）
  const base = pose.headOnly
    ? { ...source, parts: [...(pose.extraParts ?? []), ...source.parts.filter((part) => part.shape === 'head' || kept.has(part.id))], marks: [] }
    : source;
  const grass = pose.grass ?? opts.grass;
  let grid = renderBase(model, base, { ...opts, grass, reach: false, width: undefined }).rotatedQuarter(pose.turn ?? 0);
  if (pose.flipY) grid = grid.flippedVertically();
  const width = opts.width ?? pose.width ?? 32;
  const poke = opts.reach ? pose.reachPixels ?? 0 : 0;
  return grid.windowed(-Math.round((pose.offsetX ?? 0) - poke), -Math.round(pose.offsetY ?? 0), width, CANVAS_HEIGHT);
}

function renderBase(model, pose, opts) {
  const width = opts.width ?? pose.width ?? 32;
  const head = { ...pose.head, y: pose.head.y + (opts.inhale ? -1 : 0) + (opts.nod ? 1 : 0) };
  const props = opts.props ?? pose.yuzu ?? false;

  let grid = Grid.empty(width, CANVAS_HEIGHT);
  for (const part of pose.parts) {
    grid = part.shape === 'head'
      ? drawHead(grid, model.head, head, opts)
      : drawPart(grid, adjustedPart(part, opts, pose), null);
  }
  for (const mark of pose.marks ?? []) {
    grid = grid.dots(mark.ink, mark.points);
  }
  if (pose.tiltDegrees && opts.tilt) {
    grid = grid.sheared(opts.tilt * pose.tiltDegrees, pose.pivotRow ?? 16);
  }
  grid = grid.outlined();

  if (props) {
    // grassOffset：打喷嚏时嘴里的草被喷出去几格
    const [grassDx, grassDy] = opts.grassOffset ?? [0, 0];
    const grass = canvasPixel(head, model.head.marks.grass.x + grassDx, model.head.marks.grass.y + grassDy);
    if (opts.grass !== false) grid = grid.dots('grass', offsetPoints(grass, PATTERNS.grass[opts.chewPhase === 1 ? 1 : 0]));
    grid = grid
      .overlaid(headwearLayer(width, head, { ...model.head.marks.yuzu, x: model.head.marks.yuzu.x + (opts.yuzuShift ?? 0), y: model.head.marks.yuzu.y - (opts.yuzuLift ?? 0) }, opts.headwear));
  }
  // 眯紧眼默认带一滴汗（被拎着难受）；打喷嚏也眯眼，但不出汗
  if (opts.face === 'squeeze' && opts.squeezeSweat !== false) grid = grid.dots('sweat', OVERLAYS.sweat);
  if (opts.face === 'dizzy') grid = grid.dots('star', OVERLAYS.stars[opts.twinkle ? 1 : 0]);
  if (opts.dust !== undefined && opts.dust !== null) grid = grid.dots('dust', OVERLAYS.dust[opts.dust]);
  const stamps = [
    opts.heart != null ? HEART_PATH[opts.heart] : null,
    opts.zzz != null ? ZZZ_PATH[opts.zzz] : null,
    opts.bang ? { stamp: 'bang', at: BANG_AT } : null,
    opts.alert ? { stamp: 'bang', at: ALERT_AT } : null,
    opts.question != null ? QUESTION_PATH[opts.question] : null,
    ...(opts.sparkle != null ? SPARKLE_PATH[opts.sparkle] : []),
  ].filter(Boolean);
  const stamped = stamps.reduce((g, stamp) => g.overlaid(stampLayer(width, stamp)), grid);
  return opts.bird ? stamped.overlaid(birdLayer(width, opts.bird)) : stamped;
}

// ---------- 全部素材帧 ----------

/** 8fps：main 4 秒一轮（两次呼吸，中间动耳朵，后段眨眼），一直叼着草 */
export function idleMainOptions() {
  return Array.from({ length: 32 }, (_, f) => ({
    inhale: Math.floor(f / 8) % 2 === 1,
    blink: f === 20 || f === 21,
    earTwitch: f === 10 || f === 11,
    chewPhase: 0,
  }));
}

/** 8fps：chew 2 秒一轮，草茎每 2 帧摆一次 */
export function idleChewOptions() {
  return Array.from({ length: 16 }, (_, f) => ({
    inhale: f >= 8,
    blink: f === 12 || f === 13,
    chewPhase: Math.floor(f / 2) % 2,
  }));
}

/** 被摸头：6fps，眯眼 + 爱心往上飘，中间动一下耳朵 */
export function pettedOptions() {
  return HEART_PATH.map((_, f) => ({ face: 'happy', chewPhase: 0, heart: f, earTwitch: f === 1 }));
}

/** 打盹：4fps，4 秒一轮；闭眼低头，慢慢呼吸，z 从背上飘起（每轮开头空一拍） */
export function napOptions() {
  return Array.from({ length: 16 }, (_, f) => ({
    blink: true,
    nod: true,
    chewPhase: 0,
    inhale: f >= 8,
    zzz: f < 4 ? null : Math.floor((f - 4) / 3),
  }));
}

/** 待机小动作 · 柚子摇摇：6fps，柚子左右晃两下，眼睛抬起来盯着它 */
export function yuzuWobbleOptions() {
  const shifts = [0, 1, 1, 0, -1, -1, 0, 1, 0, 0];
  return shifts.map((yuzuShift, f) => ({ chewPhase: 0, yuzuShift, eyes: f >= 1 && f <= 8 ? 'up' : undefined }));
}

/**
 * 待机小动作 · 小鸟来访：6fps。从左上方飞来（脸朝右）→ 落在柚子前面的额头上歇一会儿
 * （转回朝左，和水豚同向）→ 往左飞走；水豚抬眼看它
 */
export function birdVisitOptions() {
  const flyIn = [
    { pose: 'wingsUp', at: [-3, -1], faceRight: true },
    { pose: 'wingsDown', at: [-1, -1], faceRight: true },
    { pose: 'wingsUp', at: [1, 0], faceRight: true },
  ];
  const sit = Array.from({ length: 12 }, (_, f) => ({ pose: 'sit', at: [2, 1], faceRight: f < 4 }));
  const flyOff = [
    { pose: 'wingsUp', at: [0, -1] },
    { pose: 'wingsDown', at: [-3, -1] },
  ];
  return [...flyIn, ...sit, ...flyOff, null].map((bird, f) => ({
    chewPhase: 0,
    bird,
    eyes: f >= 3 && f <= 15 ? 'up' : undefined,
    earTwitch: f === 8 || f === 9,
    blink: f === 11,
  }));
}

/**
 * [相对 pets/capybara 的路径, 网格]。headwear 换头顶装扮（默认橙子）；
 * 衣柜格子用的小图 ui/item_<装扮>.png 每套都带着
 */
export function allFrames(model, { headwear = HEADWEAR[0] } = {}) {
  const pose = (name, o) => renderPose(model, name, { ...o, headwear });
  const front = (o) => renderFrontPeek({ ...o, headwear });
  const frames = [['base.png', pose('sit', { chewPhase: 0 })]];
  idleMainOptions().forEach((o, i) => frames.push([`idle/main/${i}.png`, pose('sit', o)]));
  idleChewOptions().forEach((o, i) => frames.push([`idle/chew/${i}.png`, pose('sit', o)]));
  for (let tilt = -2; tilt <= 2; tilt += 1) {
    frames.push([`drag/hold_${tilt}.png`, pose('hold', { face: 'squeeze', tilt })]);
    for (const twinkle of [0, 1]) {
      frames.push([`drag/dizzy_${tilt}_${twinkle}.png`, pose('hold', { face: 'dizzy', tilt, twinkle })]);
    }
  }
  for (const frame of [0, 1]) {
    frames.push([`drag/land_${frame}.png`, pose('sit', { blink: frame === 0, chewPhase: 0, dust: frame })]);
  }
  // 甩晕后落地：坐姿 + 晕眩脸。拎起那套 dizzy_* 用的是 hold 姿势，身体是悬空下垂的，
  // 放到地上会像挂着，所以落地单独一套坐姿帧
  for (const twinkle of [0, 1]) {
    frames.push([`drag/dizzy_grounded_${twinkle}.png`, pose('sit', { face: 'dizzy', twinkle })]);
  }
  pettedOptions().forEach((o, i) => frames.push([`react/petted_${i}.png`, pose('sit', o)]));
  // 被戳不同部位的反应（肚子痒、腿不耐烦、鼻子打喷嚏、背上吓一跳、戳多了生气）
  frames.push(...pokeFrames(headwear, model));
  frames.push(['sleep/doze_0.png', pose('sit', { blink: true, nod: true, chewPhase: 0 })]);
  napOptions().forEach((o, i) => frames.push([`sleep/nap_${i}.png`, pose('sit', o)]));
  frames.push(['sleep/wake_0.png', pose('sit', { chewPhase: 0, bang: true })]);
  yuzuWobbleOptions().forEach((o, i) => frames.push([`idle_act/wobble_${i}.png`, pose('sit', o)]));
  birdVisitOptions().forEach((o, i) => frames.push([`idle_act/bird_${i}.png`, pose('sit', o)]));
  // 发呆时的晒太阳、泡澡（idle-extras.mjs）
  for (const [name, options] of Object.entries(idleExtraOptions())) {
    options.forEach((o, i) => frames.push([`idle_act/${name}_${i}.png`, IDLE_EXTRA_RENDER[name]({ ...o, headwear, model })]));
  }
  // 贴边：平时正面探头；时不时把头转成侧面（就是原来侧身转 90° 那个造型）
  frames.push(['edge/peek_0.png', front({})]);
  frames.push(['edge/peek_1.png', front({ blink: true })]);
  frames.push(['edge/peek_2.png', front({ reach: true })]);
  frames.push(['edge/peek_3.png', front({ flinch: true })]);
  frames.push(['edge/turn_0.png', pose('peek', {})]);
  frames.push(['edge/turn_1.png', pose('peek', { blink: true })]);
  // 设置 / 衣柜窗口标题栏上趴着的那只（正面，爪子压在画布底边）
  frames.push(['ui/bar_peek.png', renderFrontUpright({ headwear })]);
  for (const kind of HEADWEAR) frames.push([`ui/item_${kind}.png`, itemIcon(kind)]);
  // Agent 干活时的正面小场景（读文件、搜索、改代码、跑命令、子 Agent、在想）
  frames.push(...workFrames(headwear, model));
  return frames;
}

/** 素材里按帧重新生成的目录（写之前清空，避免旧帧残留） */
export const GENERATED_DIRECTORIES = ['idle/main', 'idle/chew', 'drag', 'edge', 'react', 'sleep', 'idle_act', 'ui', 'work'];
