// 被戳的反应：戳哪儿就有哪儿的样子。都用侧身坐姿（脸朝左），App 按点到的部位挑一段放一遍：
//
//   肚子 → tickle   怕痒：眯眼张嘴笑，爪子捂肚子，左右扭，身边冒「痒」的小线
//   腿脚 → annoyed  不耐烦：斜眼，前爪一下一下拍地，扬起灰，头顶冒青筋，鼻子哼一声
//   鼻子 → sneeze   打喷嚏：鼻子一抽、仰头吸气，「阿嚏」往前一低头，嘴里的草喷飞了，再叼回来
//   背上 → startled 吓一跳：头顶「!」、眼睛瞪圆（App 同时把它抛起两格），冒一滴冷汗，缓过来
//   戳太多 → grumpy  生气：闭眼仰头「哼」，青筋 + 鼻孔喷气；App 让它扭过身去不理你一会儿
//
// 文件名 react/<反应>_<帧>.png，每帧一张（停顿也是重复的帧），App 按固定帧率从头放到尾。
import { Grid } from './raster.mjs';
import { CANVAS_HEIGHT, renderPose } from './render.mjs';
import { raisedPawPose, tiltedPose, withPose } from './state-scenes.mjs';

// ---------- 小记号（各自描边后叠上去，坐标是左上角） ----------

/** 青筋（💢）：四个拐角，红色 */
const VEIN = [[0, 1], [1, 0], [1, 1], [3, 0], [3, 1], [4, 1], [0, 3], [1, 3], [1, 4], [3, 3], [3, 4], [4, 3]];
const VEIN_AT = [25, 2];
/** 怕痒的小线：肚子前面一组、背上方一组，两拍换位置 */
const GIGGLE = [
  [[3, 20], [4, 21], [2, 24], [3, 24], [27, 9], [28, 8]],
  [[2, 21], [3, 22], [3, 25], [4, 25], [28, 10], [29, 9]],
];
/** 喷嚏喷出来的水星（鼻子低下来以后在它前下方） */
const SPRAY = [
  [[1, 17], [0, 19], [2, 19], [1, 21]],
  [[0, 18], [2, 17], [0, 21], [3, 20], [1, 23]],
];
/** 「哼」：仰着头时鼻孔喷出的一小团气（鼻子朝左上），先小后大往上飘 */
const PUFF = [
  [[1, 7], [2, 7], [2, 6]],
  [[1, 4], [2, 4], [1, 5], [2, 5], [3, 4]],
];
/** 冷汗（背上方，和被拎起时那滴同一处） */
const SWEAT_DROP = [[25, 9], [24, 10], [25, 10], [26, 10], [25, 11]];
/** 拍地扬起的灰：前爪左边 */
const STOMP_DUST = [
  [[7, 31], [8, 30], [6, 30]],
  [[5, 30], [6, 31], [7, 29], [4, 31], [8, 28]],
];

const layer = (ink, points) => Grid.empty(32, CANVAS_HEIGHT).dots(ink, points).outlined();
const plain = (ink, points) => Grid.empty(32, CANVAS_HEIGHT).dots(ink, points);
const at = ([x0, y0], points) => points.map(([dx, dy]) => [x0 + dx, y0 + dy]);

/** 帧上叠的小记号：key 是选项名，值是怎么画 */
const MARKS = {
  vein: () => layer('band', at(VEIN_AT, VEIN)),
  giggle: (i) => plain('star', GIGGLE[i]),
  spray: (i) => plain('sweat', SPRAY[i]),
  puff: (i) => layer('white', PUFF[i]),
  sweat: () => layer('sweat', SWEAT_DROP),
  stompDust: (i) => plain('dust', STOMP_DUST[i]),
};

// ---------- 身体 ----------

/** 近侧前爪抬起几格（不耐烦地拍地）：脚底下露出一道缝 */
function liftedFrontPawPose(sit, pixels) {
  const lift = (part) => (part.id === 'nearFrontLeg' || part.id === 'nearPaw' ? { ...part, cy: part.cy - pixels } : part);
  return { ...sit, parts: sit.parts.map(lift) };
}

/** 这一帧的身体：歪头（正数抬头）、举爪捂肚子、抬前爪，按需叠起来 */
function bodyPose(sit, { tilt = 0, paw = null, pawUp = 0 }) {
  const withPaw = paw ? raisedPawPose(sit, paw) : sit;
  const withTap = pawUp ? liftedFrontPawPose(withPaw, pawUp) : withPaw;
  return tilt ? tiltedPose(withTap, tilt) : withTap;
}

/**
 * 笑得往后仰：屁股最宽那一行以下不动，越往上越往右挪，头顶挪 `pixels` 格。
 * 只往右、只挪上半身：往左会把鼻子和嘴里的草挤出画布，下半身往右会把屁股挤出画布
 */
const LEAN_PIVOT_ROW = 22;

function leaned(grid, pixels) {
  if (!pixels) return grid;
  const cells = grid.cells.map((_, i) => {
    const x = i % grid.width;
    const y = Math.floor(i / grid.width);
    return grid.get(x - Math.round((pixels * Math.max(0, LEAN_PIVOT_ROW - y)) / LEAN_PIVOT_ROW), y);
  });
  return new Grid(grid.width, grid.height, cells);
}

