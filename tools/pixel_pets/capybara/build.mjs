#!/usr/bin/env node
// 水豚素材构建：读 pose.json（没有就用默认模型）→ 写全部 PNG 帧
//
// 用法: node tools/pixel_pets/capybara/build.mjs [--assets assets/pets/capybara] [--preview <目录>] [--model <json>]
import { mkdirSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_MODEL } from './model.mjs';
import { encodePNG } from './png.mjs';
import { allFrames, GENERATED_DIRECTORIES, renderPose } from './render.mjs';
import { OUTFIT_HEADWEAR } from './headwear.mjs';
import { CURSOR_SCALE, cursorDefinitions, cursorManifest } from './cursors.mjs';
import { validateModel } from './validate.mjs';
import { workSceneManifest } from './front-work.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
export const MODEL_PATH = join(HERE, 'pose.json');
export const REPO_ROOT = resolve(HERE, '../../..');
export const DEFAULT_ASSETS = join(REPO_ROOT, 'assets/pets/capybara');

export function loadModel(path = MODEL_PATH) {
  if (!existsSync(path)) return DEFAULT_MODEL;
  return validateModel(JSON.parse(readFileSync(path, 'utf8')));
}

/** 像素光标：按 CURSOR_SCALE 倍导出，热点写进 cursors.json 给 App 读 */
function writeCursors(assetsDir) {
  const dir = join(assetsDir, 'cursor');
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  for (const [name, { grid }] of Object.entries(cursorDefinitions())) {
    writeFileSync(join(dir, `${name}.png`), encodePNG(grid, { scale: CURSOR_SCALE }));
  }
  writeFileSync(join(dir, 'cursors.json'), `${JSON.stringify(cursorManifest(), null, 2)}\n`);
}

/** 干活场景的播放顺序：每套装扮的 work/ 里各放一份，App 按装扮目录读 */
function writeWorkManifest(dir) {
  writeFileSync(join(dir, 'work', 'scenes.json'), `${JSON.stringify(workSceneManifest(), null, 2)}\n`);
}

function writeFrames(frames, dir) {
  for (const [path, grid] of frames) {
    const target = join(dir, path);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, encodePNG(grid));
  }
  return frames.length;
}

/**
 * 写全部素材帧（和像素光标），返回写入的帧数。
 * 默认装扮（橙子）的帧在根目录；其他头顶装扮各一整套，放在 outfits/<装扮>/ 下，光标共用
 */
export function writeAssets(model, assetsDir = DEFAULT_ASSETS) {
  for (const sub of GENERATED_DIRECTORIES) rmSync(join(assetsDir, sub), { recursive: true, force: true });
  rmSync(join(assetsDir, 'outfits'), { recursive: true, force: true });
  writeCursors(assetsDir);
  const base = writeFrames(allFrames(model), assetsDir);
  writeWorkManifest(assetsDir);
  return OUTFIT_HEADWEAR.reduce((count, headwear) => {
    const dir = join(assetsDir, 'outfits', headwear);
    const written = writeFrames(allFrames(model, { headwear }), dir);
    writeWorkManifest(dir);
    return count + written;
  }, base);
}

/** 8 倍预览，含完整的趴姿（不截断） */
export function writePreviews(model, previewDir) {
  mkdirSync(previewDir, { recursive: true });
  for (const [path, grid] of allFrames(model)) {
    writeFileSync(join(previewDir, path.replaceAll('/', '-')), encodePNG(grid, { scale: 8 }));
  }
  writeFileSync(join(previewDir, 'lie-full.png'), encodePNG(renderPose(model, 'lie', { chewPhase: 0 }), { scale: 8 }));
}

function parseArgs(argv) {
  const args = { assets: DEFAULT_ASSETS, preview: null, model: MODEL_PATH };
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    if (!(key in args) || argv[i + 1] === undefined) throw new Error(`unknown or incomplete argument: ${argv[i]}`);
    args[key] = resolve(argv[i + 1]);
  }
  return args;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const model = loadModel(args.model);
    const count = writeAssets(model, args.assets);
    if (args.preview) writePreviews(model, args.preview);
    console.log(`wrote ${count} capybara frames to ${args.assets}`);
  } catch (error) {
    console.error(`构建失败: ${error.message}`);
    process.exit(1);
  }
}
