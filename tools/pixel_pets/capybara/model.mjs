// 水豚参数化模型：一个共用的头 + 每个姿势各自的身体部件。
//
// - 头（含眼耳口鼻、脸颊、柚子、草）在所有姿势里完全相同，只改位置 / 角度，
//   保证比例一致。
// - 「贴边探头」：「趴着」逆时针转 90°（头朝上），只露出柚子和半个脑袋，其余藏在屏幕边（画布右边）外。
// - 坐标单位是像素，x 向右、y 向下；头的局部坐标原点在头中心、脸朝左。

export const PALETTE = {
  outline: '#2F1C12', body: '#B0714A', shade: '#8A5236', light: '#CB8F62',
  dark: '#4A2E22', muzzle: '#99603F', white: '#FFFFFF', blush: '#E58D86',
  grass: '#6DAA45', sweat: '#8CC8F0', star: '#F4BC2C', dust: '#D8D0C2',
  // 头顶的橙子（2026-11-08 从柚子黄改成橙色）
  orange: '#F08A24',
  // 来访的小鸟（水豚身上常停着小鸟）
  bird: '#7FB2D9', birdWing: '#4F7FAE',
};

export const POSE_LABELS = {
  sit: '坐姿（待机）',
  lie: '趴着（参考）',
  peek: '贴边探头',
  hold: '被拎起',
};

const ell = (id, label, ink, cx, cy, rx, ry, extra = {}) => ({ id, label, shape: 'ellipse', ink, cx, cy, rx, ry, rot: 0, ...extra });
const box = (id, label, ink, cx, cy, w, h, r, extra = {}) => ({ id, label, shape: 'rbox', ink, cx, cy, w, h, r, rot: 0, ...extra });
const cap = (id, label, ink, x1, y1, x2, y2, r, extra = {}) => ({ id, label, shape: 'capsule', ink, x1, y1, x2, y2, r, ...extra });
const HEAD = { id: 'head', label: '头（整体）', shape: 'head' };

