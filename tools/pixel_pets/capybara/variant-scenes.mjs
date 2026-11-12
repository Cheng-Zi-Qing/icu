// 同一种状态的几种演法（2026-11-11 用户定：字跟着画面走，抽到哪段动画就说那段的话）。
// variantOf：是哪个场景的另一种演法（App 开演时在这几种里抽一种）；side：侧身演（可以转头看鼠标）。
// 都用侧面模型；比 32 格宽的场景（趴着的）App 会把窗口放宽，水豚还是一样大。
//
//   在想    think_dots 头顶三个小点绕圈转 / think_bulb 停嘴眯眼，灯泡由暗到亮「叮」
//   跑命令  eat（吃东西，原有）/ surf 趴滑板冲浪 / button 拍大红按钮
//   搜索    search（追球，原有）/ rummage 翻箱倒柜
//   读文件  read（翻书，原有）/ paper 叼纸啃文档
//   出错了  fail（歪头冒问号，原有）/ fall 摔一跤，四脚朝天
//   休息    rest_fish 趴着钓鱼（休息时的场景，不是 Agent 的）
import { renderPose } from './render.mjs';
import { raisedPawPose, withPose } from './state-scenes.mjs';
import { block, line, placed, plain, prop, stacked } from './scene-props.mjs';

const ORANGE = 'orange';

// ---------------- 在想 ----------------

/** 头顶绕圈的小点：一圈 8 个位置，每拍转两格，三个点隔开 */
const THINK_RING = [[17, 2], [19, 0], [22, 0], [25, 0], [27, 2], [25, 4], [22, 4], [19, 4]];
const thinkDots = (turn) => prop(32, ['white', [0, 3, 6].map((i) => THINK_RING[(i + turn * 2) % THINK_RING.length])]);

function thinkDotsFrame({ turn, chewPhase, headwear, model }) {
  return renderPose(model, 'sit', { headwear, chewPhase, eyes: 'up' }).overlaid(thinkDots(turn));
}

/** 灯泡：dim 是没亮（灰），lit 亮了带一圈光 */
function bulb(lit) {
  const glass = [...block(20, 1, 5, 4), ...block(21, 0, 3, 1), ...block(21, 5, 3, 1)];
  const body = prop(32, [lit ? 'star' : 'dust', glass], [['white', lit ? [[21, 1], [21, 2]] : []]])
    .overlaid(prop(32, ['metal', block(21, 6, 3, 2)], [['metalDark', [[21, 7], [23, 7]]]]));
  return lit ? body.overlaid(plain(32, [['star', [[18, 1], [27, 1], [18, 4], [27, 4]]]])) : body;
}

function thinkBulbFrame({ stage, headwear, model }) {
  if (stage === 'dots') return thinkDotsFrame({ turn: 0, chewPhase: 0, headwear, model });
  const face = stage === 'dim' ? { face: 'squeeze', squeezeSweat: false } : { face: 'happy' };
  return renderPose(model, 'sit', { headwear, chewPhase: 0, ...face }).overlaid(bulb(stage !== 'dim'));
}

// ---------------- 跑命令：拍大红按钮 ----------------

function button(pressed) {
  const top = pressed ? 27 : 25;
  const cap = block(2, top, 5, pressed ? 1 : 3);
  return prop(32, ['metal', [...block(1, 28, 7, 4), ...cap]], [
    ['metalDark', block(1, 31, 7, 1)],
    ['band', cap],
    ['white', pressed ? [] : [[3, 25]]],
  ]);
}

const SPARKS = [[[0, 22], [1, 21], [8, 22], [7, 21], [4, 20]], [[0, 20], [2, 19], [9, 20], [8, 19], [4, 18]]];

function buttonFrame({ paw, pressed, spark, face, headwear, model }) {
  const body = renderPose(withPose(model, 'slap', raisedPawPose(model.poses.sit, paw)), 'slap', { headwear, grass: false, ...face });
  const withButton = body.overlaid(button(pressed));
  return spark == null ? withButton : withButton.overlaid(plain(32, [['star', SPARKS[spark]]]));
}

