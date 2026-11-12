// 三视图对照图：侧面各姿势、正面的头、背面并排，同一条地面线，画上头顶 / 下巴 / 地面三条参考线，
// 一眼看出哪个姿势头大了、身子小了、站得高了。
import { Grid } from './raster.mjs';
import { renderPose } from './render.mjs';
import { frontFace, frontHead } from './front-head.mjs';
import { chaseFrame } from './chase.mjs';
import { measure } from './measure.mjs';
import { renderBack } from './back.mjs';

const HEIGHT = 32;
const GAP = 3;
/** frontHead(c) 画出来头顶在第 c - 8 行 */
const FRONT_HEAD_TOP_OFFSET = 8;

/** 参考线的颜色（只画在空白处，不盖住水豚） */
export const GUIDE_INK = 'guide';
export const GUIDE_COLOR = '#E04A4A';

function columns(model) {
  const sit = renderPose(model, 'sit', { chewPhase: 0 });
  const headTop = measure(sit).head.top;
  return [
    ['侧·坐', sit],
    ['侧·拎', renderPose(model, 'hold', { tilt: 0 })],
    ['侧·站', chaseFrame(model, 0)],
    ['侧·趴', renderPose(model, 'lie', {})],
    ['正·头', frontFace(frontHead(headTop + FRONT_HEAD_TOP_OFFSET), headTop + FRONT_HEAD_TOP_OFFSET)],
    ['背', renderBack()],
  ];
}

/** 参考线所在的行：坐姿的头顶、下巴、地面 */
export function guideRows(model) {
  const m = measure(renderPose(model, 'sit', { chewPhase: 0 }));
  return Object.freeze({ headTop: m.head.top, chin: m.head.bottom, ground: m.figure.bottom });
}

/** 返回 { grid, labels }：labels 是每一栏的名字和起始列 */
export function turnaround(model) {
  const cols = columns(model);
  const width = cols.reduce((sum, [, grid]) => sum + grid.width + GAP, GAP);
  const placed = cols.reduce(
    ({ grid, x, labels }, [label, col]) => ({
      grid: grid.overlaid(col.windowed(-x, 0, width, HEIGHT)),
      x: x + col.width + GAP,
      labels: [...labels, { label, x }],
    }),
    { grid: Grid.empty(width, HEIGHT), x: GAP, labels: [] },
  );
  const rows = Object.values(guideRows(model));
  const grid = placed.grid.paint(GUIDE_INK, (x, y, current) => current === 'clear' && rows.includes(y) && x % 2 === 0, 'outline');
  return Object.freeze({ grid, labels: placed.labels });
}
