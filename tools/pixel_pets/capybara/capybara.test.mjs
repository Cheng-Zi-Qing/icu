// 运行: node --test tools/pixel_pets/capybara/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, existsSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { DEFAULT_MODEL, PALETTE } from './model.mjs';
import { EDGE_BIRD_FLYBY, allFrames, birdVisitOptions, napOptions, pettedOptions, renderPose, resolvePose, yuzuWobbleOptions } from './render.mjs';
import { Grid } from './raster.mjs';
import { renderFrontPeek, renderFrontUpright } from './front-peek.mjs';
import { EYE_LEFT } from './front-head.mjs';
import { OUTFIT_HEADWEAR } from './headwear.mjs';
import { CURSOR_POINT_SIZE, CURSOR_SCALE, CURSOR_SIZE, cursorDefinitions, cursorManifest } from './cursors.mjs';
import { loadModel } from './build.mjs';
import { encodePNG } from './png.mjs';
import { validateModel } from './validate.mjs';
import {
  committed, createHistory, dragged, duplicatedPart, redone, setIn, undone, withMoved, withoutIndex,
} from './editor-state.mjs';
import { createEditorServer } from './server.mjs';

const clone = (value) => JSON.parse(JSON.stringify(value));
const opaqueColumns = (grid) => {
  const columns = new Set();
  for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < grid.width; x += 1) if (grid.get(x, y) !== 'clear') columns.add(x);
  return columns;
};

// ---------- 状态函数 ----------

test('setIn copies along the path and leaves the original untouched', () => {
  const original = { a: { b: [1, 2] }, c: 1 };
  const next = setIn(original, ['a', 'b', 1], 9);
  assert.deepEqual(next, { a: { b: [1, 9] }, c: 1 });
  assert.deepEqual(original, { a: { b: [1, 2] }, c: 1 });
  assert.equal(next.c, original.c);
});

test('list helpers return new lists', () => {
  const list = Object.freeze(['a', 'b', 'c']);
  assert.deepEqual(withMoved(list, 0, 2), ['b', 'c', 'a']);
  assert.equal(withMoved(list, 0, 5), list);
  assert.deepEqual(withoutIndex(list, 1), ['a', 'c']);
});

test('duplicatedPart gives the copy a unique id', () => {
  const parts = DEFAULT_MODEL.poses.sit.parts;
  const index = parts.findIndex((p) => p.id === 'belly');
  const next = duplicatedPart(parts, index);
  assert.equal(next.length, parts.length + 1);
  assert.equal(next[index + 1].id, 'belly2');
  assert.equal(next[index + 1].cx, parts[index].cx + 1);
});

test('dragging a pose part moves it in half-pixel steps', () => {
  const index = DEFAULT_MODEL.poses.lie.parts.findIndex((p) => p.id === 'barrel');
  const next = dragged(DEFAULT_MODEL, { kind: 'part', tab: 'lie', index }, 1.3, -0.2, null);
  assert.equal(next.poses.lie.parts[index].cx, DEFAULT_MODEL.poses.lie.parts[index].cx + 1.5);
  assert.equal(next.poses.lie.parts[index].cy, DEFAULT_MODEL.poses.lie.parts[index].cy);
  assert.equal(next.poses.sit, DEFAULT_MODEL.poses.sit);
});

test('dragging the head entry moves the pose head transform', () => {
  const index = DEFAULT_MODEL.poses.sit.parts.findIndex((p) => p.shape === 'head');
  const next = dragged(DEFAULT_MODEL, { kind: 'part', tab: 'sit', index }, 2, 1, null);
  assert.equal(next.poses.sit.head.x, DEFAULT_MODEL.poses.sit.head.x + 2);
  assert.equal(next.poses.sit.head.y, DEFAULT_MODEL.poses.sit.head.y + 1);
});

test('dragging a head part undoes the head rotation and scale', () => {
  const index = DEFAULT_MODEL.head.parts.findIndex((p) => p.id === 'cheek');
  const transform = { x: 10, y: 10, rot: 90, scale: 2 };
  const next = dragged(DEFAULT_MODEL, { kind: 'part', tab: 'head', index }, 0, 2, transform);
  const before = DEFAULT_MODEL.head.parts[index];
  const after = next.head.parts[index];
  assert.ok(Math.abs(after.cx - (before.cx + 1)) < 1e-6, `cx ${after.cx}`);
  assert.ok(Math.abs(after.cy - before.cy) < 1e-6, `cy ${after.cy}`);
});

test('dragging a derived pose changes its offset only', () => {
  const derived = setIn(DEFAULT_MODEL, ['poses', 'peek'], { width: 32, from: 'lie', offsetX: 9, offsetY: 0 });
  const next = dragged(derived, { kind: 'peek' }, -2, 0.5, null);
  assert.equal(next.poses.peek.offsetX, 7);
  assert.equal(next.poses.peek.offsetY, 0.5);
  assert.equal(next.poses.lie, DEFAULT_MODEL.poses.lie);
});

test('history undo and redo walk back and forth', () => {
  const h0 = createHistory('a');
  const h2 = committed(committed(h0, 'b'), 'c');
  assert.equal(undone(h2).present, 'b');
  assert.equal(undone(undone(h2)).present, 'a');
  assert.equal(redone(undone(h2)).present, 'c');
  assert.equal(committed(h2, 'c'), h2);
  assert.deepEqual(committed(undone(h2), 'd').future, []);
});