// ---------------- 跑命令：趴滑板冲浪 ----------------

const SURF_WIDTH = 48;

function skateboard(lift) {
  const deck = prop(SURF_WIDTH, ['strawShade', block(2, 28 - lift, 40, 1)]);
  const wheels = prop(SURF_WIDTH, ['dark', [...block(6, 29 - lift, 2, 2), ...block(35, 29 - lift, 2, 2)]]);
  return deck.overlaid(wheels);
}

/** 身后（右边）的速度线，每拍错开一格 */
const speedLines = (shift) => plain(SURF_WIDTH, [['white', [
  ...line([43 + shift, 15], [45 + shift, 15]),
  ...line([44 - shift, 20], [47 - shift, 20]),
  ...line([43 + shift, 25], [46 + shift, 25]),
]]]);

function surfFrame({ lift, shift, chewPhase, headwear, model }) {
  // 趴姿整只抬高 3 格站到板子上；嘴里的草被风吹向后
  const rider = placed(renderPose(model, 'lie', { headwear, face: 'happy', chewPhase, grassOffset: [1, -1] }), SURF_WIDTH).translated(0, -3 - lift);
  // 板子在身子底下：先画板子，水豚压在上面
  return stacked(skateboard(lift), rider, speedLines(shift));
}

// ---------------- 搜索：翻箱倒柜 ----------------

const RUMMAGE_WIDTH = 40;
const RUMMAGE_SHIFT = 8;

function cardboardBox() {
  const box = prop(RUMMAGE_WIDTH, ['straw', block(1, 21, 14, 11)], [
    ['strawShade', [...block(1, 21, 14, 1), ...block(7, 25, 2, 6)]],
  ]);
  const flaps = prop(RUMMAGE_WIDTH, ['straw', [...line([0, 18], [2, 20]), ...line([16, 18], [14, 20])]]);
  return box.overlaid(flaps);
}

/** 从箱子里飞出来的东西：纸、袜子、小星星，每拍飞高一点 */
const FLYING = [
  [],
  [['white', block(3, 15, 3, 3)]],
  [['white', block(2, 10, 3, 3)], ['blush', [...block(7, 14, 2, 2), [9, 15]]]],
  [['white', block(1, 5, 3, 3)], ['blush', [...block(6, 8, 2, 2), [8, 9]]], ['star', [[3, 14], [2, 15], [3, 15], [4, 15], [3, 16]]]],
];

function rummageFrame({ throwing, face, headwear, model }) {
  // 近侧前爪伸进箱子里（举起的前腿横过胸口，爪子藏在箱子后面）
  const body = renderPose(withPose(model, 'dig', raisedPawPose(model.poses.sit, [3, 23])), 'dig', { headwear, grass: false, ...face });
  const items = FLYING[throwing].map(([ink, points]) => prop(RUMMAGE_WIDTH, [ink, points]));
  return stacked(placed(body, RUMMAGE_WIDTH, RUMMAGE_SHIFT), cardboardBox(), ...items);
}

// ---------------- 读文件：叼纸啃文档 ----------------

function paperSheet(bitten) {
  const sheet = block(0, 15, 5, 7).filter(([x, y]) => !(bitten && x >= 3 && y <= 16));
  return prop(32, ['white', sheet], [['dust', [[1, 17], [2, 17], [3, 17], [1, 19], [2, 19], [1, 21], [2, 21], [3, 21]]]]);
}

function paperFrame({ bitten, chewPhase, crumbs, eyes, headwear, model }) {
  const body = renderPose(model, 'sit', { headwear, grass: false, chewPhase, eyes });
  const withPaper = body.overlaid(paperSheet(bitten));
  return crumbs ? withPaper.overlaid(prop(32, ['white', [[6, 26], [3, 29], [8, 29]]])) : withPaper;
}

// ---------------- 出错了：摔一跤 ----------------

