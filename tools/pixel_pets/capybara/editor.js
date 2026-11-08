// 水豚造型编辑器：选部件、拖动、滑杆调参数、实时预览、保存生成素材
import { INKS, partMask, shapeContains, toLocal } from './raster.mjs';
import { PALETTE, POSE_LABELS } from './model.mjs';
import { idleMainOptions, renderPose, resolvePose } from './render.mjs';
import { validateModel } from './validate.mjs';
import {
  FIELD_SPECS, HEAD_TRANSFORM_SPECS, committed, createHistory, dragged, duplicatedPart, getIn,
  markCanvasPoint, partsPath, redone, setIn, undone, withMoved, withoutIndex,
} from './editor-state.mjs';
import { drawGrid, drawMask, drawPixelLines, drawPoint, drawReference, drawVerticalLine, sizeCanvas } from './editor-view.mjs';

const $ = (id) => document.getElementById(id);
const MARK_LABELS = { eye: '眼睛', blush: '腮红', nostril: '鼻孔', mouth: '嘴', highlight: '头顶高光', earInner: '耳朵内侧', yuzu: '柚子位置', grass: '草的位置' };
const EDGE_LABELS = { '': '无', below: '下沿描线', above: '上沿描线', around: '一圈描线', inner: '内侧描线' };
const PEEK_SCRIPT = [0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 1, 0];
const PEEK_OPTIONS = [{}, { blink: true }, { reach: true }];
const PEEK_GHOST_WIDTH = 60;
const TURN_LABELS = { 0: '不转', '-1': '逆时针 90°（地面 → 屏幕边）', 1: '顺时针 90°', 2: '180°' };
const PREVIEW_ZOOM = 4;

const state = {
  history: null, defaults: null, saved: null,
  tab: 'sit', viewPose: 'sit', selection: null,
  opts: { blink: false, inhale: false, earTwitch: false, chew: false, reach: false, face: '', tilt: 0 },
  zoom: 16, lines: true,
  ref: { name: '', image: null, visible: true, opacity: 0.45, x: 0, y: 0, scale: 0.1, flip: false, front: false, drag: false },
  liveBase: null, drag: null, tick: 0,
};

const model = () => state.history.present;
/** 由别的姿势平移得到的派生姿势（没有自己的部件） */
const isDerived = (tab) => tab !== 'head' && Boolean(model().poses[tab]?.from);

// ---------- 修改 ----------

function commit(next) {
  state.history = committed(state.history, next);
  refresh();
}

/** 滑杆拖动 / 画布拖动时的实时修改：结束时（settle）才记一步撤销 */
function live(next) {
  if (!state.liveBase) state.liveBase = model();
  state.history = { ...state.history, present: next };
  refresh({ inspector: false });
}

function settle() {
  if (!state.liveBase) return;
  const next = model();
  state.history = committed({ ...state.history, present: state.liveBase }, next);
  state.liveBase = null;
  refresh();
}

function setStatus(text, kind = '') {
  $('status').textContent = text;
  $('status').className = kind;
}

// ---------- 画面 ----------

function frameOptions() {
  const o = state.opts;
  return { blink: o.blink, inhale: o.inhale, earTwitch: o.earTwitch, chewPhase: o.chew ? 1 : 0, reach: o.reach, face: o.face || undefined, tilt: o.tilt };
}

function stageHeadTransform() {
  return resolvePose(model(), state.viewPose).head;
}

function stageWidth() {
  return state.viewPose === 'peek' ? PEEK_GHOST_WIDTH : resolvePose(model(), state.viewPose).width ?? 32;
}

function selectionMask() {
  const sel = state.selection;
  if (!sel || sel.kind !== 'part') return null;
  const head = stageHeadTransform();
  if (sel.tab === 'head') return partMask(model().head.parts[sel.index], head);
  const part = model().poses[sel.tab].parts[sel.index];
  if (part.shape !== 'head') return partMask(part, null);
  const masks = model().head.parts.map((p) => partMask(p, head));
  return (x, y) => masks.some((m) => m(x, y));
}

