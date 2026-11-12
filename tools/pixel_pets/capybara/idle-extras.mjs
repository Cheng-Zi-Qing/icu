// 发呆时偶尔做的小动作（2026-11-11 用户定）：戴墨镜晒太阳、坐进木盆泡澡。
// 都在平时 32 格的坐姿画布里演，帧放在 idle_act/ 下，和看小鸟、晃橙子一起由 App 随机挑。
import { canvasPixel } from './raster.mjs';
import { renderPose } from './render.mjs';
import { block, line, plain, prop, stacked } from './scene-props.mjs';

const WIDTH = 32;

/** 往后一仰：上半身往右（背那边）挪，越往上挪得越多 */
function leanedBack(grid, pixels) {
  const pivot = 24;
  return grid.sampled(grid.width, grid.height, (x, y) => [x - Math.round((pixels * Math.max(0, pivot - y)) / pivot), y]);
}

/** 这一行往后仰了几格（和 leanedBack 同一个算法） */
const leanAt = (y, pixels) => Math.round((pixels * Math.max(0, 24 - y)) / 24);

// ---------------- 晒太阳 ----------------

const LEAN = 2;

function sunglasses(model) {
  const [ex, ey] = canvasPixel(model.poses.sit.head, model.head.marks.eye.x, model.head.marks.eye.y);
  const x = ex + leanAt(ey, LEAN);
  // 一只镜片盖住眼睛，镜腿挂到耳朵；镜片上一点反光
  return plain(WIDTH, [
    ['outline', [...block(x - 1, ey - 1, 4, 3), ...line([x + 3, ey - 1], [x + 5, ey - 2])]],
    ['white', [[x, ey - 1]]],
  ]);
}

/** 右上角（背后上方，不挡头）的小太阳，光芒一拍长一拍短 */
function sun(twinkle) {
  const disc = prop(WIDTH, ['star', [...block(27, 1, 4, 4), ...block(28, 0, 2, 1), ...block(28, 5, 2, 1)]]);
  const rays = twinkle ? [[25, 6], [25, 0], [31, 6]] : [[24, 7], [24, 0], [31, 7], [25, 6]];
  return disc.overlaid(plain(WIDTH, [['star', rays]]));
}

export function sunbatheFrame({ inhale, twinkle, headwear, model }) {
  const body = leanedBack(renderPose(model, 'sit', { headwear, face: 'happy', inhale, chewPhase: 0 }), LEAN);
  return stacked(body, sunglasses(model), sun(twinkle));
}

// ---------------- 泡澡 ----------------

function tub() {
  return prop(WIDTH, ['strawShade', [...block(2, 22, 29, 8), ...block(4, 30, 3, 2), ...block(26, 30, 3, 2)]], [
    ['straw', block(3, 23, 27, 6)],
    ['sweat', block(3, 22, 27, 1)],
    ['strawShade', [...block(3, 25, 27, 1)]],
  ]);
}

/** 叠好的毛巾顶在头上（不戴平时的橙子） */
function towel(model) {
  const [x, y] = canvasPixel(model.poses.sit.head, model.head.marks.yuzu.x, model.head.marks.yuzu.y);
  return prop(WIDTH, ['white', block(x - 3, y - 1, 7, 2)], [['dust', block(x - 3, y, 7, 1)]]);
}

const STEAM = [
  [[22, 4], [23, 3], [22, 2], [26, 6], [27, 5], [26, 4]],
  [[23, 4], [22, 3], [23, 2], [27, 6], [26, 5], [27, 4]],
];

export function bathFrame({ steam, blink, model }) {
  const body = renderPose(model, 'sit', { face: blink ? undefined : 'flat', blink, props: false });
  const bubbles = prop(WIDTH, ['white', [[6, 20], [12, 21], [24, 20]]]);
  return stacked(body, tub(), towel(model), plain(WIDTH, [['white', STEAM[steam]]]), bubbles);
}

/** 两段小动作的帧参数（8 帧一轮，App 4 fps 放 2 秒） */
export function idleExtraOptions() {
  return {
    sunbathe: Array.from({ length: 8 }, (_, f) => ({ inhale: f >= 4, twinkle: Math.floor(f / 2) % 2 })),
    bath: Array.from({ length: 8 }, (_, f) => ({ steam: Math.floor(f / 2) % 2, blink: f === 5 })),
  };
}

export const IDLE_EXTRA_RENDER = Object.freeze({ sunbathe: sunbatheFrame, bath: bathFrame });