// ---------- 校验 ----------

test('default model is valid', () => {
  assert.equal(validateModel(clone(DEFAULT_MODEL)).version, 1);
});

test('validation rejects bad numbers, inks and a missing head', () => {
  const bad = clone(DEFAULT_MODEL);
  bad.poses.lie.parts[0].cx = 'x';
  assert.throws(() => validateModel(bad), /poses\.lie\.parts\[0\]\.cx/);

  const badInk = clone(DEFAULT_MODEL);
  badInk.head.parts[0].ink = 'purple';
  assert.throws(() => validateModel(badInk), /ink/);

  const noHead = clone(DEFAULT_MODEL);
  noHead.poses.sit.parts = noHead.poses.sit.parts.filter((p) => p.shape !== 'head');
  assert.throws(() => validateModel(noHead), /head once/);
});

// ---------- 渲染 ----------

test('quarter turns rotate pixels exactly', () => {
  const g = new Grid(2, 3, ['body', 'shade', 'light', 'dark', 'white', 'blush']);
  assert.deepEqual(g.rotatedQuarter(1).cells, ['white', 'light', 'body', 'blush', 'dark', 'shade']);
  assert.deepEqual(g.rotatedQuarter(-1).cells, ['shade', 'dark', 'blush', 'body', 'light', 'white']);
  assert.equal(g.rotatedQuarter(1).width, 3);
  assert.deepEqual(g.rotatedQuarter(2).cells, [...g.cells].reverse());
  assert.equal(g.rotatedQuarter(4), g);
  assert.deepEqual(g.flippedVertically().cells, ['white', 'blush', 'light', 'dark', 'body', 'shade']);
});

test('a turned derived pose puts the lying ground on the screen edge', () => {
  const turned = setIn(DEFAULT_MODEL, ['poses', 'peek'], { width: 32, from: 'lie', turn: -1, flipY: true, offsetX: 0, offsetY: 0 });
  const lie = renderPose(DEFAULT_MODEL, 'lie', {});
  const peek = renderPose(turned, 'peek', {});
  // 头朝上：趴姿第 x 列 = 探头第 x 行；趴姿最底行（地面）= 探头最右列（屏幕边）
  for (let y = 0; y < 32; y += 1) {
    for (let x = 0; x < 32; x += 1) assert.equal(peek.get(x, y), lie.get(y, x), `(${x}, ${y})`);
  }
});

test('validation rejects odd rotations', () => {
  const bad = setIn(DEFAULT_MODEL, ['poses', 'peek', 'turn'], 3);
  assert.throws(() => validateModel(clone(bad)), /turn/);
  const badFlip = setIn(DEFAULT_MODEL, ['poses', 'peek', 'flipY'], 'yes');
  assert.throws(() => validateModel(clone(badFlip)), /flipY/);
});

test('every frame is 32 rows and the head looks the same size in every pose', () => {
  // ui/item_*.png 是衣柜格子里的 16×16 小图，不是宠物帧
  for (const [path, grid] of allFrames(DEFAULT_MODEL)) if (!path.startsWith('ui/item_')) assert.equal(grid.height, 32, path);
  for (const name of ['sit', 'lie', 'hold']) assert.equal(resolvePose(DEFAULT_MODEL, name).head.scale ?? 1, 1, name);
});

const inkColumns = (grid, inks) => {
  const columns = new Map();
  for (let y = 0; y < grid.height; y += 1) {
    for (let x = 0; x < grid.width; x += 1) {
      if (inks.includes(grid.get(x, y))) columns.set(y, Math.max(columns.get(y) ?? -1, x));
    }
  }
  return columns;
};

test('peek pose lies against the right screen edge', () => {
  const peek = renderPose(DEFAULT_MODEL, 'peek', {});
  assert.equal(peek.width, DEFAULT_MODEL.poses.peek.width);
  assert.ok(opaqueColumns(peek).has(peek.width - 1), 'body touches the screen edge');
});

test('peek keeps the counter-clockwise, head-up turn of the lying pose', () => {
  assert.equal(DEFAULT_MODEL.poses.peek.turn, -1);
  assert.equal(DEFAULT_MODEL.poses.peek.flipY, true);
});