function drawStage() {
  const zoom = state.zoom;
  const width = stageWidth();
  const ctx = sizeCanvas($('stage'), width * zoom, 32 * zoom);
  const grid = renderPose(model(), state.viewPose, { ...frameOptions(), width });
  if (!state.ref.front) drawReference(ctx, state.ref.image, state.ref, zoom);
  drawGrid(ctx, grid, { zoom, fadeFrom: state.viewPose === 'peek' ? model().poses.peek.width ?? 32 : Infinity });
  if (state.ref.front) drawReference(ctx, state.ref.image, state.ref, zoom);
  if (state.lines) drawPixelLines(ctx, width, 32, zoom);
  if (state.viewPose === 'peek') drawVerticalLine(ctx, (model().poses.peek.width ?? 32) * zoom, 32 * zoom, '#D0453C', '屏幕边（右边淡色部分在屏幕外，爪子要扒在这条线上）');

  const mask = selectionMask();
  if (mask) drawMask(ctx, mask, width, 32, zoom);
  if (state.selection?.kind === 'mark') drawPoint(ctx, markCanvasPoint(model(), state.selection.name, stageHeadTransform()), zoom);
}

function drawPreview(canvasId, grid, { mirror = false, edge = null } = {}) {
  const margin = edge ? 8 : 0;
  const width = grid.width * PREVIEW_ZOOM + margin;
  const ctx = sizeCanvas($(canvasId), width, grid.height * PREVIEW_ZOOM);
  const ox = edge === 'left' ? margin : 0;
  drawGrid(ctx, grid, { zoom: PREVIEW_ZOOM, ox, mirror });
  if (edge) {
    ctx.fillStyle = '#3A342F';
    ctx.fillRect(edge === 'left' ? 0 : width - margin, 0, margin, grid.height * PREVIEW_ZOOM);
  }
}

function drawPreviews() {
  const m = model();
  const idle = idleMainOptions();
  drawPreview('pv-idle', renderPose(m, 'sit', idle[state.tick % idle.length]));
  const swing = [0, 1, 2, 1, 0, -1, -2, -1];
  drawPreview('pv-hold', renderPose(m, 'hold', { face: 'squeeze', tilt: swing[state.tick % swing.length] }));
  const peek = renderPose(m, 'peek', PEEK_OPTIONS[PEEK_SCRIPT[Math.floor(state.tick / 2) % PEEK_SCRIPT.length]]);
  drawPreview('pv-edge-left', peek, { mirror: true, edge: 'left' });
  drawPreview('pv-edge-right', peek, { edge: 'right' });
}

// ---------- 左栏：姿势 + 部件列表 ----------

function renderTabs() {
  const tabs = [['head', '头（共用，改一次所有姿势都变）'], ...Object.entries(POSE_LABELS)];
  $('tabs').replaceChildren(...tabs.map(([key, label]) => {
    const button = document.createElement('button');
    button.textContent = label;
    button.className = state.tab === key ? 'active' : '';
    button.onclick = () => selectTab(key);
    return button;
  }));
}

function listItems() {
  if (isDerived(state.tab)) return [];
  if (state.tab === 'head') {
    const parts = model().head.parts.map((p, index) => ({ sel: { kind: 'part', tab: 'head', index }, label: p.label ?? p.id, ink: p.ink }));
    const marks = Object.keys(model().head.marks).map((name) => ({ sel: { kind: 'mark', name }, label: `◎ ${MARK_LABELS[name] ?? name}`, ink: null }));
    return [...parts, ...marks];
  }
  return model().poses[state.tab].parts.map((p, index) => ({ sel: { kind: 'part', tab: state.tab, index }, label: p.label ?? p.id, ink: p.shape === 'head' ? null : p.ink }));
}

const sameSelection = (a, b) => a && b && a.kind === b.kind && a.tab === b.tab && a.index === b.index && a.name === b.name;

