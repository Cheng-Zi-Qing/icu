// 头顶装扮：默认橙子，衣柜里可以换成草帽。每个姿势都要画得上
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { DEFAULT_MODEL, PALETTE } from './model.mjs';
import { allFrames } from './render.mjs';
import { HEADWEAR, OUTFIT_HEADWEAR, itemIcon } from './headwear.mjs';
import { writeAssets } from './build.mjs';

const inkCount = (grid, ink) => grid.cells.filter((c) => c === ink).length;
const rowsWith = (grid, ink) => {
  const rows = new Set();
  grid.cells.forEach((c, i) => { if (c === ink) rows.add(Math.floor(i / grid.width)); });
  return [...rows].sort((a, b) => a - b);
};
const columnsWith = (grid, ink) => {
  const cols = new Set();
  grid.cells.forEach((c, i) => { if (c === ink) cols.add(i % grid.width); });
  return [...cols].sort((a, b) => a - b);
};

test('headwear choices: the orange is the default, the straw hat is the first alternative', () => {
  assert.deepEqual(HEADWEAR, ['orange', 'straw_hat']);
  assert.deepEqual(OUTFIT_HEADWEAR, ['straw_hat'], 'only non-default headwear gets its own frame set');
  for (const ink of ['straw', 'strawShade', 'band']) assert.ok(PALETTE[ink], `palette has ${ink}`);
});

test('the default frames still wear the orange and nothing else on the head', () => {
  const frames = new Map(allFrames(DEFAULT_MODEL));
  assert.deepEqual([...frames.keys()], allFrames(DEFAULT_MODEL, { headwear: 'orange' }).map(([n]) => n));
  const sit = frames.get('idle/main/0.png');
  assert.ok(inkCount(sit, 'orange') > 0);
  assert.equal(inkCount(sit, 'straw'), 0);
});

test('straw hat frames have the same names and replace the orange in every head-showing frame', () => {
  const plain = allFrames(DEFAULT_MODEL).map(([n]) => n);
  const hat = allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' });
  assert.deepEqual(hat.map(([n]) => n).filter((n) => !n.startsWith('ui/item_')), plain.filter((n) => !n.startsWith('ui/item_')));
  for (const [name, grid] of hat) {
    if (name.startsWith('ui/item_')) continue;
    assert.equal(inkCount(grid, 'orange'), 0, `${name} should not show the orange`);
  }
  // 被拎起时本来就不戴头顶装扮（掉不下来也不画），所以不在这里
  for (const name of ['idle/main/0.png', 'react/petted_0.png', 'edge/peek_0.png', 'edge/turn_0.png', 'ui/bar_peek.png']) {
    const grid = hat.find(([n]) => n === name)[1];
    assert.ok(inkCount(grid, 'straw') >= 10, `${name} shows the straw hat`);
    assert.ok(inkCount(grid, 'band') >= 3, `${name} shows the hat band`);
  }
});

test('the big straw hat covers the top of the head but leaves the eyes visible (side)', () => {
  const orange = new Map(allFrames(DEFAULT_MODEL)).get('idle/main/0.png');
  const hat = new Map(allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })).get('idle/main/0.png');
  const orangeBottom = Math.max(...rowsWith(orange, 'orange'));
  const brimRow = Math.max(...rowsWith(hat, 'straw'));
  assert.ok(brimRow >= orangeBottom + 2, `the brim comes down over the head (${brimRow} vs orange bottom ${orangeBottom})`);
  const brim = columnsWith(hat, 'straw');
  assert.ok(brim.length >= 18, `the brim is wider than the 16-pixel head (${brim.length})`);
  assert.equal(inkCount(hat, 'white'), inkCount(orange, 'white') - 1, 'the eye shine is still visible (only the orange shine is gone)');
});

test('the big straw hat covers the top of the head but leaves the eyes visible (front)', () => {
  const orange = new Map(allFrames(DEFAULT_MODEL)).get('ui/bar_peek.png');
  const hat = new Map(allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })).get('ui/bar_peek.png');
  const brim = columnsWith(hat, 'straw');
  assert.ok(brim.length >= 20, `the brim sticks out past both sides of the head (${brim.length})`);
  // 正面的脸比侧面短：帽檐压到眼睛正上方那一行（再低就挡眼睛了）
  assert.ok(Math.max(...rowsWith(hat, 'straw')) >= Math.max(...rowsWith(orange, 'orange')) + 1, 'the brim sits low on the head');
  assert.equal(inkCount(hat, 'white'), 2, 'both eye shines stay visible under the brim');
});

