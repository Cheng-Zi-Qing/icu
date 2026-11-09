// 编辑器的纯状态函数：全部返回新对象，不改原模型（浏览器和测试共用）
import { toCanvas, toLocal } from './raster.mjs';

export const POSE_TABS = ['sit', 'lie', 'peek', 'hold'];
export const HISTORY_LIMIT = 100;

const round = (value, step = 0.1) => Math.round(value / step) * step;
const tidy = (value) => Number(value.toFixed(2));

export function getIn(obj, path) {
  return path.reduce((node, key) => node?.[key], obj);
}

/** 按路径写值，沿途复制，原对象不变 */
export function setIn(obj, path, value) {
  if (path.length === 0) return value;
  const [key, ...rest] = path;
  const copy = Array.isArray(obj) ? [...obj] : { ...obj };
  copy[key] = setIn(obj?.[key], rest, value);
  return copy;
}

// ---------- 部件 ----------

/** 形状参数的滑杆范围：[字段, 标签, 最小, 最大, 步长] */
export const FIELD_SPECS = {
  ellipse: [['cx', '中心 x', -16, 64, 0.1], ['cy', '中心 y', -16, 40, 0.1], ['rx', '半宽', 0.3, 20, 0.1], ['ry', '半高', 0.3, 20, 0.1], ['rot', '旋转°', -90, 90, 1]],
  rbox: [['cx', '中心 x', -16, 64, 0.1], ['cy', '中心 y', -16, 40, 0.1], ['w', '宽', 0.5, 40, 0.1], ['h', '高', 0.5, 40, 0.1], ['r', '圆角', 0, 10, 0.1], ['rot', '旋转°', -90, 90, 1]],
  capsule: [['x1', '起点 x', -16, 64, 0.1], ['y1', '起点 y', -16, 40, 0.1], ['x2', '终点 x', -16, 64, 0.1], ['y2', '终点 y', -16, 40, 0.1], ['r', '粗细（半径）', 0.3, 8, 0.1]],
};

export const HEAD_TRANSFORM_SPECS = [['x', '头 x', 0, 64, 0.1], ['y', '头 y', 0, 32, 0.1], ['rot', '头旋转°', -45, 45, 1], ['scale', '头缩放', 0.6, 1.4, 0.01]];

export function movedPart(part, dx, dy) {
  if (part.shape === 'capsule') {
    return { ...part, x1: tidy(part.x1 + dx), x2: tidy(part.x2 + dx), y1: tidy(part.y1 + dy), y2: tidy(part.y2 + dy) };
  }
  if (part.shape === 'head') return part;
  return { ...part, cx: tidy(part.cx + dx), cy: tidy(part.cy + dy) };
}

export function partsPath(tab) {
  return tab === 'head' ? ['head', 'parts'] : ['poses', tab, 'parts'];
}

export function withoutIndex(list, index) {
  return list.filter((_, i) => i !== index);
}

export function withInserted(list, index, item) {
  return [...list.slice(0, index), item, ...list.slice(index)];
}

export function withMoved(list, from, to) {
  if (to < 0 || to >= list.length || from === to) return list;
  return withInserted(withoutIndex(list, from), to, list[from]);
}

/** 复制部件，id 加后缀保证唯一 */
export function duplicatedPart(parts, index) {
  const source = parts[index];
  const ids = new Set(parts.map((p) => p.id));
  let n = 2;
  while (ids.has(`${source.id}${n}`)) n += 1;
  return withInserted(parts, index + 1, { ...movedPart(source, 1, 0), id: `${source.id}${n}`, label: `${source.label ?? source.id} 副本` });
}

// ---------- 拖动 ----------

/** 画布上的位移 → 头局部坐标的位移（抵消头的旋转和缩放） */
export function canvasDeltaToLocal(transform, dx, dy) {
  const [ox, oy] = toLocal(transform, transform.x, transform.y);
  const [lx, ly] = toLocal(transform, transform.x + dx, transform.y + dy);
  return [lx - ox, ly - oy];
}

/**
 * 按选中项拖动，返回新模型。selection:
 *   { kind: 'part', tab, index } | { kind: 'mark', name } | { kind: 'peek' }
 * headTransform：当前画面里头的变换（头部件 / 五官拖动时用）
 */
export function dragged(model, selection, dx, dy, headTransform) {
  const sx = round(dx, 0.5);
  const sy = round(dy, 0.5);
  if (!selection || (sx === 0 && sy === 0)) return model;

  if (selection.kind === 'peek') {
    const peek = model.poses.peek;
    return setIn(setIn(model, ['poses', 'peek', 'offsetX'], tidy((peek.offsetX ?? 0) + sx)), ['poses', 'peek', 'offsetY'], tidy((peek.offsetY ?? 0) + sy));
  }
  if (selection.kind === 'mark') {
    const [lx, ly] = canvasDeltaToLocal(headTransform, sx, sy);
    const mark = model.head.marks[selection.name];
    return setIn(model, ['head', 'marks', selection.name], { x: tidy(round(mark.x + lx, 0.5)), y: tidy(round(mark.y + ly, 0.5)) });
  }
  const path = [...partsPath(selection.tab), selection.index];
  const part = getIn(model, path);
  if (!part) return model;
  if (part.shape === 'head') {
    const head = model.poses[selection.tab].head;
    return setIn(model, ['poses', selection.tab, 'head'], { ...head, x: tidy(head.x + sx), y: tidy(head.y + sy) });
  }
  if (selection.tab === 'head') {
    const [lx, ly] = canvasDeltaToLocal(headTransform, sx, sy);
    return setIn(model, path, movedPart(part, round(lx, 0.1), round(ly, 0.1)));
  }
  return setIn(model, path, movedPart(part, sx, sy));
}

/** 五官锚点的画布位置（拾取用） */
export function markCanvasPoint(model, name, headTransform) {
  const mark = model.head.marks[name];
  return toCanvas(headTransform, mark.x, mark.y);
}

// ---------- 撤销 / 重做 ----------

export function createHistory(present) {
  return { past: [], present, future: [] };
}

export function committed(history, next) {
  if (next === history.present) return history;
  return { past: [...history.past, history.present].slice(-HISTORY_LIMIT), present: next, future: [] };
}

export function undone(history) {
  if (history.past.length === 0) return history;
  return { past: history.past.slice(0, -1), present: history.past.at(-1), future: [history.present, ...history.future] };
}

export function redone(history) {
  if (history.future.length === 0) return history;
  return { past: [...history.past, history.present], present: history.future[0], future: history.future.slice(1) };
}
