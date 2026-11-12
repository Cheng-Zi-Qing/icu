// 体型一致性检查：每一帧是不是同一只水豚（头一样大、整只一样大、肚皮该露才露），三视图对不对得上。
// 标准见 body-spec.mjs；量法见 measure.mjs（按部位量，不按颜色）。
import { renderPose } from './render.mjs';
import { frontHead } from './front-head.mjs';
import { renderBack } from './back.mjs';
import { measure } from './measure.mjs';
import { BELLY_RULES, FIGURE_RANGE, HEAD_RULES, THREE_VIEW_RULES, VIEWS, frameKind } from './body-spec.mjs';

/** 正面那颗头单独画在画布中间量 */
const FRONT_HEAD_ROW = 16;

/** 标准：侧面坐姿整只 + 三个视角的头（都不戴装扮量）；背面整只单独留着，比头顶和地面 */
export function referenceMeasures(model) {
  const side = measure(renderPose(model, 'sit', { chewPhase: 0 }));
  const back = measure(renderBack({ headwear: null }));
  return Object.freeze({
    figure: side.figure,
    backFigure: back.figure,
    head: Object.freeze({ side: side.head, front: measure(frontHead(FRONT_HEAD_ROW)).head, back: back.head }),
  });
}

const issue = (path, check, expected, actual) => Object.freeze({ path, check, expected, actual });
const pct = (ratio) => `${Math.round(ratio * 100)}%`;
const size = (box) => `${box.w}×${box.h}`;

/** 头：一样大。被道具或屏幕边挡住一块不算错（记成 note），但两个方向都缩了就是头变小了 */
function headFindings(path, head, ref, kind) {
  if (!ref) return { issues: [issue(path, 'head', `${kind.view} 视角的标准头`, '还没有这个视角')], notes: [] };
  if (!head) return kind.partial ? { issues: [], notes: [`${path}: 头完全被挡住`] } : { issues: [issue(path, 'head', '有头', '没有头')], notes: [] };
  const [w, h] = kind.rotated ? [head.h, head.w] : [head.w, head.h];
  const ratio = head.area / ref.area;
  const tol = HEAD_RULES.sizeTolerance;
  const tooBig = ratio > 1 + HEAD_RULES.areaTolerance || w > ref.w + tol || h > ref.h + tol;
  if (tooBig) return { issues: [issue(path, 'head', `${ref.area} 格 ${size(ref)}`, `${head.area} 格（${pct(ratio)}）${w}×${h}`)], notes: [] };
  if (ratio < 1 - HEAD_RULES.areaTolerance) {
    // 被挡住时至少有一个方向的长度还在；两个方向都短了是整颗头缩了
    const keptOneSide = Math.abs(w - ref.w) <= 1 || Math.abs(h - ref.h) <= 1;
    if (kind.partial || keptOneSide) return { issues: [], notes: [`${path}: 头被挡住 ${pct(1 - ratio)}`] };
    return { issues: [issue(path, 'head', `${ref.area} 格 ${size(ref)}`, `${head.area} 格（${pct(ratio)}）${w}×${h}`)], notes: [] };
  }
  if (Math.abs(w - ref.w) > tol || Math.abs(h - ref.h) > tol) {
    return { issues: [issue(path, 'head shape', size(ref), `${w}×${h}`)], notes: [] };
  }
  return { issues: [], notes: [] };
}

/** 整只：按姿势和坐姿比 */
function figureIssues(path, figure, ref, pose) {
  const range = FIGURE_RANGE[pose];
  if (!range) return [issue(path, 'figure', `已知姿势（${Object.keys(FIGURE_RANGE).join('/')}）`, pose)];
  const ratio = (figure?.area ?? 0) / ref.area;
  if (ratio >= range[0] && ratio <= range[1]) return [];
  return [issue(path, `figure (${pose})`, `坐姿的 ${pct(range[0])}–${pct(range[1])}`, `${figure?.area ?? 0} 格（${pct(ratio)}）`)];
}