function renderPartList() {
  const items = listItems();
  $('parts-title').textContent = isDerived(state.tab) ? `这个姿势是把「${POSE_LABELS[model().poses[state.tab].from]}」整张旋转 / 平移得到的，形状去那里改；在画布上拖动调位置` : '部件（列表越靠下画得越靠前）';
  $('parts').replaceChildren(...items.map((item) => {
    const li = document.createElement('li');
    li.className = sameSelection(item.sel, state.selection) ? 'active' : '';
    const swatch = document.createElement('span');
    swatch.className = 'swatch';
    swatch.style.background = item.ink ? PALETTE[item.ink] : 'transparent';
    li.append(swatch, document.createTextNode(item.label));
    li.onclick = () => select(item.sel);
    return li;
  }));
  const isPart = state.selection?.kind === 'part';
  ['part-up', 'part-down', 'part-dup', 'part-del'].forEach((id) => { $(id).disabled = !isPart; });
  $('part-add').disabled = isDerived(state.tab);
}

// ---------- 右栏：属性 ----------

function numberField(label, value, { min, max, step }, onInput) {
  const row = document.createElement('div');
  row.className = 'field';
  const name = document.createElement('span');
  name.textContent = label;
  const range = Object.assign(document.createElement('input'), { type: 'range', min, max, step, value });
  const number = Object.assign(document.createElement('input'), { type: 'number', min, max, step, value });
  range.oninput = () => { number.value = range.value; onInput(Number(range.value)); };
  range.onchange = settle;
  number.onchange = () => {
    const v = Number(number.value);
    if (!Number.isFinite(v)) return;
    range.value = v;
    onInput(v);
    settle();
  };
  row.append(name, range, number);
  return row;
}

function selectField(label, value, options, onChange) {
  const row = document.createElement('div');
  row.className = 'field';
  const name = document.createElement('span');
  name.textContent = label;
  const select = document.createElement('select');
  select.style.gridColumn = 'span 2';
  Object.entries(options).forEach(([key, text]) => select.append(new Option(text, key, false, key === (value ?? ''))));
  select.onchange = () => onChange(select.value);
  row.append(name, select);
  return row;
}

function checkField(label, checked, onChange) {
  const row = document.createElement('label');
  row.className = 'row';
  const box = Object.assign(document.createElement('input'), { type: 'checkbox', checked: Boolean(checked) });
  box.onchange = () => onChange(box.checked);
  row.append(box, document.createTextNode(label));
  return row;
}

const inkOptions = (withNone) => Object.fromEntries([...(withNone ? [['', '任意颜色上都画']] : []), ...INKS.filter((i) => i !== 'clear').map((i) => [i, i])]);

function partInspector(path, part) {
  const set = (key, value) => setIn(model(), [...path, key], value);
  const rows = [];
  rows.push(selectField('颜色', part.ink, inkOptions(false), (v) => commit(set('ink', v))));
  for (const [key, label, min, max, step] of FIELD_SPECS[part.shape]) {
    rows.push(numberField(label, part[key] ?? 0, { min, max, step }, (v) => live(set(key, v))));
  }
  rows.push(selectField('只画在', part.onlyOver ?? '', inkOptions(true), (v) => commit(set('onlyOver', v || undefined))));
  rows.push(selectField('分界描线', part.edge ?? '', EDGE_LABELS, (v) => commit(set('edge', v || undefined))));
  if (path[0] === 'poses') {
    rows.push(checkField('跟着呼吸起伏', part.breathe, (v) => commit(set('breathe', v || undefined))));
    rows.push(checkField('探头扒拉时往外伸', part.reach, (v) => commit(set('reach', v || undefined))));
  }
  return rows;
}