test('turning its head at the edge keeps the head as big as the front peek', () => {
  // 贴边转头（edge/turn_*）和正面探头来回切：头探出屏幕的多少、上下的位置都得对得上，不然一转头像缩了一圈
  const head = (grid) => {
    const columns = [];
    const rows = [];
    for (let y = 0; y < grid.height; y += 1) {
      for (let x = 0; x < grid.width; x += 1) {
        // 嘴里的草不算（叼着的草会伸出头外）；头顶的橙子算，正面、侧面都顶着它
        if (['clear', 'grass'].includes(grid.get(x, y))) continue;
        columns.push(x);
        rows.push(y);
      }
    }
    return { left: Math.min(...columns), right: Math.max(...columns), middle: (Math.min(...rows) + Math.max(...rows)) / 2 };
  };
  const front = head(renderFrontPeek({}));
  // 有脖子伸进屏幕边（不是飘着的一颗头）：贴着屏幕边那一列，肤色占的高度够一段脖子
  const turnedGrid = renderPose(DEFAULT_MODEL, 'peek', {});
  const edgeSkin = Array.from({ length: turnedGrid.height }, (_, y) => turnedGrid.get(turnedGrid.width - 1, y)).filter((ink) => ink === 'body').length;
  assert.ok(edgeSkin >= 8, `a neck runs into the screen edge (${edgeSkin}px tall)`);
  // 背是坐姿那条往后弯的弧：后脑勺下面，身子的左轮廓一路往屏幕边收，越往下收得越快（弯的，不是一根直线、也不是细长脖子）
  const leftmost = (y) => Array.from({ length: turnedGrid.width }, (_, x) => x).find((x) => !['clear', 'orange', 'grass', 'white'].includes(turnedGrid.get(x, y)));
  const orangeRows = Array.from({ length: turnedGrid.height }, (_, y) => y).filter((y) => Array.from({ length: turnedGrid.width }, (_, x) => turnedGrid.get(x, y)).includes('orange'));
  const backRows = Array.from({ length: turnedGrid.height - Math.max(...orangeRows) - 1 }, (_, i) => Math.max(...orangeRows) + 1 + i);
  const back = backRows.map(leftmost);
  assert.ok(back.every((x, i) => i === 0 || x >= back[i - 1]), `the back keeps curving toward the edge (${back})`);
  const half = Math.floor(back.length / 2);
  const upper = back[half] - back[0];
  const lower = back[back.length - 1] - back[half];
  assert.ok(lower > upper, `it bends: steeper lower down than right under the head (${upper} then ${lower}: ${back})`);
  assert.ok(back[back.length - 1] >= turnedGrid.width - 8, `and tucks behind the screen edge at the bottom (${back})`);
  const green = (grid) => grid.cells.filter((ink) => ink === 'grass').length;
  assert.equal(green(turnedGrid), green(renderFrontPeek({})), 'only the leaf on the orange is green: no grass in the mouth, like the front peek');
  for (const opts of [{}, { blink: true }]) {
    // 只量头：同样的位置参数，不带后面那段背
    const headOnly = { ...DEFAULT_MODEL, poses: { ...DEFAULT_MODEL.poses, peek: { ...DEFAULT_MODEL.poses.peek, keepParts: [] } } };
    const turned = head(renderPose(headOnly, 'peek', opts));
    assert.ok(Math.abs(turned.left - front.left) <= 2, `sticks out as far as the front face (turned ${turned.left}, front ${front.left})`);
    assert.ok(turned.right >= front.right - 3, `the head sits by the screen edge (turned ${turned.right}, front ${front.right})`);
    assert.ok(Math.abs(turned.middle - front.middle) <= 1, `same height on screen (turned ${turned.middle}, front ${front.middle})`);
    assert.ok(new Set(renderPose(DEFAULT_MODEL, 'peek', opts).cells).has('orange'), 'orange visible');
  }
});

test('the fruit on the head is an orange, not a yellow yuzu', () => {
  const sit = new Set(renderPose(DEFAULT_MODEL, 'sit', {}).cells);
  assert.ok(sit.has('orange'), 'head fruit should use the orange ink');
  assert.ok(!sit.has('star'), 'yellow star ink is only for stars and sparkles now');
  assert.equal(PALETTE.orange, '#F08A24');
});

test('peek reach frame pokes out a little further', () => {
  const rest = Math.min(...opaqueColumns(renderPose(DEFAULT_MODEL, 'peek', {})));
  const reach = Math.min(...opaqueColumns(renderPose(DEFAULT_MODEL, 'peek', { reach: true })));
  assert.equal(rest - reach, DEFAULT_MODEL.poses.peek.reachPixels);
});

const leftmostColumn = (grid) => {
  for (let x = 0; x < grid.width; x += 1) {
    for (let y = 0; y < grid.height; y += 1) if (grid.get(x, y) !== 'clear') return x;
  }
  return -1;
};
const inkCount = (grid, ink) => grid.cells.filter((c) => c === ink).length;

test('front peek lies flush against the right screen edge in every frame', () => {
  for (const opts of [{}, { blink: true }, { reach: true }]) {
    const peek = renderFrontPeek(opts);
    assert.equal(peek.width, 32);
    assert.equal(peek.height, 32);
    assert.ok(opaqueColumns(peek).has(31), `paws touch the screen edge (${JSON.stringify(opts)})`);
  }
});

test('front peek shows the whole face: orange, both cheeks and both eyes', () => {
  const peek = renderFrontPeek({});
  assert.ok(inkCount(peek, 'orange') > 0, 'orange on the head');
  assert.ok(inkCount(peek, 'blush') >= 4, 'two blushing cheeks');
  // 眼睛和侧面一样半眯：眼皮（shade）压在眼线上面，两只都在
  const upright = renderFrontUpright({});
  const eyeRow = lidRow(upright);
  assert.ok(eyeRow > 0, 'both eyes are there');
});

/** 两只眼睛的眼皮那一行（左右两只眼皮、下面一行是眼线）；找不到返回 -1 */
function lidRow(grid) {
  const right = 31 - EYE_LEFT - 1;
  for (let y = 0; y < 31; y += 1) {
    const lid = [EYE_LEFT, EYE_LEFT + 1, right, right + 1].every((x) => grid.get(x, y) === 'shade' && grid.get(x, y + 1) === 'outline');
    if (lid) return y;
  }
  return -1;
}

