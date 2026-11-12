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
import { allFrames, renderPose } from './render.mjs';
import { writeAssets } from './build.mjs';
import { OUTFIT_HEADWEAR } from './headwear.mjs';
import { renderFrontUpright } from './front-peek.mjs';
import { frontFace, frontHead } from './front-head.mjs';
import { WORK_SCENES, workFrames, workSceneFrames, workSceneManifest } from './front-work.mjs';
import { REMINDER_SCENES, SIDE_WORK_SCENES, STATE_SCENES } from './state-scenes.mjs';
import { CHASE_WIDTH } from './chase.mjs';
import { measure } from './measure.mjs';

const opaqueBox = (grid, predicate = (ink) => ink !== 'clear') => {
  let minX = Infinity; let maxX = -Infinity; let minY = Infinity; let maxY = -Infinity;
  for (let y = 0; y < grid.height; y += 1) for (let x = 0; x < grid.width; x += 1) {
    if (!predicate(grid.get(x, y))) continue;
    minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  return { width: maxX - minX + 1, height: maxY - minY + 1, minY, maxY };
};

test('every agent activity has a work scene; thinking only has side-view variants on top of the normal idle', () => {
  // 用户 2026-11-08：正面坐着什么都不做太丑，在想事情保持侧身坐着嚼草；2026-11-11 加了头顶转圈小点和灯泡两种演法
  assert.deepEqual([...WORK_SCENES].filter((name) => !workSceneManifest().scenes[name].variantOf).sort(),
    ['delegate', 'done', 'drink', 'eat', 'fail', 'look_away', 'read', 'search', 'wait', 'write']);
  assert.equal(workSceneManifest().scenes.think, undefined);
});

test('variants: each one names the scene it stands in for, and is played sideways', () => {
  const { scenes } = workSceneManifest();
  const variants = Object.entries(scenes).filter(([, scene]) => scene.variantOf);
  assert.deepEqual(Object.fromEntries(variants.map(([name, scene]) => [name, scene.variantOf])), {
    think_dots: 'think', think_bulb: 'think', button: 'eat', surf: 'eat', rummage: 'search', paper: 'read', fall: 'fail', rest_fish: 'rest',
  });
  for (const [name, scene] of variants) assert.equal(scene.side, true, `${name} is a side-view scene`);
  assert.equal(scenes.fall.once, true, 'falling over plays once, like the plain failure');
});

test('agent states have their own scenes: waiting loops, done and failed play once', () => {
  const { scenes, fps } = workSceneManifest();
  assert.equal(scenes.wait.once, undefined, 'waiting keeps waving until you deal with it');
  assert.equal(scenes.done.once, true);
  assert.equal(scenes.fail.once, true);
  // 干完了要被 App 抛起来：抛的那几拍在场景之内，高度不超过头顶留白（24pt = 6 格）
  const { hop } = scenes.done;
  const beats = scenes.done.order.length;
  assert.ok(hop.atBeat >= 0 && hop.atBeat + hop.beats <= beats, `hop fits inside the scene (${JSON.stringify(hop)}, ${beats} beats)`);
  assert.ok(hop.pixels > 0 && hop.pixels <= 6, `hop height fits the headroom (got ${hop.pixels})`);
  for (const name of STATE_SCENES) {
    assert.ok(scenes[name].order.length / (scenes[name].fps ?? fps) >= 1, `${name} lasts long enough to notice`);
  }
});

test('waiting raises a paw out in front of the body, so it reads at a glance', () => {
  // 平时坐姿左下角（胸口前面）是空的；举爪那几帧这里得有爪子
  const sitting = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 });
  // 近侧的腿比身体深一号（muzzle），爪子是 dark
  const pawInks = new Set(['body', 'muzzle', 'dark']);
  const front = (grid) => { let n = 0; for (let y = 17; y < 24; y += 1) for (let x = 0; x < 6; x += 1) if (pawInks.has(grid.get(x, y))) n += 1; return n; };
  for (const grid of workSceneFrames('wait')) assert.ok(front(grid) > front(sitting) + 3, 'the raised paw sticks out in front');
});

test('work scene frames are 32 rows; only side-view scenes may be wider, and a scene keeps one width', () => {
  const { scenes } = workSceneManifest();
  for (const name of WORK_SCENES) {
    const widths = new Set(workSceneFrames(name).map((grid) => grid.width));
    assert.equal(widths.size, 1, `${name}: every frame is as wide`);
    const [width] = widths;
    const side = scenes[name].side || name === 'search';
    assert.ok(side ? width >= 32 && width <= 52 : width === 32, `${name} is ${width} wide`);
    for (const grid of workSceneFrames(name)) assert.equal(grid.height, 32);
  }
  assert.equal(workSceneFrames('search')[0].width, CHASE_WIDTH);
});