function renderInspector() {
  const sel = state.selection;
  const box = $('inspector');
  if (!sel) {
    $('inspector-title').textContent = '属性';
    box.replaceChildren(Object.assign(document.createElement('p'), { className: 'hint', textContent: '在画布或左边列表里选一个部件。' }));
  } else if (sel.kind === 'mark') {
    const mark = model().head.marks[sel.name];
    $('inspector-title').textContent = `五官：${MARK_LABELS[sel.name] ?? sel.name}（头的局部坐标）`;
    box.replaceChildren(
      numberField('x', mark.x, { min: -16, max: 16, step: 0.5 }, (v) => live(setIn(model(), ['head', 'marks', sel.name, 'x'], v))),
      numberField('y', mark.y, { min: -16, max: 16, step: 0.5 }, (v) => live(setIn(model(), ['head', 'marks', sel.name, 'y'], v))),
    );
  } else if (sel.kind === 'part') {
    const path = [...partsPath(sel.tab), sel.index];
    const part = getIn(model(), path);
    $('inspector-title').textContent = `部件：${part.label ?? part.id}${sel.tab === 'head' ? '（头的局部坐标）' : ''}`;
    box.replaceChildren(...(part.shape === 'head'
      ? [Object.assign(document.createElement('p'), { className: 'hint', textContent: '头整体的位置 / 角度 / 大小在下面「姿势设置」里调。' })]
      : partInspector(path, part)));
  } else {
    $('inspector-title').textContent = '贴边探头';
    box.replaceChildren();
  }
  renderPoseSettings();
  $('json').value = JSON.stringify(state.tab === 'head' ? model().head : model().poses[state.tab], null, 2);
}

function renderPoseSettings() {
  const name = state.tab === 'head' ? state.viewPose : state.tab;
  const pose = model().poses[name];
  const at = (key) => ['poses', name, key];
  const rows = [Object.assign(document.createElement('p'), { className: 'hint', textContent: `当前：${POSE_LABELS[name]}` })];
  rows.push(numberField('画布宽', pose.width ?? 32, { min: 16, max: 64, step: 1 }, (v) => live(setIn(model(), at('width'), v))));
  if (pose.from) {
    rows.push(numberField('往右推 x', pose.offsetX ?? 0, { min: -32, max: 40, step: 0.5 }, (v) => live(setIn(model(), at('offsetX'), v))));
    rows.push(numberField('上下 y', pose.offsetY ?? 0, { min: -16, max: 16, step: 0.5 }, (v) => live(setIn(model(), at('offsetY'), v))));
    rows.push(numberField('偶尔多探出', pose.reachPixels ?? 0, { min: 0, max: 6, step: 0.5 }, (v) => live(setIn(model(), at('reachPixels'), v))));
    rows.push(selectField('旋转', String(pose.turn ?? 0), TURN_LABELS, (v) => commit(setIn(model(), at('turn'), Number(v)))));
    rows.push(checkField('上下翻转（头朝上 / 朝下）', pose.flipY, (v) => commit(setIn(model(), at('flipY'), v))));
    rows.push(checkField('只露头（身体藏在屏幕外）', pose.headOnly, (v) => commit(setIn(model(), at('headOnly'), v))));
  } else {
    for (const [key, label, min, max, step] of HEAD_TRANSFORM_SPECS) {
      rows.push(numberField(label, pose.head[key] ?? (key === 'scale' ? 1 : 0), { min, max, step }, (v) => live(setIn(model(), ['poses', name, 'head', key], v))));
    }
    rows.push(checkField('头顶柚子 + 叼草', pose.yuzu, (v) => commit(setIn(model(), at('yuzu'), v))));
    if (name === 'peek') rows.push(numberField('扒拉伸出', pose.reachPixels ?? 0, { min: 0, max: 6, step: 0.5 }, (v) => live(setIn(model(), at('reachPixels'), v))));
  }
  if (name === 'hold') {
    rows.push(numberField('摇摆支点行', pose.pivotRow ?? 16, { min: 0, max: 31, step: 1 }, (v) => live(setIn(model(), at('pivotRow'), v))));
    rows.push(numberField('摇摆角度°', pose.tiltDegrees ?? 8, { min: 0, max: 20, step: 0.5 }, (v) => live(setIn(model(), at('tiltDegrees'), v))));
  }
  $('pose-settings').replaceChildren(...rows);
}

