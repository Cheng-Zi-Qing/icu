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
  // 草帽（衣柜里的头顶装扮）
  straw: '#E9C46A', strawShade: '#C99A3E', band: '#C8503C',
  // 来访的小鸟（水豚身上常停着小鸟）
  bird: '#7FB2D9', birdWing: '#4F7FAE',
  // 干活场景里青菜的暗面
  leaf: '#3F7F34',
  // 新场景的道具：按钮底座、鱼钩、针这类金属
  metal: '#9AA3AD', metalDark: '#6B737C',
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
        ell('bellyShade', '腿间阴影', 'shade', 16, 26.5, 3, 3.6),
        box('hindFoot', '后脚', 'shade', 17.5, 30, 5, 2, 0),
        ell('hips', '臀部', 'body', 22.6, 22.6, 8, 7.6),
        ell('chest', '胸口', 'body', 14.6, 18.5, 7, 6, { breathe: true }),
        ell('back', '背', 'body', 19.5, 15.5, 6, 4.6),
        ell('nape', '后颈', 'body', 18.2, 10.6, 3.6, 5),
        ell('belly', '圆肚子', 'body', 15.2, 23, 5.6, 4.6),
        // 两只前腿都在肚皮前面，都描边，和肚皮分开。
        // 腿和身体同色，只有脚是深色（2026-11-11 用户定，方案 B）
        box('farFrontLeg', '远侧前腿', 'body', 14, 27, 2, 8, 0, { edge: 'inner' }),
        box('nearFrontLeg', '近侧前腿', 'body', 11, 27, 2, 8, 0, { edge: 'inner' }),
        HEAD,
        box('nearPaw', '近侧前爪', 'dark', 11, 30, 2, 2, 0, { onlyOver: 'body' }),
        box('farPaw', '远侧前爪', 'dark', 14, 30.5, 2, 1, 0, { onlyOver: 'body' }),
        box('hindPaw', '后爪', 'dark', 17, 30, 4, 2, 0, { onlyOver: 'shade' }),
      ],
      marks: [
        { ink: 'shade', points: [[17, 25], [18, 24], [19, 23], [20, 23], [21, 23], [22, 23], [23, 24], [24, 25]] },
        { ink: 'light', points: [[20, 12], [21, 12], [22, 13], [23, 13]] },
      ],
    },
    lie: {
      width: 44,
      // 下巴贴地：头是最低的地方（2026-11-11 用户：原来那版不自然，头像搁在身子上）
      head: { x: 9.5, y: 22.5, rot: 0, scale: 1 },
      yuzu: true,
      parts: [
        // 腿全收在身子底下：下巴底下露两个前爪尖，屁股后面露一点后脚
        ell('farPaw', '远侧前爪', 'dark', 4.6, 29.9, 1.2, 0.8, { reach: true }),
        // 一整条圆顶的身子，从后脑勺顺下来，中后段最高；不单独鼓一个屁股（像驼峰）
        ell('barrel', '身体', 'body', 26.5, 24.2, 15, 7),
        ell('rump', '臀部', 'body', 34.5, 24.4, 7.6, 6.8),
        ell('shoulder', '肩膀', 'body', 18, 24.6, 6.4, 5.8, { breathe: true }),
        ell('hindPaw', '后脚', 'shade', 39.5, 29.8, 2.2, 1),
        HEAD,
        ell('nearPaw', '近侧前爪', 'dark', 7.5, 30, 1.5, 0.8, { reach: true }),
      ],
      marks: [
        // 收着的后腿：一道浅浅的弧线
        { ink: 'shade', points: [[31, 28], [32, 27], [33, 26], [34, 26], [35, 26], [36, 27], [37, 28]] },
        { ink: 'light', points: [[24, 18], [25, 18], [26, 18], [27, 18]] },
      ],
    },
    peek: {
      // 贴边转头（edge/turn_*）：坐姿的头逆时针转 90° 再上下翻（鼻子朝上、头顶朝屏幕里），
      // 脖子和背直接用坐姿的后颈、背、胸口、肚子、屁股：坐姿侧面那条从后脑勺往后弯的背弧，
      // 转过来就是从后脑勺往下、再弯进屏幕边的弧线（不是一根直线，也不是细长脖子）。腿脚不画，藏在屏幕外。
      // 和正面探头来回切，所以头探出来的多少、上下位置都对齐正面那颗头；正面不叼草，这里也不叼
      width: 32,
      from: 'sit',
      headOnly: true,
      keepParts: ['nape', 'back', 'chest', 'belly', 'hips'],
      grass: false,
      turn: -1,
      flipY: true,
      offsetX: 11,
      offsetY: 6,
      reachPixels: 1,
    },
    hold: {
      width: 32,
      // 头的小数位置和坐姿一样（都落在半格上），栅格化出来才是同一颗头
      head: { x: 13.5, y: 12.5, rot: 0, scale: 1 },
      yuzu: true,
      pivotRow: 17,
      tiltDegrees: 8,
      parts: [
        // 身子和坐姿一样壮（体型检查：坐姿的 95–105%）：肚子、屁股各一团，垂下来不缩水。
        // 被拎起来时身子正对你，露出浅色肚皮（侧面姿势都不画肚皮，2026-11-11 用户定）
        // 腿和身体同色，只有脚是深色
        box('farHindLeg', '远侧后腿', 'body', 15, 28.5, 2, 5, 0),
        box('nearHindLeg', '近侧后腿', 'body', 22, 28.5, 2, 5, 0),
        ell('neck', '后颈', 'body', 19.5, 16.5, 6, 5),
        ell('rump', '屁股', 'body', 21, 22.8, 9.2, 7.4),
        ell('belly', '圆肚子', 'body', 15.5, 22.4, 10.6, 8.1),
        ell('tummy', '浅色肚皮', 'light', 13, 23.4, 5.2, 5.2, { onlyOver: 'body' }),
        HEAD,
        cap('frontLeg', '前腿（垂在胸前）', 'body', 9.5, 19, 8.5, 22, 1.4, { edge: 'inner' }),
        ell('frontPawTip', '前爪尖', 'dark', 8.5, 22.4, 1.4, 0.9, { onlyOver: 'body' }),
        // 后脚只露最底下一行（腿被屁股挡住，深色不能渗到屁股上）
        box('hindPaws', '后爪', 'dark', 22, 31, 2, 1, 0, { onlyOver: 'body' }),
        box('hindPawFar', '远侧后爪', 'dark', 15, 31, 2, 1, 0, { onlyOver: 'body' }),
      ],
      marks: [],
    },
  },
});