test('the manifest only points at frames that exist and plays each scene for a few seconds', () => {
  const manifest = workSceneManifest();
  assert.ok(manifest.fps > 0);
  for (const name of WORK_SCENES) {
    const scene = manifest.scenes[name];
    const count = workSceneFrames(name).length;
    assert.equal(scene.frames.length, count, `${name}: one file per key frame`);
    assert.ok(scene.order.every((i) => Number.isInteger(i) && i >= 0 && i < count), `${name}: order indexes key frames`);
    if (!scene.once) assert.ok(scene.order.length / (scene.fps ?? manifest.fps) >= 3, `${name}: a loop lasts at least 3 seconds (the app holds a scene that long)`);
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
  // 追球、放小鸟、三段状态动作和两段健康提醒是侧身的，不比正面头
  const variants = Object.entries(workSceneManifest().scenes).filter(([, scene]) => scene.side).map(([name]) => name);
  const sideways = new Set(['search', ...SIDE_WORK_SCENES, ...STATE_SCENES, ...REMINDER_SCENES, ...variants]);
  for (const name of WORK_SCENES.filter((n) => !sideways.has(n))) {
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
  // 整只（头、身子、腿、爪）离画布四边至少留一格描边（嘴里的草是道具，本来就伸到边上，不算）
  for (const grid of workSceneFrames('search')) {
    const { figure } = measure(grid);
    assert.ok(figure.left >= 1 && figure.top >= 1, `figure starts at (${figure.left}, ${figure.top})`);
    assert.ok(figure.right <= grid.width - 2 && figure.bottom <= grid.height - 2, `figure ends at (${figure.right}, ${figure.bottom})`);
  }
});

test('state-scenes.mjs loads on its own (no import cycle through render.mjs)', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const run = spawnSync(process.execPath, ['--input-type=module', '-e', "await import('./state-scenes.mjs')"], { cwd: here, encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
});

test('chase.mjs loads on its own (no import cycle through render.mjs)', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const run = spawnSync(process.execPath, ['--input-type=module', '-e', "await import('./chase.mjs')"], { cwd: here, encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
});

// ---------------- 健康提醒的两段动作 ----------------

test('health reminders have looping scenes: drinking from a cup and looking far away', () => {
  const { scenes } = workSceneManifest();
  for (const name of REMINDER_SCENES) {
    assert.equal(scenes[name].once, undefined, `${name} loops until the reminder is answered`);
    assert.ok(scenes[name].order.length >= 8, `${name} lasts long enough to notice`);
  }
  // 喝水那几帧嘴边有一杯水（浅蓝），平时坐姿没有
  const water = (grid) => grid.cells.filter((ink) => ink === 'sweat').length;
  assert.equal(water(renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 })), 0);
  for (const grid of workSceneFrames('drink')) assert.ok(water(grid) >= 8, 'every drinking frame shows the cup');
  // 望远处：至少一帧抬眼往上看，和平时的坐姿不是同一张
  const sitting = renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 }).cells.join();
  assert.ok(workSceneFrames('look_away').some((grid) => grid.cells.join() !== sitting), 'the head lifts to look away');
  // 是抬头不是低头：鼻垫（深色）比坐着时高
  // （耳朵里面也是深色，只看脸最左边几列）
  const noseTop = (grid) => grid.cells.findIndex((ink, i) => ink === 'dark' && i % 32 < 7);
  const sittingNose = noseTop(renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 }));
  assert.ok(noseTop(workSceneFrames('look_away')[1]) < sittingNose, 'looking far away raises the nose');
});

// ---------------- 各角度、各状态一样大 ----------------

const FUR = new Set(['body', 'shade', 'light', 'muzzle']);
const furArea = (grid) => grid.cells.filter((ink) => FUR.has(ink)).length;

test('every whole-body pose is as big as the sitting one: side, lifted and trotting', () => {
  const sit = furArea(renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 }));
  const poses = {
    lifted: renderPose(DEFAULT_MODEL, 'hold', { face: 'squeeze', tilt: 0 }),
    trotting: workSceneFrames('search')[0],
    drinking: workSceneFrames('drink')[1],
    'looking away': workSceneFrames('look_away')[1],
    waiting: workSceneFrames('wait')[1],
  };
  for (const [name, grid] of Object.entries(poses)) {
    const ratio = furArea(grid) / sit;
    assert.ok(ratio >= 0.79 && ratio <= 1.08, `${name} is ${Math.round(ratio * 100)}% of the sitting body (want 79-108%)`);
  }
});