test('front peek head top points into the screen (turned 90 degrees)', () => {
  const peek = renderFrontPeek({});
  const orangeColumns = [];
  peek.cells.forEach((c, i) => { if (c === 'orange') orangeColumns.push(i % 32); });
  assert.ok(Math.max(...orangeColumns) < 31 - 8, 'the orange sits away from the edge');
  assert.ok(Math.min(...orangeColumns) <= leftmostColumn(peek) + 2, 'the orange is the part sticking out furthest');
});

test('front peek head is about as big as the side head-turn frame', () => {
  const size = (g) => { const c = opaqueColumns(g); return Math.max(...c) - Math.min(...c) + 1; };
  const rows = (g) => { const r = []; g.cells.forEach((c, i) => { if (c !== 'clear') r.push(Math.floor(i / 32)); }); return Math.max(...r) - Math.min(...r) + 1; };
  const front = renderFrontPeek({});
  const side = renderPose(DEFAULT_MODEL, 'peek', {});
  assert.ok(size(front) - size(side) <= 6, `sticks out about as far (only the orange on top adds a few pixels) (${size(front)} vs ${size(side)})`);
  // 侧面下面还连着一段背（弯进屏幕边），不比整体高度；头顶对齐就行（头的位置另有测试）
  const top = (g) => Math.min(...g.cells.flatMap((c, i) => (c !== 'clear' ? [Math.floor(i / 32)] : [])));
  assert.ok(Math.abs(top(front) - top(side)) <= 1, `the heads start at the same height (${top(front)} vs ${top(side)})`);
});

test('front peek blink closes the eyes and reach pokes out one pixel further', () => {
  assert.equal(lidRow(renderFrontUpright({ blink: true })), -1, 'eyes shut while blinking');
  assert.equal(leftmostColumn(renderFrontPeek({})) - leftmostColumn(renderFrontPeek({ reach: true })), 1);
});

test('front peek flinch squeezes the eyes shut and ducks one pixel toward the edge', () => {
  const rest = renderFrontPeek({});
  const flinch = renderFrontPeek({ flinch: true });
  assert.equal(leftmostColumn(flinch) - leftmostColumn(rest), 1, 'the head sinks one pixel behind the edge');
  assert.equal(inkCount(flinch, 'white'), 1, 'no eye highlights, only the orange shine');
  assert.ok(opaqueColumns(flinch).has(31), 'the paws still hold the edge');
  const eyeInk = (g) => inkCount(g, 'outline');
  assert.notDeepEqual(flinch.cells, renderFrontPeek({ blink: true }).cells, 'squeezed eyes are not a plain blink');
  assert.ok(eyeInk(flinch) > 0);
});

const edgeNames = [
  'peek_0.png', 'peek_1.png', 'peek_2.png', 'peek_3.png',
  'look_left.png', 'look_right.png', 'bird_0.png', 'bird_1.png', 'bird_2.png',
  'turn_0.png', 'turn_1.png',
];

test('edge frames include frontal glances and a flyby, keeping the legacy turn pair', () => {
  const names = allFrames(DEFAULT_MODEL).map(([name]) => name).filter((n) => n.startsWith('edge/'));
  assert.deepEqual(names, edgeNames.map((name) => `edge/${name}`));
});

const birdPixels = (grid) => grid.cells.flatMap((ink, j) => ['bird', 'birdWing', 'star'].includes(ink)
  ? [[j % grid.width, Math.floor(j / grid.width), ink]] : []);

test('front peek head turn: look moves the whole head one column, gaze turns the face, paws and outline stay', () => {
  for (const headwear of ['orange', 'straw_hat']) {
    const rest = renderFrontPeek({ headwear });
    const up = renderFrontPeek({ headwear, gaze: -1 });
    const down = renderFrontPeek({ headwear, gaze: 1 });
    // 转脸只动轮廓里面的五官，脑袋外形（哪些格子有颜色）不变
    const shape = (grid) => grid.cells.map((ink) => ink !== 'clear');
    assert.deepEqual(shape(up), shape(rest), `${headwear}: turning the face keeps the head outline`);
    assert.notDeepEqual(up.cells, rest.cells, `${headwear}: turning the face is visible`);
    // 眼睛高光：往上看比往下看高两行（各挪一格），左右不动
    const whites = (grid) => grid.cells.flatMap((ink, j) => ink === 'white' ? [[j % 32, Math.floor(j / 32)]] : []);
    // 头饰上的高光不算，只看眼睛里的
    const restWhites = new Set(whites(rest).map(String));
    const eyeWhites = (grid) => whites(grid).filter((point) => !restWhites.has(String(point)));
    assert.equal(eyeWhites(up).length, 2, `${headwear}: both watching eyes are open`);
    assert.deepEqual(eyeWhites(up), eyeWhites(down).map(([x, y]) => [x, y - 2]), `${headwear}: gaze -1 turns the face up on screen`);
    for (const look of [-1, 1]) {
      const glance = renderFrontPeek({ headwear, look, gaze: -1 });
      for (let y = 0; y < 32; y += 1) for (let x = 0; x < 32; x += 1) {
        if (rest.tagAt(x, y) === 'paw') {
          assert.equal(glance.get(x, y), rest.get(x, y), `paw stays at ${x},${y}`);
          assert.equal(glance.tagAt(x, y), 'paw');
        }
      }
      // 整颗头（连五官、头饰）在屏幕上只左右挪一格；最后七列被不动的爪子描边盖着，不比
      for (let y = 0; y < 32; y += 1) for (let x = 1; x < 25; x += 1) {
        assert.equal(glance.get(x, y), up.get(x - look, y), `${headwear}: horizontal look ${look} at ${x},${y}`);
      }
    }
  }
});