function renderRefFields() {
  const ref = state.ref;
  const update = (key) => (v) => { state.ref = { ...state.ref, [key]: v }; drawStage(); };
  $('ref-fields').replaceChildren(
    numberField('透明度', ref.opacity, { min: 0, max: 1, step: 0.05 }, update('opacity')),
    numberField('缩放', ref.scale, { min: 0.01, max: 3, step: 0.005 }, update('scale')),
    numberField('x（像素）', ref.x, { min: -64, max: 64, step: 0.5 }, update('x')),
    numberField('y（像素）', ref.y, { min: -64, max: 64, step: 0.5 }, update('y')),
  );
}

function refresh({ inspector = true } = {}) {
  drawStage();
  drawPreviews();
  renderTabs();
  renderPartList();
  if (inspector) renderInspector();
  $('undo').disabled = state.history.past.length === 0;
  $('redo').disabled = state.history.future.length === 0;
  const dirty = JSON.stringify(model()) !== JSON.stringify(state.saved);
  if (!$('status').classList.contains('error')) setStatus(dirty ? '有未保存的修改' : '已是保存的版本');
}

// ---------- 选择 / 拾取 ----------

function selectTab(tab) {
  state.tab = tab;
  if (tab !== 'head') state.viewPose = tab;
  else if (isDerived(state.viewPose)) state.viewPose = 'sit';
  state.selection = isDerived(tab) ? { kind: 'peek' } : null;
  refresh();
}

function select(selection) {
  state.selection = selection;
  refresh();
}

function pick(px, py) {
  if (isDerived(state.tab)) return { kind: 'peek' };
  const m = model();
  const head = stageHeadTransform();
  const [lx, ly] = toLocal(head, px, py);
  if (state.tab === 'head') {
    const mark = Object.keys(m.head.marks).find((name) => {
      const [mx, my] = markCanvasPoint(m, name, head);
      return Math.hypot(mx - px, my - py) < 1.2;
    });
    if (mark) return { kind: 'mark', name: mark };
    for (let i = m.head.parts.length - 1; i >= 0; i -= 1) {
      if (shapeContains(m.head.parts[i], lx, ly)) return { kind: 'part', tab: 'head', index: i };
    }
    return null;
  }
  const parts = m.poses[state.tab].parts;
  for (let i = parts.length - 1; i >= 0; i -= 1) {
    const hit = parts[i].shape === 'head' ? m.head.parts.some((p) => shapeContains(p, lx, ly)) : shapeContains(parts[i], px, py);
    if (hit) return { kind: 'part', tab: state.tab, index: i };
  }
  return null;
}

function stagePoint(event) {
  const rect = $('stage').getBoundingClientRect();
  return [(event.clientX - rect.left) / state.zoom, (event.clientY - rect.top) / state.zoom];
}

function bindStage() {
  const stage = $('stage');
  stage.onpointerdown = (event) => {
    const [px, py] = stagePoint(event);
    stage.setPointerCapture(event.pointerId);
    if (state.ref.drag) {
      state.drag = { start: [px, py], ref: state.ref };
      return;
    }
    const hit = pick(px, py);
    if (hit && !sameSelection(hit, state.selection)) select(hit);
    state.drag = hit ? { start: [px, py], base: model(), head: stageHeadTransform() } : null;
  };
  stage.onpointermove = (event) => {
    const [px, py] = stagePoint(event);
    const [lx, ly] = toLocal(stageHeadTransform(), px, py);
    $('coords').textContent = `画布 (${px.toFixed(1)}, ${py.toFixed(1)})　头局部 (${lx.toFixed(1)}, ${ly.toFixed(1)})`;
    const drag = state.drag;
    if (!drag) return;
    const dx = px - drag.start[0];
    const dy = py - drag.start[1];
    if (drag.ref) {
      state.ref = { ...drag.ref, x: drag.ref.x + Math.round(dx * 2) / 2, y: drag.ref.y + Math.round(dy * 2) / 2 };
      renderRefFields();
      drawStage();
      return;
    }
    const next = dragged(drag.base, state.selection, dx, dy, drag.head);
    if (next !== model()) live(next);
  };
  stage.onpointerup = () => {
    state.drag = null;
    settle();
  };
}

