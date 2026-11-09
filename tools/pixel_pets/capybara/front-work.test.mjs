// 运行: node --test tools/pixel_pets/capybara/
// Agent 干活时的正面小场景
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { DEFAULT_MODEL } from './model.mjs';
import { allFrames } from './render.mjs';
import { writeAssets } from './build.mjs';
import { OUTFIT_HEADWEAR } from './headwear.mjs';
import { renderFrontUpright } from './front-peek.mjs';
import { WORK_SCENES, workFrames, workSceneFrames, workSceneManifest } from './front-work.mjs';

const opaqueBox = (grid, predicate = (ink) => ink !== 'clear') => {
  let minX = Infinity; let maxX = -Infinity; let minY = Infinity; let maxY = -Infinity;
  for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < grid.width; x += 1) {
    if (!predicate(grid.get(x, y))) continue;
    minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  return { width: maxX - minX + 1, height: maxY - minY + 1, minY, maxY };
};

test('every agent activity has a work scene except thinking, which keeps the normal side-view idle', () => {
  // 用户 2026-11-08：正面坐着什么都不做太丑，在想事情就保持平时侧身坐着嚼草的样子
  assert.deepEqual([...WORK_SCENES].sort(), ['delegate', 'eat', 'read', 'search', 'write']);
  assert.equal(workSceneManifest().scenes.think, undefined);
});

test('work scene frames are 32x32, like every other pose', () => {
  for (const name of WORK_SCENES) {
    for (const grid of workSceneFrames(name)) {
      assert.equal(grid.width, 32);
      assert.equal(grid.height, 32);
    }
  }
});

test('the manifest only points at frames that exist and plays each scene for a few seconds', () => {
  const manifest = workSceneManifest();
  assert.ok(manifest.fps > 0);
  for (const name of WORK_SCENES) {
    const scene = manifest.scenes[name];
    const count = workSceneFrames(name).length;
    assert.equal(scene.frames.length, count, `${name}: one file per key frame`);
    assert.ok(scene.order.every((i) => Number.isInteger(i) && i >= 0 && i < count), `${name}: order indexes key frames`);
    assert.ok(scene.order.length / (scene.fps ?? manifest.fps) >= 3, `${name}: a loop lasts at least 3 seconds (the app holds a scene that long)`);
    assert.equal(new Set(scene.order).size, count, `${name}: every key frame is used`);
  }
});

test('searching is a sideways chase that the app moves around, the other scenes stay put', () => {
  const manifest = workSceneManifest();
  assert.equal(manifest.scenes.search.motion, 'chase');
  assert.ok(manifest.scenes.search.fps > manifest.fps, 'running ticks faster than the calm scenes');
  for (const name of WORK_SCENES.filter((n) => n !== 'search')) assert.equal(manifest.scenes[name].motion, undefined, `${name} stays in place`);
});

test('the front head in work scenes is the same size as the edge peek head (three views stay consistent)', () => {
  const muzzleBox = (grid) => opaqueBox(grid, (ink) => ink === 'muzzle');
  const reference = muzzleBox(renderFrontUpright());
  for (const name of WORK_SCENES.filter((n) => n !== 'search')) {
    // 吃饭会把头埋进碗里，取整段里口鼻露得最全的那帧比
    const width = Math.max(...workSceneFrames(name).map((grid) => muzzleBox(grid).width));
    assert.equal(width, reference.width, `${name}: muzzle width matches`);
  }
});

test('work frames are part of every outfit and come with the manifest', () => {
  const paths = allFrames(DEFAULT_MODEL).map(([path]) => path);
  for (const [path] of workFrames()) assert.ok(paths.includes(path), `${path} is generated`);
  const dir = mkdtempSync(join(tmpdir(), 'capy-work-'));
  writeAssets(DEFAULT_MODEL, dir);
  assert.deepEqual(JSON.parse(readFileSync(join(dir, 'work/scenes.json'), 'utf8')), workSceneManifest());
  for (const outfit of OUTFIT_HEADWEAR) {
    assert.ok(existsSync(join(dir, 'outfits', outfit, 'work/read_0.png')), `${outfit} has its own work frames`);
    assert.ok(existsSync(join(dir, 'outfits', outfit, 'work/scenes.json')), `${outfit} has the manifest too`);
  }
});

test('the chase body stays inside the canvas: its outline is never cut off', () => {
  // 身体已经拉到 32 格画布的右边缘，再往外就会被切掉（嘴里的草和坐姿一样本来就伸到边上，不算）
  const bodyInks = new Set(['body', 'shade', 'light', 'dark']);
  for (const grid of workSceneFrames('search')) {
    for (let i = 0; i < 32; i += 1) {
      for (const [x, y] of [[0, i], [31, i], [i, 0], [i, 31]]) {
        assert.ok(!bodyInks.has(grid.get(x, y)), `body touches the edge at (${x}, ${y})`);
      }
    }
  }
});

test('chase.mjs loads on its own (no import cycle through render.mjs)', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const run = spawnSync(process.execPath, ['--input-type=module', '-e', "await import('./chase.mjs')"], { cwd: here, encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
});