test('edge bird flies upright over the head toward the screen edge while the capybara turns to watch it', () => {
  for (const headwear of ['orange', 'straw_hat']) {
    const frames = new Map(allFrames(DEFAULT_MODEL, { headwear }));
    const centers = [];
    EDGE_BIRD_FLYBY.forEach(({ look }, i) => {
      const flyby = frames.get(`edge/bird_${i}.png`);
      assert.ok(flyby, `bird ${i} exists for ${headwear}`);
      // 水豚：抬头看着，头跟着小鸟挪；小鸟不压到水豚身上，爪子不动
      const base = renderFrontPeek({ headwear, look, gaze: -1 });
      for (let j = 0; j < base.cells.length; j += 1) {
        if (flyby.cells[j] === base.cells[j]) continue;
        const [x, y] = [j % 32, Math.floor(j / 32)];
        assert.equal(base.cells[j], 'clear', `${headwear}: bird stays clear of pet at ${x},${y}`);
        // 连小鸟的描边都不贴着水豚或帽子
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          assert.equal(base.get(x + dx, y + dy), 'clear', `${headwear}: bird ${i} brushes the pet at ${x + dx},${y + dy}`);
        }
      }
      assert.deepEqual(flyby.tags.flatMap((tag, j) => tag === 'paw' ? [j] : []), base.tags.flatMap((tag, j) => tag === 'paw' ? [j] : []));
      // 小鸟正着飞（不跟着头转 90°）：横着比竖着宽，嘴朝它飞去的屏幕边（右边），整只在头顶上方
      const points = birdPixels(flyby);
      assert.ok(points.some(([, , ink]) => ink === 'birdWing'), `bird ${i} flaps`);
      const xs = points.map(([x]) => x);
      const ys = points.map(([, y]) => y);
      assert.ok(Math.max(...xs) - Math.min(...xs) > Math.max(...ys) - Math.min(...ys), `bird ${i} is upright, not turned with the head`);
      const beak = points.find(([, , ink]) => ink === 'star');
      assert.equal(beak[0], Math.max(...xs), `bird ${i} faces the screen edge it flies toward`);
      for (const [x, y] of points) {
        for (let below = 0; below <= y; below += 1) assert.equal(base.get(x, below), 'clear', `${headwear}: bird ${i} flies above the pet in column ${x}`);
      }
      centers.push(xs.reduce((sum, x) => sum + x, 0) / xs.length);
    });
    assert.ok(centers[0] < centers[1] && centers[1] < centers[2], `${headwear}: the bird crosses toward the edge (${centers})`);
    assert.ok(centers[2] >= 24, `${headwear}: the last frame reaches the screen edge it flies out of`);
    const looks = EDGE_BIRD_FLYBY.map(({ look }) => look);
    assert.deepEqual(looks, [...looks].sort((a, b) => a - b), 'the head follows the bird the same way it flies');
    assert.ok(looks[0] < looks[2], 'the head really turns while the bird crosses');
  }
});

test('edge PNGs match the Swift enum and generated 32px frames for both headwear sets', () => {
  const script = readFileSync(new URL('../../../apps/macos-shell/Sources/ICUShell/Pet/Edge/PetPeekScript.swift', import.meta.url), 'utf8');
  const files = [...script.matchAll(/return "([^"]+\.png)"/g)].map((match) => match[1]);
  assert.deepEqual([...files].sort(), [...edgeNames].sort(), 'Swift and generator list the same frames');
  for (const headwear of ['orange', 'straw_hat']) {
    const root = headwear === 'orange' ? '../../../assets/pets/capybara/' : '../../../assets/pets/capybara/outfits/straw_hat/';
    for (const [name, grid] of allFrames(loadModel(), { headwear }).filter(([name]) => name.startsWith('edge/'))) {
      assert.equal(grid.width, 32, name);
      assert.equal(grid.height, 32, name);
      const png = readFileSync(new URL(root + name, import.meta.url));
      assert.equal(png.readUInt32BE(16), 32, name);
      assert.equal(png.readUInt32BE(20), 32, name);
      assert.deepEqual(png, encodePNG(grid), `${headwear}/${name} is up to date`);
    }
  }
});

test('settings title bar decoration is the upright front peek with paws on the bottom edge', () => {
  const frames = new Map(allFrames(DEFAULT_MODEL));
  const bar = frames.get('ui/bar_peek.png');
  assert.ok(bar, 'ui/bar_peek.png is generated');
  assert.deepEqual(bar.cells, renderFrontUpright({}).cells);
  const bottom = Array.from({ length: 32 }, (_, x) => bar.get(x, 31)).filter((c) => c !== 'clear');
  assert.ok(bottom.length >= 6, 'paws rest on the bottom edge');
});

test('lying pose is long and low', () => {
  const lie = renderPose(DEFAULT_MODEL, 'lie', { props: false });
  const columns = opaqueColumns(lie);
  const rows = new Set();
  for (let y = 0; y < lie.height; y += 1) for (let x = 0; x < lie.width; x += 1) if (lie.get(x, y) !== 'clear') rows.add(y);
  const width = Math.max(...columns) - Math.min(...columns) + 1;
  const height = Math.max(...rows) - Math.min(...rows) + 1;
  assert.ok(width / height >= 1.8, `width ${width} height ${height}`);
});