// ---------- 按钮 / 快捷键 ----------

function changeParts(update) {
  const sel = state.selection;
  const path = partsPath(sel.tab);
  const { parts, index } = update(getIn(model(), path), sel.index);
  state.selection = index === null ? null : { ...sel, index };
  commit(setIn(model(), path, parts));
}

function nudge(dx, dy) {
  if (!state.selection) return;
  commit(dragged(model(), state.selection, dx, dy, stageHeadTransform()));
}

async function save() {
  try {
    validateModel(model());
  } catch (error) {
    setStatus(`不能保存：${error.message}`, 'error');
    return;
  }
  setStatus('保存中…');
  try {
    const res = await fetch('/api/save', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ model: model() }) });
    const body = await res.json();
    if (!body.success) throw new Error(body.error);
    state.saved = model();
    setStatus(`已保存，生成了 ${body.data.frames} 帧。重启桌宠 App 就能看到。`, 'ok');
  } catch (error) {
    setStatus(`保存失败：${error.message}`, 'error');
  }
}

function bindControls() {
  $('undo').onclick = () => { state.history = undone(state.history); refresh(); };
  $('redo').onclick = () => { state.history = redone(state.history); refresh(); };
  $('reset').onclick = () => { if (confirm('恢复成默认造型？（可以撤销）')) commit(state.defaults); };
  $('save').onclick = save;
  $('export').onclick = () => {
    const link = Object.assign(document.createElement('a'), { download: 'capybara-pose.json', href: URL.createObjectURL(new Blob([JSON.stringify(model(), null, 2)], { type: 'application/json' })) });
    link.click();
    URL.revokeObjectURL(link.href);
  };
  $('part-up').onclick = () => changeParts((parts, i) => ({ parts: withMoved(parts, i, i - 1), index: Math.max(0, i - 1) }));
  $('part-down').onclick = () => changeParts((parts, i) => ({ parts: withMoved(parts, i, i + 1), index: Math.min(parts.length - 1, i + 1) }));
  $('part-dup').onclick = () => changeParts((parts, i) => ({ parts: duplicatedPart(parts, i), index: i + 1 }));
  $('part-del').onclick = () => {
    const part = getIn(model(), [...partsPath(state.selection.tab), state.selection.index]);
    if (part.shape === 'head') { setStatus('头不能删，可以在「头（共用）」里改。', 'error'); return; }
    changeParts((parts, i) => ({ parts: withoutIndex(parts, i), index: null }));
  };
  $('part-add').onclick = () => {
    const path = partsPath(state.tab);
    const parts = getIn(model(), path);
    const id = `blob${parts.length + 1}`;
    const blob = state.tab === 'head'
      ? { id, label: '新椭圆', shape: 'ellipse', ink: 'body', cx: 0, cy: 0, rx: 3, ry: 3, rot: 0 }
      : { id, label: '新椭圆', shape: 'ellipse', ink: 'body', cx: 16, cy: 20, rx: 4, ry: 4, rot: 0 };
    state.selection = { kind: 'part', tab: state.tab, index: parts.length };
    commit(setIn(model(), path, [...parts, blob]));
  };
  $('json-apply').onclick = () => {
    try {
      const value = JSON.parse($('json').value);
      const next = state.tab === 'head' ? { ...model(), head: value } : setIn(model(), ['poses', state.tab], value);
      validateModel(next);
      state.selection = null;
      commit(next);
    } catch (error) {
      setStatus(`JSON 有问题：${error.message}`, 'error');
    }
  };
  $('zoom').onchange = () => { state.zoom = Number($('zoom').value); drawStage(); };
  $('opt-lines').onchange = () => { state.lines = $('opt-lines').checked; drawStage(); };
  document.querySelectorAll('[data-opt]').forEach((input) => {
    input.oninput = () => {
      const key = input.dataset.opt;
      const value = input.type === 'checkbox' ? input.checked : input.type === 'range' ? Number(input.value) : input.value;
      state.opts = { ...state.opts, [key]: value };
      drawStage();
    };
  });
  bindReferenceControls();
  window.addEventListener('keydown', (event) => {
    if (event.target.matches('input, textarea, select')) return;
    const mod = event.metaKey || event.ctrlKey;
    if (mod && event.key.toLowerCase() === 'z') { event.preventDefault(); $(event.shiftKey ? 'redo' : 'undo').click(); return; }
    if (mod && event.key.toLowerCase() === 's') { event.preventDefault(); save(); return; }
    const step = event.shiftKey ? 1 : 0.5;
    const moves = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] };
    if (moves[event.key]) { event.preventDefault(); nudge(...moves[event.key]); }
  });
  window.addEventListener('beforeunload', (event) => {
    if (JSON.stringify(model()) !== JSON.stringify(state.saved)) event.preventDefault();
  });
}

