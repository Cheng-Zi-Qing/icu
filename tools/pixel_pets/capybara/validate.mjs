// 模型 JSON 校验：编辑器保存、命令行读取前都要过一遍，防止坏数据写进素材
import { INKS } from './raster.mjs';

const NUMBER_LIMIT = 200;
const SHAPE_FIELDS = {
  ellipse: ['cx', 'cy', 'rx', 'ry'],
  rbox: ['cx', 'cy', 'w', 'h', 'r'],
  capsule: ['x1', 'y1', 'x2', 'y2', 'r'],
};
const EDGES = ['below', 'above', 'around', 'inner'];
const MARKS = ['eye', 'blush', 'nostril', 'mouth', 'highlight', 'earInner', 'yuzu', 'grass'];

function fail(path, message) {
  throw new Error(`${path}: ${message}`);
}

function checkNumber(value, path, { min = -NUMBER_LIMIT, max = NUMBER_LIMIT } = {}) {
  if (typeof value !== 'number' || !Number.isFinite(value)) fail(path, 'must be a finite number');
  if (value < min || value > max) fail(path, `must be between ${min} and ${max}`);
}

function checkPart(part, path) {
  if (typeof part !== 'object' || part === null) fail(path, 'must be an object');
  if (typeof part.id !== 'string' || !/^[A-Za-z][A-Za-z0-9]{0,40}$/.test(part.id)) fail(`${path}.id`, 'invalid id');
  if (part.shape === 'head') return;
  const fields = SHAPE_FIELDS[part.shape];
  if (!fields) fail(`${path}.shape`, `unknown shape "${part.shape}"`);
  fields.forEach((field) => checkNumber(part[field], `${path}.${field}`));
  if (part.rot !== undefined) checkNumber(part.rot, `${path}.rot`, { min: -180, max: 180 });
  if (!INKS.includes(part.ink) || part.ink === 'clear') fail(`${path}.ink`, `unknown ink "${part.ink}"`);
  if (part.onlyOver != null && !INKS.includes(part.onlyOver)) fail(`${path}.onlyOver`, 'unknown ink');
  if (part.edge != null && !EDGES.includes(part.edge)) fail(`${path}.edge`, 'unknown edge');
}

function checkTransform(t, path) {
  if (typeof t !== 'object' || t === null) fail(path, 'must be an object');
  checkNumber(t.x, `${path}.x`);
  checkNumber(t.y, `${path}.y`);
  checkNumber(t.rot ?? 0, `${path}.rot`, { min: -180, max: 180 });
  checkNumber(t.scale ?? 1, `${path}.scale`, { min: 0.5, max: 2 });
}

/** 校验通过返回模型本身，否则抛出带路径的错误 */
export function validateModel(model) {
  if (typeof model !== 'object' || model === null) fail('model', 'must be an object');
  if (model.version !== 1) fail('model.version', 'must be 1');
  if (!Array.isArray(model.head?.parts)) fail('model.head.parts', 'must be an array');
  model.head.parts.forEach((part, i) => checkPart(part, `head.parts[${i}]`));
  MARKS.forEach((name) => {
    checkNumber(model.head.marks?.[name]?.x, `head.marks.${name}.x`);
    checkNumber(model.head.marks?.[name]?.y, `head.marks.${name}.y`);
  });

  for (const name of ['sit', 'lie', 'peek', 'hold']) {
    const pose = model.poses?.[name];
    if (!pose) fail(`poses.${name}`, 'missing');
    checkNumber(pose.width ?? 32, `poses.${name}.width`, { min: 16, max: 64 });
    if (pose.from) {
      if (!model.poses[pose.from] || model.poses[pose.from].from) fail(`poses.${name}.from`, 'must name a base pose');
      checkNumber(pose.offsetX ?? 0, `poses.${name}.offsetX`, { min: -64, max: 64 });
      checkNumber(pose.offsetY ?? 0, `poses.${name}.offsetY`, { min: -32, max: 32 });
      checkNumber(pose.reachPixels ?? 0, `poses.${name}.reachPixels`, { min: 0, max: 6 });
      if (![-1, 0, 1, 2].includes(pose.turn ?? 0)) fail(`poses.${name}.turn`, 'must be -1, 0, 1 or 2 (quarter turns)');
      if (pose.flipY !== undefined && typeof pose.flipY !== 'boolean') fail(`poses.${name}.flipY`, 'must be true or false');
      if (pose.headOnly !== undefined && typeof pose.headOnly !== 'boolean') fail(`poses.${name}.headOnly`, 'must be true or false');
      continue;
    }
    checkTransform(pose.head, `poses.${name}.head`);
    if (!Array.isArray(pose.parts)) fail(`poses.${name}.parts`, 'must be an array');
    if (pose.parts.filter((p) => p.shape === 'head').length !== 1) fail(`poses.${name}.parts`, 'must contain the head once');
    pose.parts.forEach((part, i) => checkPart(part, `poses.${name}.parts[${i}]`));
  }
  return model;
}