/** 肚皮：身体部位上的浅色格子数 */
function bellyIssues(path, grid, pose) {
  let light = 0;
  for (let i = 0; i < grid.cells.length; i += 1) if (grid.cells[i] === 'light' && grid.tags[i] === 'body') light += 1;
  if (BELLY_RULES.shownIn.includes(pose)) {
    return light >= BELLY_RULES.minPixels ? [] : [issue(path, 'belly', `露肚皮（≥ ${BELLY_RULES.minPixels} 格浅色）`, `${light} 格`)];
  }
  return light <= BELLY_RULES.maxPixelsElsewhere ? [] : [issue(path, 'belly', `侧面不露肚皮（≤ ${BELLY_RULES.maxPixelsElsewhere} 格浅色）`, `${light} 格`)];
}

/** 一帧的全部检查。kind 不给就按路径认（body-spec.mjs 的 FRAME_KINDS） */
export function checkFrame(path, grid, refs, kind = frameKind(path)) {
  if (!kind || kind.skip) return { issues: [], notes: [] };
  const m = measure(grid);
  const head = headFindings(path, m.head, refs.head[kind.view], kind);
  if (kind.partial) return head;
  return {
    issues: [...head.issues, ...figureIssues(path, m.figure, refs.figure, kind.pose), ...bellyIssues(path, grid, kind.pose)],
    notes: head.notes,
  };
}

/** 三视图之间：正面头和侧面头一样高，正面宽和侧面长成比例；缺的视角记下来 */
export function threeViewIssues(refs) {
  const { side, front } = refs.head;
  const found = [];
  if (Math.abs(front.h - side.h) > THREE_VIEW_RULES.headHeightTolerance) {
    found.push(issue('三视图', 'head height', `正面 = 侧面 ±${THREE_VIEW_RULES.headHeightTolerance}`, `正面 ${front.h}，侧面 ${side.h}`));
  }
  const [lo, hi] = THREE_VIEW_RULES.frontWidthToSideLength;
  const ratio = front.w / side.w;
  if (ratio < lo || ratio > hi) {
    found.push(issue('三视图', 'head width', `正面宽 / 侧面长 ${lo}–${hi}`, ratio.toFixed(2)));
  }
  const { back } = refs.head;
  if (back) {
    const tol = THREE_VIEW_RULES.headHeightTolerance;
    if (Math.abs(back.h - front.h) > tol || Math.abs(back.w - front.w) > tol) {
      found.push(issue('三视图', 'back head', `背面头 = 正面头 ±${tol}（${size(front)}）`, size(back)));
    }
    const lines = THREE_VIEW_RULES.lineTolerance;
    const { figure, backFigure } = refs;
    if (Math.abs(backFigure.top - figure.top) > lines || Math.abs(backFigure.bottom - figure.bottom) > lines) {
      found.push(issue('三视图', 'back lines', `头顶 ${figure.top}、地面 ${figure.bottom}（侧面坐姿）`, `头顶 ${backFigure.top}、地面 ${backFigure.bottom}`));
    }
  }
  const missing = VIEWS.filter((view) => !refs.head[view]);
  return { issues: found, missing };
}

/**
 * 整套检查。frames：[[路径, 网格, kind?], ...]（kind 可选，给设计稿这类不在素材路径里的帧用）
 * 返回 { issues, notes, missingViews, checked }
 */
export function checkConsistency(frames, model) {
  const refs = referenceMeasures(model);
  const perFrame = frames.map(([path, grid, kind]) => checkFrame(path, grid, refs, kind ?? frameKind(path)));
  const views = threeViewIssues(refs);
  return Object.freeze({
    issues: [...views.issues, ...perFrame.flatMap((r) => r.issues)],
    notes: perFrame.flatMap((r) => r.notes),
    missingViews: views.missing,
    checked: frames.length,
    references: refs,
  });
}
