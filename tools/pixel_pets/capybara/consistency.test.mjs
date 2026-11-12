import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULT_MODEL } from './model.mjs';
import { allFrames, renderPose } from './render.mjs';
import { Grid } from './raster.mjs';
import { measure } from './measure.mjs';
import { checkConsistency, checkFrame, referenceMeasures, threeViewIssues } from './consistency.mjs';
import { frameKind } from './body-spec.mjs';

const refs = referenceMeasures(DEFAULT_MODEL);
const sit = () => renderPose(DEFAULT_MODEL, 'sit', { chewPhase: 0 });
const withPose = (name, pose) => ({ ...DEFAULT_MODEL, poses: { ...DEFAULT_MODEL.poses, [name]: pose } });
const SIDE_SIT = { view: 'side', pose: 'sit' };

test('measuring goes by body part, not by colour: repainting the legs changes nothing', () => {
  const sitPose = DEFAULT_MODEL.poses.sit;
  const repainted = { ...sitPose, parts: sitPose.parts.map((part) => (/Leg$/.test(part.id) ? { ...part, ink: 'body' } : part)) };
  const before = measure(sit());
  const after = measure(renderPose(withPose('repainted', repainted), 'repainted', { chewPhase: 0 }));
  assert.deepEqual(after.head, before.head);
  assert.equal(after.figure.area, before.figure.area);
});

test('body part tags travel with the pixels through flips, turns, shifts and overlays', () => {
  const grid = sit();
  const head = measure(grid).head.area;
  assert.equal(measure(grid.flippedVertically()).head.area, head);
  assert.equal(measure(grid.rotatedQuarter(1)).head.area, head);
  assert.equal(measure(grid.translated(2, 1)).head.area, head);
  assert.equal(measure(grid.overlaid(Grid.empty(grid.width, grid.height))).head.area, head);
  // 盖上一块道具：被盖住的格子不再算头
  const patch = Grid.empty(grid.width, grid.height).dots('white', [[8, 6], [9, 6], [8, 7], [9, 7]]);
  assert.equal(measure(grid.overlaid(patch)).head.area, head - 4);
});

test('the sitting pose passes its own check, and the side, front and back views line up', () => {
  assert.deepEqual(checkFrame('idle/main/0.png', sit(), refs).issues, []);
  const views = threeViewIssues(refs);
  assert.deepEqual(views.issues, [], 'heads are the same height, the back stands on the same lines');
  assert.deepEqual(views.missing, []);
});

test('a back view that floats above the ground is caught', () => {
  const lifted = { ...refs, backFigure: { ...refs.backFigure, bottom: refs.backFigure.bottom - 3 } };
  assert.ok(threeViewIssues(lifted).issues.some((found) => found.check === 'back lines'));
});

test('a shrunken head is an error, a head partly hidden behind a prop is only a note', () => {
  const sitPose = DEFAULT_MODEL.poses.sit;
  const shrunk = renderPose(withPose('small', { ...sitPose, head: { ...sitPose.head, scale: 0.85 } }), 'small', { chewPhase: 0 });
  assert.ok(checkFrame('x.png', shrunk, refs, SIDE_SIT).issues.some((found) => found.check === 'head'), 'scaled-down head is caught');

  const cup = Grid.empty(32, 32).dots('sweat', [[3, 12], [4, 12], [3, 13], [4, 13], [3, 14], [4, 14], [5, 12], [5, 13], [5, 14]]);
  const hidden = checkFrame('x.png', sit().overlaid(cup), refs, SIDE_SIT);
  assert.deepEqual(hidden.issues, []);
  assert.equal(hidden.notes.length, 1);
});

test('a whole body that is too small for its pose is an error', () => {
  const half = sit().cropped(0, 18).windowed(0, 0, 32, 32);
  assert.ok(checkFrame('x.png', half, refs, SIDE_SIT).issues.some((found) => found.check.startsWith('figure')));
});

test('the belly only shows when the underside faces you (lifted or flipped over)', () => {
  const lifted = checkFrame('x.png', sit(), refs, { view: 'side', pose: 'hold' });
  assert.ok(lifted.issues.some((found) => found.check === 'belly'), 'lifted pose without a belly is caught');
  const sitPose = DEFAULT_MODEL.poses.sit;
  const tummy = { id: 'tummy', label: '肚皮', shape: 'ellipse', ink: 'light', cx: 14, cy: 23.8, rx: 3.4, ry: 3.2, rot: 0, onlyOver: 'body' };
  const withTummy = renderPose(withPose('tummy', { ...sitPose, parts: [...sitPose.parts, tummy] }), 'tummy', { chewPhase: 0 });
  assert.ok(checkFrame('x.png', withTummy, refs, SIDE_SIT).issues.some((found) => found.check === 'belly'), 'side pose with a belly is caught');
});

test('frames are classified by their asset path', () => {
  assert.equal(frameKind('work/search_0.png').pose, 'stand');
  assert.equal(frameKind('drag/hold_0.png').pose, 'hold');
  assert.equal(frameKind('drag/dizzy_grounded_0.png').pose, 'sit');
  assert.equal(frameKind('work/read_3.png').partial, true);
  assert.equal(frameKind('ui/item_orange.png').skip, true);
});

test('every asset frame is the same capybara (body consistency check)', () => {
  const result = checkConsistency(allFrames(DEFAULT_MODEL), DEFAULT_MODEL);
  assert.deepEqual(result.issues, []);
});