function pokeFrame(model, headwear, { tilt, paw, pawUp, lean, ...options }) {
  const markKeys = Object.keys(MARKS).filter((key) => options[key] !== undefined && options[key] !== false);
  const faceOptions = Object.fromEntries(Object.entries(options).filter(([key]) => !(key in MARKS)));
  const pose = bodyPose(model.poses.sit, { tilt, paw, pawUp });
  const body = leaned(renderPose(withPose(model, 'poked', pose), 'poked', { chewPhase: 0, headwear, ...faceOptions }), lean);
  return markKeys.reduce((grid, key) => grid.overlaid(MARKS[key](options[key] === true ? 0 : options[key])), body);
}

// ---------- 关键帧 ----------

/** 草喷到画布外面 = 嘴里没草了 */
const GRASS_GONE = [-40, 0];

/**
 * 每段反应的关键帧和播放顺序。写成函数：从 render.mjs 进来时这个模块还没初始化完。
 * fps 和 order.length 决定一段有多长；App（PetActionClip）里的帧数、帧率要和这里一致，
 * 见 apps/macos-shell 的 testPokeReactionFramesExistInTheRepoAssets。
 */
export function pokeReactionDefinitions() {
  // tilt：头的角度，正数抬头、负数低头
  const tickle = {
    fps: 8,
    keys: [
      { face: 'happy', mouth: 'open', tilt: 8, lean: 2, inhale: true, paw: [8, 23.5], giggle: 0 },
      { face: 'happy', mouth: 'open', tilt: -4, paw: [8.5, 22], giggle: 1 },
      { face: 'happy', tilt: 4, lean: 1, paw: [8.5, 23] },
      { face: 'happy' },
    ],
    order: [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 2, 2, 3, 3],
  };
  const annoyed = {
    fps: 8,
    keys: [
      { face: 'flat' },
      { face: 'flat', pawUp: 3 },
      { face: 'flat', vein: true, stompDust: 0 },
      { face: 'flat', vein: true, pawUp: 3 },
      { face: 'flat', vein: true, stompDust: 1 },
      { face: 'flat', vein: true },
      { face: 'flat', vein: true, tilt: 6, puff: 0 },
      { face: 'flat', vein: true, tilt: 6, puff: 1 },
    ],
    order: [0, 0, 1, 2, 3, 4, 1, 2, 5, 6, 7, 5, 0, 0],
  };
  const sneeze = {
    fps: 8,
    keys: [
      { earTwitch: true },
      { tilt: 6, blink: true },
      { tilt: 12, blink: true, inhale: true, mouth: 'open' },
      { tilt: -9, face: 'squeeze', squeezeSweat: false, mouth: 'open', spray: 0, grassOffset: [-3, 2] },
      { tilt: -9, blink: true, spray: 1, grassOffset: GRASS_GONE },
      { blink: true, grassOffset: GRASS_GONE },
      { grassOffset: GRASS_GONE, earTwitch: true },
      { blink: true },
      {},
    ],
    order: [0, 1, 2, 2, 2, 3, 4, 4, 5, 6, 6, 6, 7, 8, 8],
  };
  const startled = {
    fps: 8,
    keys: [
      { bang: true, eyes: 'up', tilt: 8, earTwitch: true },
      { bang: true, eyes: 'up', tilt: 8 },
      { eyes: 'up', tilt: 4, sweat: true },
      { blink: true, sweat: true },
      { sweat: true },
      {},
    ],
    order: [0, 1, 0, 1, 1, 1, 2, 2, 3, 4, 4, 5],
  };
  const grumpy = {
    fps: 6,
    keys: [
      { blink: true, tilt: 6 },
      { blink: true, tilt: 14, vein: true },
      { blink: true, tilt: 14, vein: true, puff: 0 },
      { blink: true, tilt: 14, vein: true, puff: 1 },
      // 偷偷斜眼瞄你一下，再把头扬回去
      { face: 'flat', tilt: 8, vein: true },
    ],
    order: [0, 1, 1, 2, 3, 1, 1, 1, 4, 4, 1, 2, 3, 1, 1, 1, 0, 0],
  };
  return { tickle, annoyed, sneeze, startled, grumpy };
}

export const POKE_REACTIONS = ['tickle', 'annoyed', 'sneeze', 'startled', 'grumpy'];

/** 一段反应按播放顺序展开成逐帧网格 */
export function pokeReactionFrames(name, model, headwear) {
  const definition = pokeReactionDefinitions()[name];
  if (!definition) throw new Error(`unknown poke reaction: ${name}`);
  const keyFrames = definition.keys.map((key) => pokeFrame(model, headwear, key));
  return definition.order.map((index) => keyFrames[index]);
}

/** [react/<反应>_<帧>.png, 网格]，每套装扮都带一份 */
export function pokeFrames(headwear, model) {
  return POKE_REACTIONS.flatMap((name) =>
    pokeReactionFrames(name, model, headwear).map((grid, i) => [`react/${name}_${i}.png`, grid]));
}