const FALL_WIDTH = 44;
/** 坐姿放在 44 格画布中间 */
const FALL_SIT_SHIFT = 6;

/** 往前一绊：上半身往左（脸那边）栽，越往上挪得越多 */
function stumbled(grid, pixels) {
  const pivot = 26;
  return grid.sampled(grid.width, grid.height, (x, y) => [x + Math.round((pixels * Math.max(0, pivot - y)) / pivot), y]);
}

/** 翻身四脚朝天：趴姿加上浅色肚皮再上下翻（翻过来朝上的是肚皮，2026-11-11 用户） */
function bellyUp(model, headwear, twinkle, kick) {
  const lie = model.poses.lie;
  const tummy = { id: 'tummy', label: '肚皮', shape: 'ellipse', ink: 'light', cx: 25, cy: 29, rx: 9.5, ry: 2.6, rot: 0, onlyOver: 'body' };
  const belly = { ...lie, parts: lie.parts.flatMap((part) => (part.id === 'shoulder' ? [part, tummy] : [part])) };
  const flipped = renderPose(withPose(model, 'belly_up', belly), 'belly_up', { face: 'dizzy', twinkle, props: false })
    .flippedVertically()
    .translated(0, 12);
  // 四只脚从朝天的肚皮上蹬出来（前脚在肩膀那段、后脚在屁股那段，不能长在头上面，不然像耳朵）
  const legs = [18, 22, 32, 36].map((x, i) => {
    const y = 8 + ((i + kick) % 2);
    return prop(FALL_WIDTH, ['body', block(x, y, 2, 5)], [['dark', block(x, y, 2, 1)]], 'leg');
  });
  const rolled = headwear === ORANGE ? [prop(FALL_WIDTH, ['orange', [...block(37, 28, 3, 3), [38, 27]]], [['grass', [[39, 26]]], ['white', [[37, 28]]]])] : [];
  const marks = plain(FALL_WIDTH, [['star', twinkle ? [[1, 19], [5, 18], [3, 22]] : [[3, 22], [1, 19], [5, 17]]], ['dust', [[1, 30], [2, 29], [42, 31]]]]);
  return stacked(legs.reduce((grid, leg) => leg.overlaid(grid), flipped), ...rolled, marks);
}

function fallFrame({ stage, twinkle = 0, kick = 0, headwear, model }) {
  if (stage === 'stumble') {
    const sit = renderPose(model, 'sit', { headwear, face: 'squeeze', mouth: 'open', grass: false });
    return stumbled(placed(sit, FALL_WIDTH, FALL_SIT_SHIFT), 3);
  }
  if (stage === 'flat') return bellyUp(model, headwear, twinkle, kick);
  // 爬起来坐好，拍拍土
  return placed(renderPose(model, 'sit', { headwear, face: 'flat', dust: 0, chewPhase: 0 }), FALL_WIDTH, FALL_SIT_SHIFT);
}

// ---------------- 休息：趴着钓鱼 ----------------

const FISH_WIDTH = 50;
const FISH_SHIFT = 6;

/** 水和鱼竿在水豚后面（竿子从身子后面伸出去） */
function waterAndRod() {
  const water = plain(FISH_WIDTH, [['sweat', block(0, 30, 9, 2)], ['birdWing', [[2, 30], [3, 30], [7, 30]]]]);
  return water.overlaid(plain(FISH_WIDTH, [['strawShade', line([13, 29], [3, 9])]]));
}

/** 线、浮漂、溅起的水花、钓上来的鱼在最前面 */
function fishingLine(dip, catching) {
  if (catching) {
    // 钓起来一条小鱼：线收短，鱼挂在半空
    const fish = prop(FISH_WIDTH, ['sweat', [...block(2, 15, 3, 2), [5, 15], [5, 16], [1, 15]]], [['outline', [[2, 15]]]]);
    return plain(FISH_WIDTH, [['white', line([3, 10], [3, 14])]]).overlaid(fish);
  }
  const string = plain(FISH_WIDTH, [['white', line([3, 10], [3, 26 + dip])]]);
  const bobber = prop(FISH_WIDTH, ['band', block(2, 27 + dip, 3, 2)], [['white', block(2, 27 + dip, 3, 1)]]);
  const splash = dip >= 2 ? [plain(FISH_WIDTH, [['white', [[0, 29], [6, 29], [1, 28], [5, 28]]]])] : [];
  return stacked(string, bobber, ...splash);
}

