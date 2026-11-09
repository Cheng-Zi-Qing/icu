// Agent 状态的三段动作：在等你（举爪招手）、干完了（开心跳）、出错了（歪头冒问号）。
// 都用侧身坐姿，和平时待机一个样子；跳起来的高度由 App 的动画引擎负责（整只往上抛，头顶留白够），
// 画面里只管表情、爪子和小记号。
import { renderPose } from './render.mjs';

/** 坐姿换掉近侧前腿，改成举起来的爪子（画在头之后，盖在胸口和下巴前面） */
function raisedPawPose(sit, paw) {
  const parts = sit.parts.filter((part) => part.id !== 'nearFrontLeg' && part.id !== 'nearPaw');
  return {
    ...sit,
    parts: [
      ...parts,
      { id: 'raisedLeg', label: '举起的前腿', shape: 'capsule', ink: 'body', x1: 10.5, y1: 23.5, x2: paw[0], y2: paw[1], r: 1.2 },
      { id: 'raisedPaw', label: '举起的爪子', shape: 'ellipse', ink: 'dark', cx: paw[0], cy: paw[1] - 0.6, rx: 1.3, ry: 1, rot: 0 },
    ],
  };
}

/** 歪头：头绕自己转一点 */
function tiltedPose(sit, degrees) {
  return { ...sit, head: { ...sit.head, rot: degrees } };
}

const withPose = (model, name, pose) => ({ ...model, poses: { ...model.poses, [name]: pose } });

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
  return {
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
