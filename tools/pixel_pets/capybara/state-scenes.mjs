// Agent 状态的三段动作：在等你（举爪招手）、干完了（开心跳）、出错了（歪头冒问号）；
// 健康提醒的两段动作：该喝水了（捧着杯子喝）、该护眼了（抬头望远处）；
// 派子 Agent：额头上的小鸟叼着信飞出去，过一会儿飞回来（2026-11-11 从正面坐姿改成侧身：正面干坐着光秃秃的不可爱）。
// 都用侧身坐姿，和平时待机一个样子；跳起来的高度由 App 的动画引擎负责（整只往上抛，头顶留白够），
// 画面里只管表情、爪子和小记号。
import { Grid } from './raster.mjs';
import { CANVAS_HEIGHT, renderPose } from './render.mjs';

/** 坐姿换掉近侧前腿，改成举起来的爪子（画在头之后，盖在胸口和下巴前面） */
export function raisedPawPose(sit, paw) {
  const parts = sit.parts.filter((part) => part.id !== 'nearFrontLeg' && part.id !== 'nearPaw');
  return {
    ...sit,
    parts: [
      ...parts,
      // 举的是靠近我们的那只手：从肚皮上方的肩膀起笔、横过肚皮，挡住一部分肚皮（外侧手伸出来就不该看到整个肚皮）
      { id: 'raisedLeg', label: '举起的前腿', shape: 'capsule', ink: 'body', x1: 15, y1: 21.5, x2: paw[0], y2: paw[1], r: 1.3, edge: 'above' },
      { id: 'raisedPaw', label: '举起的爪子', shape: 'ellipse', ink: 'dark', cx: paw[0], cy: paw[1] - 0.6, rx: 1.3, ry: 1, rot: 0 },
    ],
  };
}

/** 歪头：头绕自己转一点 */
export function tiltedPose(sit, degrees) {
  return { ...sit, head: { ...sit.head, rot: degrees } };
}

export const withPose = (model, name, pose) => ({ ...model, poses: { ...model.poses, [name]: pose } });

// 在等你：爪子在下巴前一高一低地招，背上「!」一闪一闪；一直循环到你处理
function waitFrame({ paw, alert, headwear, model }) {
  return renderPose(withPose(model, 'wave', raisedPawPose(model.poses.sit, paw)), 'wave', { headwear, chewPhase: 0, alert });
}

// 干完了：先蹲一下（低头，橙子还在原处），眯眼笑着被 App 抛起来；落地时身体一沉、橙子晚一拍才落（看起来跳得更高），
// 再冒两颗小星星。只放一遍
function doneFrame({ headwear, model, ...options }) {
  return renderPose(model, 'sit', { headwear, chewPhase: 0, ...options });
}

// 出错了：歪头、抬眼，问号从背上方冒出来停住，眨一下眼。只放一遍
function failFrame({ tilt, headwear, model, ...options }) {
  return renderPose(withPose(model, 'puzzled', tiltedPose(model.poses.sit, tilt)), 'puzzled', { headwear, chewPhase: 0, ...options });
}

/** 水杯（左上角坐标）：4×4 一杯水，自己描边；tipped 时杯口朝嘴歪一格 */
function cupLayer(width, [x, y], tipped) {
  const rows = tipped ? [[1, 4], [0, 3], [0, 3], [0, 2]] : [[0, 3], [0, 3], [0, 3], [1, 2]];
  const water = rows.flatMap(([from, to], dy) => Array.from({ length: to - from + 1 }, (_, i) => [x + from + i, y + dy]));
  return Grid.empty(width, CANVAS_HEIGHT)
    .dots('sweat', water)
    .outlined()
    .dots('white', water.filter(([, py]) => py === y));
}

// 该喝水了：爪子捧着杯子，举到嘴边闭眼喝两口，放下来眯眼笑。循环到你点了卡片
function drinkFrame({ paw, cup, tipped = false, headwear, model, ...options }) {
  const body = renderPose(withPose(model, 'drink', raisedPawPose(model.poses.sit, paw)), 'drink', { headwear, chewPhase: 0, ...options });
  return body.overlaid(cupLayer(body.width, cup, tipped));
}

// 该护眼了：抬头望着远处，眼睛往上看，慢慢眨一下。循环到你点了卡片
function lookAwayFrame({ tilt, headwear, model, ...options }) {
  return renderPose(withPose(model, 'gaze', tiltedPose(model.poses.sit, tilt)), 'gaze', { headwear, chewPhase: 0, ...options });
}

/** 小鸟叼着的信：3×2 白信封自己描边，红点封口；画在小鸟脚下 */
function letterLayer(width, [x, y]) {
  return Grid.empty(width, CANVAS_HEIGHT)
    .dots('white', [[x, y], [x + 1, y], [x + 2, y], [x, y + 1], [x + 1, y + 1], [x + 2, y + 1]])
    .outlined()
    .dots('band', [[x + 1, y]]);
}