// ---------- 互动 / 打盹帧 ----------

const framesByPath = () => new Map(allFrames(DEFAULT_MODEL));
const cellsDiffering = (a, b) => {
  const cells = [];
  for (let y = 0; y < a.height; y += 1) for (let x = 0; x < a.width; x += 1) if (a.get(x, y) !== b.get(x, y)) cells.push([x, y]);
  return cells;
};
const eyeRegion = (cells) => cells.filter(([x, y]) => x >= 9 && x <= 15 && y >= 6 && y <= 11);

test('action frames exist, are 32x32 and keep the sitting silhouette', () => {
  const frames = framesByPath();
  const expected = [
    ...pettedOptions().map((_, i) => `react/petted_${i}.png`),
    ...napOptions().map((_, i) => `sleep/nap_${i}.png`),
    'sleep/doze_0.png',
    'sleep/wake_0.png',
  ];
  for (const path of expected) {
    const grid = frames.get(path);
    assert.ok(grid, `${path} is generated`);
    assert.equal(grid.width, 32, path);
    assert.equal(grid.height, 32, path);
  }
});

test('petted frames squint happily and float a heart that never covers the pet', () => {
  for (const opts of pettedOptions()) {
    const plain = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0, earTwitch: opts.earTwitch });
    const petted = renderPose(DEFAULT_MODEL, 'sit', opts);
    const changed = cellsDiffering(plain, petted);
    assert.ok(eyeRegion(changed).length > 0, 'eye changes to a happy squint');
    const outsideEye = changed.filter((cell) => !eyeRegion([cell]).length);
    for (const [x, y] of outsideEye) assert.equal(plain.get(x, y) === 'clear' || plain.get(x, y) === 'outline', true, `heart at ${x},${y} sits beside the pet`);
    assert.ok(new Set(petted.cells).has('blush') && outsideEye.some(([x, y]) => petted.get(x, y) === 'blush'), 'a pink heart shows up');
  }
});

test('nap frames keep the eyes shut, breathe slowly and drift z marks above the back', () => {
  const blink = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0, blink: true, nod: true });
  const options = napOptions();
  assert.ok(options.some((o) => o.inhale) && options.some((o) => !o.inhale), 'breathes while sleeping');
  const zFrames = options.filter((o) => o.zzz !== null && o.zzz !== undefined).length;
  assert.ok(zFrames >= options.length / 2, 'z marks show most of the time');
  for (const opts of options) {
    assert.equal(opts.blink, true, 'eyes stay shut');
    const nap = renderPose(DEFAULT_MODEL, 'sit', opts);
    const base = renderPose(DEFAULT_MODEL, 'sit', { ...opts, zzz: null });
    for (const [x, y] of cellsDiffering(base, nap)) {
      assert.ok(base.get(x, y) === 'clear' || base.get(x, y) === 'outline', `z mark at ${x},${y} sits beside the pet`);
    }
  }
  assert.deepEqual(eyeRegion(cellsDiffering(blink, renderPose(DEFAULT_MODEL, 'sit', { ...options[0], inhale: false, zzz: null }))), []);
});

test('waking up shows open eyes and a little exclamation mark', () => {
  const frames = framesByPath();
  const wake = frames.get('sleep/wake_0.png');
  const open = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 });
  const extra = cellsDiffering(open, wake);
  assert.ok(extra.length > 0, 'exclamation mark drawn');
  for (const [x, y] of extra) assert.ok(open.get(x, y) === 'clear' || open.get(x, y) === 'outline', `mark at ${x},${y} sits beside the pet`);
});

// ---------- 待机小动作 ----------

const withoutExtras = (opts) => ({ ...opts, bird: null, eyes: undefined, yuzuShift: 0 });

test('idle action frames are generated at 32x32', () => {
  const frames = framesByPath();
  const expected = [
    ...yuzuWobbleOptions().map((_, i) => `idle_act/wobble_${i}.png`),
    ...birdVisitOptions().map((_, i) => `idle_act/bird_${i}.png`),
  ];
  for (const path of expected) {
    const grid = frames.get(path);
    assert.ok(grid, `${path} is generated`);
    assert.equal(grid.width, 32, path);
    assert.equal(grid.height, 32, path);
  }
});

test('yuzu wobbles left and right while the eyes look up at it', () => {
  const options = yuzuWobbleOptions();
  const shifts = new Set(options.map((o) => o.yuzuShift));
  assert.ok(shifts.has(-1) && shifts.has(1) && shifts.has(0), 'tips both ways and settles');
  assert.equal(options.at(-1).yuzuShift, 0, 'ends with the yuzu back in place');
  assert.ok(options.some((o) => o.eyes === 'up'), 'looks up at the yuzu');
  const still = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 });
  const tipped = renderPose(DEFAULT_MODEL, 'sit', options.find((o) => o.yuzuShift === 1));
  const moved = cellsDiffering(still, tipped).filter(([, y]) => y <= 5);
  assert.ok(moved.length > 0, 'yuzu pixels move');
});