function fishFrame({ dip = 0, catching = false, face, headwear, model }) {
  const body = placed(renderPose(model, 'lie', { headwear, grass: false, ...face }), FISH_WIDTH, FISH_SHIFT);
  return stacked(waterAndRod(), body, fishingLine(dip, catching));
}

// ---------------- 场景表 ----------------

/** 和 front-work.mjs 的 SCENE_DEFINITIONS 同一格式，多了 variantOf / side */
export function variantSceneDefinitions() {
  return {
    think_dots: {
      render: thinkDotsFrame,
      keys: [0, 1, 2, 3].map((turn) => ({ turn, chewPhase: turn % 2 })),
      order: [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3],
      variantOf: 'think',
      side: true,
    },
    think_bulb: {
      render: thinkBulbFrame,
      keys: [{ stage: 'dots' }, { stage: 'dim' }, { stage: 'lit' }],
      order: [0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 0, 0],
      variantOf: 'think',
      side: true,
    },
    button: {
      render: buttonFrame,
      keys: [
        { paw: [5, 19], pressed: false, face: { eyes: 'up' } },
        { paw: [5, 24], pressed: true, spark: 0, face: { face: 'squeeze', squeezeSweat: false, mouth: 'open' } },
        { paw: [5, 24], pressed: true, spark: 1, face: { face: 'happy' } },
        { paw: [5, 19], pressed: false, face: { face: 'happy' } },
      ],
      order: [0, 0, 0, 1, 2, 2, 3, 3, 0, 0, 0, 0],
      variantOf: 'eat',
      side: true,
    },
    surf: {
      render: surfFrame,
      keys: [{ lift: 0, shift: 0, chewPhase: 0 }, { lift: 1, shift: 1, chewPhase: 1 }],
      order: [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1],
      variantOf: 'eat',
      side: true,
    },
    rummage: {
      render: rummageFrame,
      keys: [0, 1, 2, 3].map((throwing) => ({ throwing, face: throwing % 2 ? { face: 'happy' } : { face: 'squeeze', squeezeSweat: false } })),
      order: [0, 1, 2, 3, 0, 0, 1, 2, 3, 0, 0, 0],
      variantOf: 'search',
      side: true,
    },
    paper: {
      render: paperFrame,
      keys: [
        { bitten: false, chewPhase: 0 },
        { bitten: false, chewPhase: 1 },
        { bitten: true, chewPhase: 0 },
        { bitten: true, chewPhase: 1, crumbs: true },
        { bitten: true, chewPhase: 0, crumbs: true, eyes: 'up' },
      ],
      order: [0, 1, 0, 1, 2, 3, 2, 3, 4, 4, 4, 4],
      variantOf: 'read',
      side: true,
    },
    fall: {
      render: fallFrame,
      keys: [
        { stage: 'stumble' },
        { stage: 'flat', twinkle: 0, kick: 0 },
        { stage: 'flat', twinkle: 1, kick: 1 },
        { stage: 'up' },
      ],
      order: [0, 0, 1, 2, 1, 2, 1, 2, 3, 3, 3],
      fps: 4,
      once: true,
      variantOf: 'fail',
      side: true,
    },
    rest_fish: {
      render: fishFrame,
      keys: [
        { dip: 0, face: { face: 'flat' } },
        { dip: 1, face: { face: 'flat' } },
        { dip: 2, face: { bang: true, eyes: 'up' } },
        { catching: true, face: { face: 'happy' } },
      ],
      order: [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 2, 3, 3, 3, 3],
      variantOf: 'rest',
      side: true,
    },
  };
}