export const DEFAULT_MODEL = Object.freeze({
  version: 1,
  head: {
    parts: [
      ell('ear', '耳朵', 'shade', 6.3, -7.1, 1.8, 1.6),
      box('skull', '头骨', 'body', 0, -1.5, 16, 10, 3),
      box('snout', '鼻头', 'body', -5.5, 0, 5, 8, 2.2),
      ell('jaw', '下颌', 'body', 0, 2.6, 5.5, 3.2),
      ell('cheek', '脸颊', 'body', -0.5, 2.9, 4.4, 3.4, { edge: 'below' }),
      box('muzzleTint', '口鼻深色', 'muzzle', -5, 0, 5, 9, 2, { onlyOver: 'body' }),
      ell('nosePad', '鼻垫', 'dark', -6, -2, 1.45, 1.45, { onlyOver: 'muzzle' }),
    ],
    marks: {
      eye: { x: 2, y: -4 },
      blush: { x: 0, y: 2 },
      nostril: { x: -6, y: -2 },
      mouth: { x: -6, y: 2 },
      highlight: { x: -2, y: -5 },
      earInner: { x: 7, y: -7 },
      yuzu: { x: 0, y: -9 },
      grass: { x: -7, y: 3 },
    },
  },
  poses: {
    sit: {
      width: 32,
      head: { x: 9.5, y: 12.5, rot: 0, scale: 1 },
      yuzu: true,
      parts: [
        box('farFrontLeg', '远侧前腿', 'shade', 14, 27, 2, 8, 0),
        box('nearFrontLeg', '近侧前腿', 'body', 11, 27, 2, 8, 0),
        ell('bellyShade', '腿间阴影', 'shade', 16, 26.5, 3, 3.6),
        box('hindFoot', '后脚', 'shade', 17.5, 30, 5, 2, 0),
        ell('hips', '臀部', 'body', 22.6, 22.6, 8, 7.6),
        ell('chest', '胸口', 'body', 14.6, 18.5, 7, 6, { breathe: true }),
        ell('back', '背', 'body', 19.5, 15.5, 6, 4.6),
        ell('nape', '后颈', 'body', 18.2, 10.6, 3.6, 5),
        ell('belly', '圆肚子', 'body', 15.2, 23, 5.6, 4.6),
        ell('tummy', '浅色肚皮', 'light', 14, 23.8, 3.4, 3.2, { onlyOver: 'body' }),
        HEAD,
        box('nearPaw', '近侧前爪', 'dark', 11, 30, 2, 2, 0, { onlyOver: 'body' }),
        box('farPaw', '远侧前爪', 'dark', 14, 30.5, 2, 1, 0, { onlyOver: 'shade' }),
        box('hindPaw', '后爪', 'dark', 17, 30, 4, 2, 0, { onlyOver: 'shade' }),
      ],
      marks: [
        { ink: 'shade', points: [[17, 25], [18, 24], [19, 23], [20, 23], [21, 23], [22, 23], [23, 24], [24, 25]] },
        { ink: 'light', points: [[20, 12], [21, 12], [22, 13], [23, 13]] },
      ],
    },
    lie: {
      width: 44,
      head: { x: 9, y: 20.5, rot: 6, scale: 1 },
      yuzu: true,
      parts: [
        // 照片 014 / 063 / g15：肚子贴地，身体又长又低，臀部略高；两条前腿平伸在下巴下面
        cap('farFrontLeg', '远侧前腿（平伸）', 'shade', 15, 28, 5, 28.2, 1, { reach: true }),
        ell('barrel', '身体', 'body', 25, 24, 12, 6.8),
        ell('rump', '臀部', 'body', 32.5, 22.6, 7, 7.8),
        ell('nape', '后颈（接头和背）', 'body', 18, 19.5, 6, 5),
        ell('shoulder', '肩膀', 'body', 16, 24, 5.6, 5.6, { breathe: true }),
        HEAD,
        cap('nearFrontLeg', '近侧前腿（平伸）', 'body', 17, 29.6, 6, 29.8, 1.1, { edge: 'above', reach: true }),
        ell('nearPaw', '近侧前爪', 'dark', 6, 29.8, 1.4, 1.1, { onlyOver: 'body', reach: true }),
        ell('farPaw', '远侧前爪', 'dark', 5, 28.2, 1.3, 1, { onlyOver: 'shade', reach: true }),
        box('hindPaw', '后爪', 'dark', 35, 30.5, 4, 1, 0.5, { onlyOver: 'body' }),
      ],
      marks: [
        // 后腿大腿上沿的弧线
        { ink: 'shade', points: [[29, 27], [30, 26], [31, 25], [32, 25], [33, 25], [34, 26], [35, 27]] },
        { ink: 'light', points: [[24, 17], [25, 17], [26, 16], [27, 16]] },
      ],
    },
    peek: {
      // 贴边探头：和「趴着」整张逆时针转 90°（头朝上）的方向一致，
      // 但只露出小柚子和半个脑袋，身体藏在屏幕边（画布右边）外
      width: 32,
      from: 'lie',
      headOnly: true,
      turn: -1,
      flipY: true,
      offsetX: 11,
      offsetY: 5,
      reachPixels: 1,
    },
    hold: {
      width: 32,
      head: { x: 13.5, y: 9.5, rot: 0, scale: 1 },
      yuzu: false,
      pivotRow: 17,
      tiltDegrees: 8,
      parts: [
        box('farHindLeg', '远侧后腿', 'shade', 14, 28.5, 2, 5, 0),
        box('nearHindLeg', '近侧后腿', 'body', 19, 28.5, 2, 5, 0),
        ell('neck', '后颈', 'body', 18.5, 15.5, 4.6, 4),
        ell('belly', '圆肚子', 'body', 15, 21.6, 8.2, 7),
        ell('tummy', '浅色肚皮', 'light', 12.8, 22.6, 4.4, 5, { onlyOver: 'body' }),
        HEAD,
        cap('frontLeg', '前腿（垂在胸前）', 'body', 9.5, 16.5, 8.5, 20, 1.4, { edge: 'inner' }),
        ell('frontPawTip', '前爪尖', 'dark', 8.5, 20.4, 1.4, 0.9, { onlyOver: 'body' }),
        box('hindPaws', '后爪', 'dark', 16.5, 30, 7, 2, 0, { onlyOver: 'body' }),
        box('hindPawFar', '远侧后爪', 'dark', 14, 30, 2, 2, 0, { onlyOver: 'shade' }),
      ],
      marks: [],
    },
  },
});