test('the visiting bird flies in, perches on the head without covering the pet and flies off', () => {
  const options = birdVisitOptions();
  const birds = options.map((o) => o.bird);
  assert.ok(birds[0] && birds[0].pose !== 'sit', 'arrives flying');
  assert.ok(birds.at(-1) === null || birds.at(-1).pose !== 'sit', 'leaves flying');
  assert.ok(birds.filter((b) => b && b.pose === 'sit').length >= 6, 'stays a moment');
  assert.ok(options.some((o) => o.eyes === 'up'), 'the capybara looks up at its visitor');
  for (const opts of options) {
    if (!opts.bird) continue;
    const plain = renderPose(DEFAULT_MODEL, 'sit', withoutExtras(opts));
    const visited = renderPose(DEFAULT_MODEL, 'sit', { ...opts, eyes: undefined });
    const birdCells = cellsDiffering(plain, visited);
    assert.ok(birdCells.length > 0, 'bird drawn');
    for (const [x, y] of birdCells) {
      assert.ok(plain.get(x, y) === 'clear' || plain.get(x, y) === 'outline', `bird at ${x},${y} sits beside / on top of the pet`);
    }
    // 刚从画面外飞进来时可能只露出翅膀
    assert.ok(birdCells.some(([x, y]) => ['bird', 'birdWing'].includes(visited.get(x, y))), 'bird has its own colors');
  }
});

// ---------- 光标 ----------

test('Kenney cursor masks and hot spots match the selected source tiles', () => {
  const expected = {
    pat: { hotSpot: [7, 5], rows: [
      '................', '................', '....XXXXXXXXX...', '...XXXXXXXXXXX..',
      '..XXX#X##X##XXX.', '..XX#########XX.', '..XX#########XX.', '.XXXX########XXX',
      '.XX###########XX', '.XX###########XX', '.XX###########XX', '.XXX##########XX',
      '..XXXX#######XXX', '...XXXX#####XXX.', '.....XXXXXXXXX..', '......XXXXXXX...',
    ] },
    tickle: { hotSpot: [4, 3], rows: [
      '......XXXX......', '...XXXXXXXXXX...', '..XXXXX##XXXXX..', '..XX##X##X##XX..',
      '..XX##X##X##XXX.', '..XX###X##X##XX.', '..XX#########XX.', '.XXXX########XXX',
      'XXXXX#########XX', 'XX############XX', 'XX############XX', 'XXXX##########XX',
      '.XXXXX#######XXX', '...XXXX#####XXX.', '.....XXXXXXXXX..', '......XXXXXXX...',
    ] },
    grabbing: { hotSpot: [8, 7], rows: [
      '................', '................', '................', '....XXXXXXXXXX..',
      '...XXXXXXXXXXXX.', '..XXX##X##X##XX.', '.XXXX########XXX', '.XX###########XX',
      '.XX###########XX', '.XX###########XX', '.XXX##########XX', '..XXX########XXX',
      '...XX########XX.', '...XXX######XXX.', '....XXXXXXXXXX..', '.....XXXXXXXX...',
    ] },
    poke: { hotSpot: [3, 2], rows: [
      '..XXX...........', '.XXXXX..........', 'XXX#XXXXXX......', 'XX###XXXXXXX....',
      'XX#######XXXX...', 'XXX########XXX..', 'XXXX########XX..', 'XX##X#######XXX.',
      'XX###########XXX', 'XXX###########XX', '.XXX##########XX', '..XXXXXX######XX',
      '...XXXXX#####XXX', '......XX###XXXX.', '......XXXXXXXX..', '.......XXXXX....',
    ] },
    grab: { hotSpot: [8, 3], rows: [
      '.......XXXX.....', '....XXXXXXXXXX..', '...XXXXX##XXXXX.', '...XX##X##X##XX.',
      '...XX##X##X##XX.', '.XXXX##X##X##XX.', 'XXXXX########XXX', 'XX##X#########XX',
      'XX############XX', 'XXX###########XX', '.XXX##########XX', '..XXX########XXX',
      '...XX########XX.', '...XXX######XXX.', '....XXXXXXXXXX..', '.....XXXXXXXX...',
    ] },
  };
  const definitions = cursorDefinitions();
  assert.deepEqual(Object.keys(definitions).sort(), Object.keys(expected).sort());
  for (const [name, { rows, hotSpot }] of Object.entries(expected)) {
    const { grid } = definitions[name];
    for (const row of rows) assert.equal(row.length, CURSOR_SIZE, `${name}: source row width`);
    assert.equal(grid.cells.length, 256, `${name}: 16x16 grid cells`);
    assert.deepEqual(definitions[name].hotSpot, hotSpot, `${name}: selected hot spot`);
    assert.deepEqual(Array.from({ length: CURSOR_SIZE }, (_, y) => Array.from({ length: CURSOR_SIZE }, (_, x) => {
      const ink = grid.get(x, y);
      return ink === 'clear' ? '.' : ink === 'outline' ? 'X' : ink === 'white' ? '#' : '?';
    }).join('')), rows, `${name}: Kenney source mask`);
    assert.equal(grid.get(...hotSpot), 'white', `${name}: hot spot is a source white pixel`);
  }
});

