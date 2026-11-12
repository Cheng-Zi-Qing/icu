// 运行: node --test tools/pixel_pets/capybara/
// 被戳不同部位的反应
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_MODEL } from './model.mjs';
import { allFrames, renderPose } from './render.mjs';
import { OUTFIT_HEADWEAR } from './headwear.mjs';
import { POKE_REACTIONS, pokeReactionDefinitions, pokeReactionFrames } from './poke-reactions.mjs';

const sit = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 });
const frames = (name) => pokeReactionFrames(name, DEFAULT_MODEL);
const count = (grid, ink) => grid.cells.filter((cell) => cell === ink).length;
const topmost = (grid, ink, maxX = grid.width) => {
  for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < maxX; x += 1) if (grid.get(x, y) === ink) return y;
  return Infinity;
};
/** 鼻垫：脸最左边那块深色（耳朵里面也是深色，所以只看左边几列） */
const noseTop = (grid) => topmost(grid, 'dark', 7);
/** 嘴里叼的草（头顶橙子的叶子也是草绿色，只数嘴边那块） */
const mouthGrass = (grid) => {
  let n = 0;
  for (let y = 12; y < 24; y += 1) for (let x = 0; x < 8; x += 1) if (grid.get(x, y) === 'grass') n += 1;
  return n;
};

test('five poke reactions, each a few beats long with every key frame used', () => {
  assert.deepEqual(POKE_REACTIONS, ['tickle', 'annoyed', 'sneeze', 'startled', 'grumpy']);
  const definitions = pokeReactionDefinitions();
  for (const name of POKE_REACTIONS) {
    const { fps, keys, order } = definitions[name];
    const seconds = order.length / fps;
    assert.ok(seconds >= 1.2 && seconds <= 3.5, `${name} lasts ${seconds.toFixed(1)}s (want 1.2-3.5s: long enough to read, short enough to poke again)`);
    assert.equal(new Set(order).size, keys.length, `${name}: every key frame is used`);
    for (const grid of frames(name)) {
      assert.equal(grid.width, 32);
      assert.equal(grid.height, 32);
    }
  }
});

test('reaction frames ship with every outfit', () => {
  const definitions = pokeReactionDefinitions();
  const expected = POKE_REACTIONS.flatMap((name) => definitions[name].order.map((_, i) => `react/${name}_${i}.png`));
  for (const headwear of [undefined, ...OUTFIT_HEADWEAR]) {
    const paths = new Set(allFrames(DEFAULT_MODEL, headwear ? { headwear } : {}).map(([path]) => path));
    for (const path of expected) assert.ok(paths.has(path), `${path} is generated (${headwear ?? 'default'})`);
  }
});

test('the pet stays the same size and inside the canvas while it reacts', () => {
  const FUR = new Set(['body', 'shade', 'light', 'muzzle']);
  const fur = (grid) => grid.cells.filter((ink) => FUR.has(ink)).length;
  const edgeInk = (grid) => {
    let n = 0;
    for (let y = 0; y < 32; y += 1) for (const x of [0, 31]) if (FUR.has(grid.get(x, y)) || grid.get(x, y) === 'outline') n += 1;
    return n;
  };
  for (const name of POKE_REACTIONS) {
    for (const grid of frames(name)) {
      const ratio = fur(grid) / fur(sit);
      assert.ok(ratio >= 0.9 && ratio <= 1.1, `${name}: body is ${Math.round(ratio * 100)}% of sitting`);
      assert.ok(edgeInk(grid) <= edgeInk(sit), `${name}: nothing is pushed off the side of the canvas`);
    }
  }
});

test('tickled: laughs with squinting eyes and giggle lines, leaning back and forth', () => {
  const tickle = frames('tickle');
  assert.ok(tickle.slice(0, 10).every((grid) => count(grid, 'star') >= 4), 'giggle lines while laughing');
  // 往后仰：头顶的橙子在几拍之间左右挪
  const orangeX = new Set(tickle.map((grid) => grid.cells.findIndex((ink) => ink === 'orange') % 32));
  assert.ok(orangeX.size >= 2, 'the head sways while laughing');
  assert.equal(count(tickle.at(-1), 'star'), 0, 'calms down at the end');
});

test('annoyed: taps the front paw on the ground and a vein pops up', () => {
  const annoyed = frames('annoyed');
  // 近侧前爪（x 10-11）平时踩着地，抬起来时脚底下空出来
  const pawOnGround = (grid) => [10, 11].some((x) => grid.get(x, 30) !== 'clear');
  assert.ok(pawOnGround(sit));
  const lifted = annoyed.filter((grid) => !pawOnGround(grid)).length;
  assert.ok(lifted >= 2, `the paw taps more than once (lifted in ${lifted} frames)`);
  assert.ok(annoyed.some((grid) => count(grid, 'band') >= 8), 'an anger vein shows up');
  assert.ok(annoyed.some((grid) => count(grid, 'dust') > 0), 'tapping kicks up dust');
});

test('sneeze: nose up to breathe in, then down with a spray, and the grass flies off and comes back', () => {
  const sneeze = frames('sneeze');
  const lowest = Math.max(...sneeze.map(noseTop));
  const highest = Math.min(...sneeze.map(noseTop));
  assert.ok(highest < noseTop(sit) && lowest > noseTop(sit), 'the head goes up, then down');
  assert.ok(sneeze.some((grid) => count(grid, 'sweat') >= 4), 'a spray in front of the nose');
  assert.ok(sneeze.some((grid) => mouthGrass(grid) === 0), 'the grass is blown out of its mouth');
  assert.ok(mouthGrass(sneeze.at(-1)) > 0, 'and back in its mouth at the end');
});

test('startled: a "!" over its back, then a drop of cold sweat', () => {
  const startled = frames('startled');
  assert.ok(count(startled[0], 'white') > count(sit, 'white'), 'starts with the "!"');
  assert.ok(startled.some((grid) => count(grid, 'sweat') > 0), 'cold sweat afterwards');
  assert.deepEqual(startled.at(-1).cells, sit.cells, 'back to the normal sitting frame');
});

test('grumpy: nose in the air with a vein and a huff', () => {
  const grumpy = frames('grumpy');
  assert.ok(grumpy.every((grid) => noseTop(grid) < noseTop(sit)), 'keeps its nose up the whole time');
  assert.ok(grumpy.filter((grid) => count(grid, 'band') >= 8).length >= grumpy.length / 2, 'stays cross most of the time');
  assert.ok(grumpy.some((grid) => count(grid, 'white') > count(sit, 'white')), 'huffs through the nose');
});

test('poke-reactions.mjs loads on its own (no import cycle through render.mjs)', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const run = spawnSync(process.execPath, ['--input-type=module', '-e', "await import('./poke-reactions.mjs')"], { cwd: here, encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
});