test('the head is the same size in every side pose, and every front pose shares one front head', () => {
  // 侧面：按部位量头（腿也是口鼻那个深色，不能按颜色数），坐着、被拎着、小跑一样大
  const head = (grid) => measure(grid).head.area;
  const sit = head(renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 }));
  // 头后面紧挨着的身子不同，描边会多吃 / 少吃一两格
  assert.ok(Math.abs(head(renderPose(DEFAULT_MODEL, 'hold', { tilt: 0 })) - sit) <= 2, 'lifted head = sitting head');
  assert.ok(Math.abs(head(workSceneFrames('search')[0]) - sit) <= 2, 'trotting head = sitting head');
  for (const pose of Object.values(DEFAULT_MODEL.poses)) {
    if (pose.head) assert.equal(pose.head.scale, 1, 'no pose scales the head');
  }
  // 正面：标题栏上趴着的和翻书场景是同一颗头（比口鼻那块的宽，标题栏那只下巴被画布底边切掉了）
  const muzzleWidth = (grid) => opaqueBox(grid, (ink) => ink === 'muzzle').width;
  assert.equal(muzzleWidth(renderFrontUpright()), muzzleWidth(workSceneFrames('read')[6]), 'title-bar head = reading head');
});

test('no bare front-facing sitting pose: front faces only peek out from behind props or a screen edge', () => {
  // 2026-11-11 用户：正面坐姿不可爱，没有道具挡着显得光秃秃的。转身改成蹦一下直接换边，放小鸟改成侧身
  const paths = allFrames(DEFAULT_MODEL).map(([path]) => path);
  assert.ok(!paths.some((path) => path.startsWith('turn/')), 'no turn/front.png any more');
  assert.ok(SIDE_WORK_SCENES.includes('delegate'), 'releasing the bird is a side-view scene');
});

test('delegating sends the bird off with a letter and waits for it to come back', () => {
  const { scenes } = workSceneManifest();
  const frames = scenes.delegate.order.map((i) => workSceneFrames('delegate')[i]);
  const bird = (grid) => grid.cells.filter((ink) => ink === 'bird').length;
  const letter = (grid) => grid.cells.filter((ink) => ink === 'band').length;
  assert.equal(scenes.delegate.once, undefined, 'loops while the sub-agent works');
  assert.ok(bird(frames[0]) > 0, 'starts with the bird on its forehead');
  const leaving = frames.findIndex((grid) => letter(grid) > 0);
  assert.ok(leaving > 0, 'the bird flies off carrying a letter');
  const away = frames.findIndex((grid, i) => i > leaving && bird(grid) === 0);
  assert.ok(away > leaving, 'then it is gone for a while');
  assert.ok(frames.slice(away).some((grid) => bird(grid) > 0 && letter(grid) === 0), 'and comes back without the letter');
});

test('the front face is broad, not pointy: the muzzle is nearly as wide as the head', () => {
  // 2026-11-11 用户：干活时正面的脸有点尖、瘦。口鼻窄一大圈、下巴收成尖，就像狐狸 / 熊
  const c = 15;
  const head = frontHead(c);
  const rowWidth = (y) => {
    const xs = Array.from({ length: 32 }, (_, x) => x).filter((x) => head.get(x, y) !== 'clear');
    return xs.length ? xs.at(-1) - xs[0] + 1 : 0;
  };
  const rows = Array.from({ length: 32 }, (_, y) => y).filter((y) => rowWidth(y) > 0);
  const widest = Math.max(...rows.map(rowWidth));
  const muzzle = rowWidth(c + 4);
  const chin = rowWidth(rows.at(-1));
  assert.ok(muzzle / widest >= 0.75, `muzzle is ${muzzle}px of a ${widest}px head (want at least 75%)`);
  assert.ok(chin / widest >= 0.5, `the chin is ${chin}px of a ${widest}px head (want at least half, not a point)`);
});

test('the front face is shaped like a capybara: a loaf, widest at the jaw, with a nose pad and two nostrils', () => {
  // 2026-11-11 用户：「还是不太像豚鼠」。上宽下窄、口鼻凸出一块是熊；水豚腮帮下颌最宽
  const c = 15;
  const head = frontHead(c);
  const rowWidth = (y) => {
    const xs = Array.from({ length: 32 }, (_, x) => x).filter((x) => head.get(x, y) !== 'clear');
    return xs.length ? xs.at(-1) - xs[0] + 1 : 0;
  };
  const widest = (from, to) => Math.max(...Array.from({ length: to - from + 1 }, (_, i) => rowWidth(c + from + i)));
  // 脑壳（耳朵下面到眼睛）和腮帮（眼睛下面到下巴）
  assert.ok(widest(1, 6) >= widest(-5, -2), `jaw ${widest(1, 6)}px is at least as wide as the skull ${widest(-5, -2)}px`);
  // 鼻垫是深色一块，两边鼻孔是描边色
  const face = frontFace(head, c, {});
  const nose = Array.from({ length: 32 * 32 }, (_, i) => [i % 32, Math.floor(i / 32)])
    .filter(([x, y]) => y > c && y < c + 5 && x >= 11 && x <= 20 && face.get(x, y) === 'dark');
  assert.ok(nose.length >= 8, `a big nose pad (${nose.length} dark cells)`);
});