test('Kenney cursor masks retain their 16x16 white fill and dark outline', () => {
  const definitions = cursorDefinitions();
  assert.deepEqual(Object.keys(definitions).sort(), ['grab', 'grabbing', 'pat', 'poke', 'tickle']);
  for (const [name, { grid, hotSpot }] of Object.entries(definitions)) {
    assert.equal(grid.width, CURSOR_SIZE, name);
    assert.equal(grid.height, CURSOR_SIZE, name);
    assert.equal(grid.get(...hotSpot), 'white', `${name}: hot spot sits on the hand`);
    assert.ok(grid.cells.includes('white'), `${name}: white hand fill`);
    assert.ok(grid.cells.includes('outline'), `${name}: original dark outline`);
    assert.ok(grid.cells.every((ink) => ['clear', 'white', 'outline'].includes(ink)), `${name}: original black/white palette only`);
  }
});

test('cursor masks remain distinct', () => {
  const entries = Object.entries(cursorDefinitions());
  for (let i = 0; i < entries.length; i += 1) {
    for (let j = i + 1; j < entries.length; j += 1) {
      assert.notDeepEqual(entries[i][1].grid.cells, entries[j][1].grid.cells, `${entries[i][0]} and ${entries[j][0]} use different Kenney tiles`);
    }
  }
});

test('cursor manifest lists every cursor with its hot spot and size', () => {
  const manifest = cursorManifest();
  assert.equal(manifest.pixelSize, CURSOR_SIZE);
  assert.equal(manifest.pointSize, CURSOR_POINT_SIZE);
  for (const [name, { hotSpot }] of Object.entries(cursorDefinitions())) {
    assert.deepEqual(manifest.cursors[name], { file: `${name}.png`, hotSpot });
  }
});

test('cursor generated resources match the manifest and 48px PNG exports', () => {
  const directory = new URL('../../../assets/pets/capybara/cursor/', import.meta.url);
  const manifest = JSON.parse(readFileSync(new URL('cursors.json', directory), 'utf8'));
  assert.deepEqual(manifest, cursorManifest());
  assert.equal(CURSOR_SCALE, 3);
  assert.equal(CURSOR_POINT_SIZE, 24);
  for (const [name, { grid }] of Object.entries(cursorDefinitions())) {
    const png = readFileSync(new URL(manifest.cursors[name].file, directory));
    assert.equal(png.readUInt32BE(16), 48, `${name}: PNG width`);
    assert.equal(png.readUInt32BE(20), 48, `${name}: PNG height`);
    assert.deepEqual(png, encodePNG(grid, { scale: CURSOR_SCALE }), `${name}: resource matches pixels`);
  }
});

// ---------- 服务 ----------

async function withServer(run) {
  const dir = mkdtempSync(join(tmpdir(), 'capy-editor-'));
  const refs = join(dir, 'refs');
  const { mkdirSync } = await import('node:fs');
  mkdirSync(refs);
  writeFileSync(join(refs, 'one.png'), 'png-bytes');
  writeFileSync(join(dir, 'secret.txt'), 'nope');
  const server = createEditorServer({ modelPath: join(dir, 'pose.json'), assetsDir: join(dir, 'assets'), refsDir: refs });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await run(base, dir);
  } finally {
    server.close();
    rmSync(dir, { recursive: true, force: true });
  }
}

test('server serves the model, the editor and reference images only', async () => {
  await withServer(async (base) => {
    const model = await (await fetch(`${base}/api/model`)).json();
    assert.equal(model.success, true);
    assert.equal(model.data.saved, false);
    assert.equal((await fetch(`${base}/`)).status, 200);
    assert.deepEqual((await (await fetch(`${base}/api/refs`)).json()).data.refs, ['one.png']);
    assert.equal((await fetch(`${base}/refs/one.png`)).status, 200);
    assert.equal((await fetch(`${base}/refs/..%2Fsecret.txt`)).status, 404);
    assert.equal((await fetch(`${base}/server.mjs`)).status, 404);
    assert.equal((await fetch(`${base}/pose.json`)).status, 404);
  });
});

test('saving validates, writes pose.json and regenerates frames', async () => {
  await withServer(async (base, dir) => {
    const post = (body) => fetch(`${base}/api/save`, { method: 'POST', headers: { 'content-type': 'application/json' }, body });
    const bad = await post(JSON.stringify({ model: { version: 2 } }));
    assert.equal(bad.status, 400);
    assert.equal(existsSync(join(dir, 'pose.json')), false);
    assert.equal((await post('not json')).status, 400);

    const edited = setIn(DEFAULT_MODEL, ['poses', 'peek', 'offsetX'], 7);
    const res = await (await post(JSON.stringify({ model: edited }))).json();
    assert.equal(res.success, true);
    const outfitFrames = OUTFIT_HEADWEAR.reduce((n, headwear) => n + allFrames(DEFAULT_MODEL, { headwear }).length, 0);
    assert.equal(res.data.frames, allFrames(DEFAULT_MODEL).length + outfitFrames);
    assert.equal(JSON.parse(readFileSync(join(dir, 'pose.json'), 'utf8')).poses.peek.offsetX, 7);
    assert.ok(existsSync(join(dir, 'assets/edge/peek_0.png')));
    assert.ok(existsSync(join(dir, 'assets/base.png')));
    assert.ok(existsSync(join(dir, 'assets/cursor/pat.png')), 'pixel cursors are exported with the frames');
    assert.deepEqual(JSON.parse(readFileSync(join(dir, 'assets/cursor/cursors.json'), 'utf8')), cursorManifest());

    const reloaded = await (await fetch(`${base}/api/model`)).json();
    assert.equal(reloaded.data.saved, true);
    assert.equal(reloaded.data.model.poses.peek.offsetX, 7);
  });
});
