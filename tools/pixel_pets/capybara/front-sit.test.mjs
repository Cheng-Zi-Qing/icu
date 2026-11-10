// 运行: node --test tools/pixel_pets/capybara/
// 正面坐姿（三视图里的正面）：转身时先闪一下这一张
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_MODEL } from './model.mjs';
import { allFrames, GENERATED_DIRECTORIES, renderPose, idleMainOptions } from './render.mjs';
import { HEADWEAR } from './headwear.mjs';
import { FRONT_EYE_ROW, renderFrontSit } from './front-sit.mjs';
import { EYE_LEFT } from './front-head.mjs';

const rowsWith = (grid, ink) => {
  const rows = new Set();
  for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < grid.width; x += 1) if (grid.get(x, y) === ink) rows.add(y);
  return rows;
};
const opaque = (grid) => {
  let minX = Infinity; let maxX = -Infinity; let minY = Infinity; let maxY = -Infinity;
  for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < grid.width; x += 1) {
    if (grid.get(x, y) === 'clear') continue;
    minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  return { minX, maxX, minY, maxY };
};

test('every outfit has a front-facing sit frame for turning around', () => {
  assert.ok(GENERATED_DIRECTORIES.includes('turn'), 'turn/ is rebuilt with the other frames');
  for (const headwear of HEADWEAR) {
    const paths = allFrames(DEFAULT_MODEL, { headwear }).map(([path]) => path);
    assert.ok(paths.includes('turn/front.png'), `${headwear} has turn/front.png`);
  }
});

test('front and side views sit on the same floor and share the eye row', () => {
  const side = renderPose(DEFAULT_MODEL, 'sit', { ...idleMainOptions()[0], headwear: 'orange' });
  const front = renderFrontSit({ headwear: 'orange' });
  assert.equal(opaque(front).maxY, opaque(side).maxY, 'feet on the same row, so turning does not hop');
  assert.ok(Math.abs(opaque(front).minY - opaque(side).minY) <= 1, 'the orange sits at the same height');
  assert.ok(rowsWith(front, 'outline').has(FRONT_EYE_ROW + 1), 'eyes are drawn on the shared eye row');
});

test('the front face is relaxed and expressionless: half-lidded eyes, flat mouth, grass in its mouth', () => {
  const front = renderFrontSit({ headwear: 'orange' });
  // 半眯：眼皮（shade）压在眼睛上一行，没有高光
  for (const x of [EYE_LEFT, EYE_LEFT + 1, 30 - EYE_LEFT, 31 - EYE_LEFT]) {
    assert.equal(front.get(x, FRONT_EYE_ROW), 'shade', `lid over the eye at x ${x}`);
    assert.equal(front.get(x, FRONT_EYE_ROW + 1), 'outline', `eye line at x ${x}`);
  }
  for (const y of [FRONT_EYE_ROW, FRONT_EYE_ROW + 1]) {
    for (let x = 8; x < 24; x += 1) assert.notEqual(front.get(x, y), 'white', 'no sparkle in relaxed eyes');
  }
  // 草从嘴里伸出去，越过左脸颊
  const grass = opaque({ width: 32, height: 32, get: (x, y) => (front.get(x, y) === 'grass' ? 'grass' : 'clear') });
  // 口鼻比脑袋窄一圈（11–20 列），草从嘴角越过口鼻边、垂到脸颊外侧
  assert.ok(grass.minX <= 8 && grass.maxX >= 14, `grass runs from the mouth past the cheek (x ${grass.minX}–${grass.maxX})`);
});

test('the front face and body are symmetric apart from the grass', () => {
  // 头顶装扮本身不对称（橙子的叶子、草帽的系带），从眼睛那行往下比
  const front = renderFrontSit({ headwear: 'straw_hat' });
  const sideInk = new Set(['grass', 'leaf']);
  let mismatches = 0;
  for (let y = FRONT_EYE_ROW; y < 32; y += 1) for (let x = 0; x < 16; x += 1) {
    const a = front.get(x, y); const b = front.get(31 - x, y);
    if (sideInk.has(a) || sideInk.has(b)) continue;
    if (a !== b) mismatches += 1;
  }
  assert.ok(mismatches <= 6, `left and right halves match (${mismatches} pixels differ)`);
});

test('a closed-eye variant exists for blinking mid-turn', () => {
  const closed = renderFrontSit({ headwear: 'orange', eyes: 'closed' });
  assert.notEqual(closed.get(EYE_LEFT, FRONT_EYE_ROW), 'shade', 'no lid when the eyes are shut');
  assert.equal(closed.get(EYE_LEFT, FRONT_EYE_ROW + 1), 'outline');
});

test('every front view uses the same head: turning, edge peek, title bar and work scenes match', async () => {
  const { renderFrontUpright } = await import('./front-peek.mjs');
  const { workSceneFrames } = await import('./front-work.mjs');
  const muzzle = (grid) => {
    const xs = []; const ys = [];
    for (let y = 0; y < 32; y += 1) for (let x = 0; x < 32; x += 1) if (grid.get(x, y) === 'muzzle') { xs.push(x); ys.push(y); }
    return { width: Math.max(...xs) - Math.min(...xs) + 1, height: Math.max(...ys) - Math.min(...ys) + 1 };
  };
  const reference = muzzle(renderFrontSit({}));
  for (const [name, grid] of [['bar peek', renderFrontUpright({})], ['delegate', workSceneFrames('delegate')[0]], ['read', workSceneFrames('read')[6]]]) {
    assert.equal(muzzle(grid).width, reference.width, `${name}: same muzzle width as the turning frame`);
  }
  assert.equal(muzzle(workSceneFrames('delegate')[0]).height, reference.height, 'the bird scene is the very same sitting pose');
});