test('wardrobe item icons are generated for every headwear', () => {
  const frames = new Map(allFrames(DEFAULT_MODEL));
  for (const kind of HEADWEAR) {
    const icon = frames.get(`ui/item_${kind}.png`);
    assert.ok(icon, `ui/item_${kind}.png exists`);
    assert.deepEqual(icon.cells, itemIcon(kind).cells);
    assert.equal(icon.width, 16);
    assert.equal(icon.height, 16);
  }
  assert.ok(inkCount(itemIcon('straw_hat'), 'straw') > inkCount(itemIcon('straw_hat'), 'band'));
});

test('build writes a full frame set per alternative headwear under outfits/', () => {
  const dir = mkdtempSync(join(tmpdir(), 'capy-outfits-'));
  try {
    writeAssets(DEFAULT_MODEL, dir);
    assert.ok(existsSync(join(dir, 'idle/main/0.png')), 'default set at the root');
    assert.ok(existsSync(join(dir, 'outfits/straw_hat/idle/main/0.png')), 'straw hat set under outfits/');
    assert.ok(existsSync(join(dir, 'outfits/straw_hat/edge/peek_0.png')));
    assert.ok(!existsSync(join(dir, 'outfits/straw_hat/cursor')), 'cursors are shared');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('the straw hat brim curls up at both ends (side, front and wardrobe icon)', () => {
  const side = new Map(allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })).get('idle/main/0.png');
  const front = new Map(allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })).get('ui/bar_peek.png');
  for (const [name, grid] of [['side', side], ['front', front], ['icon', itemIcon('straw_hat')]]) {
    const straw = [];
    grid.cells.forEach((c, i) => { if (c === 'straw' || c === 'strawShade') straw.push([i % grid.width, Math.floor(i / grid.width)]); });
    const xs = straw.map(([x]) => x);
    const lowest = (x) => Math.max(...straw.filter(([px]) => px === x).map(([, y]) => y));
    const brimRow = Math.max(...straw.map(([, y]) => y));
    const left = Math.min(...xs);
    const right = Math.max(...xs);
    assert.ok(lowest(left) < brimRow && lowest(right) < brimRow, `${name}: both brim tips sit above the brim (${lowest(left)}, ${lowest(right)} vs ${brimRow})`);
  }
});

test('the straw hat is big: a wide crown on the side, a tall wide crown from the front', () => {
  const side = new Map(allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })).get('idle/main/0.png');
  const front = new Map(allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })).get('ui/bar_peek.png');
  assert.ok(columnsWith(side, 'band').length >= 12, `side crown is at least 12 wide (${columnsWith(side, 'band').length})`);
  assert.ok(columnsWith(front, 'band').length >= 16, `front crown is as wide as the head (${columnsWith(front, 'band').length})`);
  const frontRows = rowsWith(front, 'straw');
  assert.ok(frontRows.at(-1) - frontRows[0] + 1 >= 7, `front hat is at least 7 rows tall (${frontRows.at(-1) - frontRows[0] + 1})`);
  for (const [name, grid] of allFrames(DEFAULT_MODEL, { headwear: 'straw_hat' })) {
    if (name.startsWith('ui/item_')) continue;
    for (let x = 0; x < grid.width; x += 1) {
      assert.ok(!['straw', 'strawShade', 'band'].includes(grid.get(x, 0)), `${name}: the hat never touches the top of the canvas`);
    }
  }
});

test('a lifted pet keeps its headwear, whole, below the top edge of the canvas', () => {
  for (const [headwear, ink] of [['orange', 'orange'], ['straw_hat', 'straw']]) {
    const frames = new Map(allFrames(DEFAULT_MODEL, { headwear }));
    for (const name of ['drag/hold_0.png', 'drag/dizzy_0_0.png']) {
      const grid = frames.get(name);
      const rows = [];
      for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < grid.width; x += 1) if (grid.get(x, y) === ink) rows.push(y);
      assert.ok(rows.length > 0, `${headwear} is worn in ${name}`);
      assert.ok(Math.min(...rows) >= 2, `${headwear} is not cut off at the top of ${name} (top row ${Math.min(...rows)})`);
    }
  }
});