function loadReference(src, name) {
  const image = new Image();
  image.onload = () => {
    // 默认铺满画布宽度，再用滑杆 / 拖动对齐
    const scale = Number(((stageWidth() * 16) / image.naturalWidth).toFixed(3));
    state.ref = { ...state.ref, image, name, scale, x: 0, y: 0 };
    renderRefFields();
    drawStage();
  };
  image.onerror = () => setStatus(`参考图打不开：${name}`, 'error');
  image.src = src;
}

function bindReferenceControls() {
  $('ref-select').onchange = () => {
    const name = $('ref-select').value;
    if (!name) { state.ref = { ...state.ref, image: null, name: '' }; drawStage(); return; }
    loadReference(`/refs/${encodeURIComponent(name)}`, name);
  };
  $('ref-open').onclick = () => $('ref-file').click();
  $('ref-file').onchange = () => {
    const file = $('ref-file').files[0];
    if (file) loadReference(URL.createObjectURL(file), file.name);
  };
  $('ref-flip').onchange = () => { state.ref = { ...state.ref, flip: $('ref-flip').checked }; drawStage(); };
  $('ref-front').onchange = () => { state.ref = { ...state.ref, front: $('ref-front').checked }; drawStage(); };
  $('ref-drag').onchange = () => { state.ref = { ...state.ref, drag: $('ref-drag').checked }; };
  renderRefFields();
}

/** 地址里的 #tab=lie&ref=xxx.jpg 直接打开对应姿势和参考图 */
function applyHash() {
  const params = new URLSearchParams(location.hash.slice(1));
  const tab = params.get('tab');
  const ref = params.get('ref');
  if (ref && [...$('ref-select').options].some((o) => o.value === ref)) {
    $('ref-select').value = ref;
    $('ref-select').onchange();
  }
  if (tab === 'head' || Object.hasOwn(POSE_LABELS, tab ?? '')) selectTab(tab);
  else refresh();
}

async function start() {
  try {
    const [modelRes, refsRes] = await Promise.all([fetch('/api/model'), fetch('/api/refs')]);
    const modelBody = await modelRes.json();
    const refsBody = await refsRes.json();
    if (!modelBody.success) throw new Error(modelBody.error);
    state.history = createHistory(modelBody.data.model);
    state.defaults = modelBody.data.defaults;
    state.saved = modelBody.data.model;
    (refsBody.data?.refs ?? []).forEach((name) => $('ref-select').append(new Option(name, name)));
  } catch (error) {
    setStatus(`加载失败：${error.message}`, 'error');
    return;
  }
  bindControls();
  bindStage();
  applyHash();
  setInterval(() => { state.tick += 1; drawPreviews(); }, 125);
}

start();