// 派子 Agent：小鸟歇在额头上，水豚点一下头「去吧」，小鸟叼着信往左上飞走；水豚抬眼目送，
// 嚼着草等一会儿，小鸟从左边飞回来落回额头，水豚眯眼笑。循环到子 Agent 干完
function delegateFrame({ bird, letter = false, headwear, model, ...options }) {
  const body = renderPose(model, 'sit', { headwear, chewPhase: 0, ...options, bird });
  return letter && bird ? body.overlaid(letterLayer(body.width, [bird.at[0] + 1, bird.at[1] + 4])) : body;
}

/**
 * 场景定义（和干活小场景同一份 manifest）。写成函数：被 render.mjs 间接引用时这里可能还没初始化完。
 * `once`: 只放一遍，放完 App 回到平时的画面；`hop`: App 在第几拍把整只往上抛几格、抛多久
 */
export function stateSceneDefinitions() {
  // 关键帧参数写在函数里：从这个文件进入时，front-work.mjs 会在这里的顶层常量初始化之前就来调它
  const waitKeys = [
    { paw: [3.5, 22], alert: false },
    { paw: [3, 19.5], alert: true },
  ];
  const doneKeys = [
    { face: 'happy', nod: true, yuzuLift: 1 },
    { face: 'happy' },
    { face: 'happy', nod: true, yuzuLift: 1, dust: 0 },
    { face: 'happy', sparkle: 0 },
    { face: 'happy', sparkle: 1 },
  ];
  const failKeys = [
    { tilt: 10, eyes: 'up' },
    { tilt: 16, eyes: 'up', question: 0 },
    { tilt: 16, eyes: 'up', question: 1 },
    { tilt: 16, blink: true, question: 1 },
  ];
  const drinkKeys = [
    { paw: [4, 22.5], cup: [1, 18] },
    { paw: [4, 19.5], cup: [0, 14], tipped: true, blink: true },
    { paw: [4, 19.5], cup: [0, 14], tipped: true, blink: true, inhale: true },
    { paw: [4, 22.5], cup: [1, 18], face: 'happy' },
  ];
  // 头的角度正数是抬头（鼻子朝上），负数是低头
  const lookAwayKeys = [
    { tilt: 0 },
    { tilt: 12, eyes: 'up' },
    { tilt: 12, eyes: 'up', earTwitch: true },
    { tilt: 12, blink: true },
  ];
  // 小鸟的位置和待机「小鸟来访」同一套（额头上 [2, 1]），从左上方进出
  // 点头时头低一格，歇在额头上的小鸟跟着低一格
  const perched = (faceRight, nod = false) => ({ pose: 'sit', at: [2, nod ? 2 : 1], faceRight });
  const delegateKeys = [
    { bird: perched(false), eyes: 'up' },
    { bird: perched(false, true), eyes: 'up', nod: true },
    { bird: { pose: 'wingsUp', at: [0, -1] }, letter: true, eyes: 'up' },
    { bird: { pose: 'wingsDown', at: [-2, -1] }, letter: true, eyes: 'up' },
    { eyes: 'up' },
    { chewPhase: 0 },
    { chewPhase: 1, blink: true },
    { bird: { pose: 'wingsUp', at: [-3, -1], faceRight: true }, eyes: 'up' },
    { bird: { pose: 'wingsDown', at: [-1, 0], faceRight: true }, eyes: 'up' },
    { bird: perched(true), face: 'happy' },
  ];
  return {
    delegate: { render: delegateFrame, keys: delegateKeys, order: [0, 0, 1, 1, 2, 3, 4, 4, 5, 6, 5, 5, 6, 5, 7, 8, 9, 9, 9, 0] },
    drink: { render: drinkFrame, keys: drinkKeys, order: [0, 0, 1, 2, 1, 2, 1, 0, 3, 3, 3, 0] },
    look_away: { render: lookAwayFrame, keys: lookAwayKeys, order: [0, 1, 1, 1, 2, 1, 1, 3, 1, 1, 1, 1] },
    wait: { render: waitFrame, keys: waitKeys, order: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1] },
    done: {
      render: doneFrame,
      keys: doneKeys,
      order: [0, 1, 1, 1, 2, 3, 3, 4, 4, 4, 4, 4],
      fps: 8,
      once: true,
      hop: { atBeat: 1, pixels: 3, beats: 3 },
    },
    fail: { render: failFrame, keys: failKeys, order: [0, 1, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2], fps: 4, once: true },
  };
}

export const STATE_SCENES = ['wait', 'done', 'fail'];
/** 侧身演的干活场景（其余干活场景是正脸从道具后面探出头） */
export const SIDE_WORK_SCENES = ['delegate'];
export const REMINDER_SCENES = ['drink', 'look_away'];
