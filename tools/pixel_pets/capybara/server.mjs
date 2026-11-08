#!/usr/bin/env node
// 水豚造型编辑器的本地服务（只监听 127.0.0.1）
//
// 用法: node tools/pixel_pets/capybara/server.mjs [--port 4790] [--refs <参考照片目录>]
// 保存 = 校验 → 写 pose.json → 重新生成 assets/pets/capybara 下的全部帧
import { createServer } from 'node:http';
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_ASSETS, MODEL_PATH, loadModel, writeAssets } from './build.mjs';
import { DEFAULT_MODEL } from './model.mjs';
import { validateModel } from './validate.mjs';

const HERE = fileURLToPath(new URL('.', import.meta.url));
const HOST = '127.0.0.1';
const MAX_BODY_BYTES = 1_000_000;
const STATIC_FILES = new Set(['editor.html', 'editor.js', 'editor-state.mjs', 'editor-view.mjs', 'model.mjs', 'raster.mjs', 'render.mjs', 'validate.mjs']);
const IMAGE_TYPES = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp', '.gif': 'image/gif' };
const TEXT_TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8' };

function sendJSON(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
  res.end(JSON.stringify(body));
}

const ok = (res, data) => sendJSON(res, 200, { success: true, data, error: null });
const failed = (res, status, error) => sendJSON(res, status, { success: false, data: null, error });

function readBody(req) {
  return new Promise((resolveBody, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error('请求太大'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolveBody(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function listRefs(refsDir) {
  if (!refsDir || !existsSync(refsDir)) return [];
  return readdirSync(refsDir).filter((name) => IMAGE_TYPES[extname(name).toLowerCase()]).sort();
}

/** 只允许参考目录里的图片文件名，拒绝任何路径 */
function refFile(refsDir, rawName) {
  const name = decodeURIComponent(rawName);
  if (!refsDir || name !== basename(name) || !IMAGE_TYPES[extname(name).toLowerCase()]) return null;
  const path = join(refsDir, name);
  return existsSync(path) ? path : null;
}

export function createEditorServer({ modelPath = MODEL_PATH, assetsDir = DEFAULT_ASSETS, refsDir = null } = {}) {
  const handle = async (req, res) => {
    const url = new URL(req.url, `http://${HOST}`);
    const path = url.pathname;

    if (req.method === 'GET' && path === '/api/model') {
      return ok(res, { model: loadModel(modelPath), defaults: DEFAULT_MODEL, saved: existsSync(modelPath) });
    }
    if (req.method === 'GET' && path === '/api/refs') return ok(res, { refs: listRefs(refsDir) });
    if (req.method === 'POST' && path === '/api/save') {
      let model;
      try {
        model = validateModel(JSON.parse(await readBody(req)).model);
      } catch (error) {
        return failed(res, 400, `模型无效：${error.message}`);
      }
      try {
        writeFileSync(modelPath, `${JSON.stringify(model, null, 2)}\n`);
        return ok(res, { frames: writeAssets(model, assetsDir), modelPath, assetsDir });
      } catch (error) {
        console.error('save failed', error);
        return failed(res, 500, `写文件失败：${error.message}`);
      }
    }
    if (req.method === 'GET' && path.startsWith('/refs/')) {
      const file = refFile(refsDir, path.slice('/refs/'.length));
      if (!file) return failed(res, 404, '没有这张参考图');
      res.writeHead(200, { 'content-type': IMAGE_TYPES[extname(file).toLowerCase()] });
      return res.end(readFileSync(file));
    }
    if (req.method === 'GET') {
      const name = path === '/' ? 'editor.html' : path.slice(1);
      if (!STATIC_FILES.has(name)) return failed(res, 404, '没有这个文件');
      res.writeHead(200, { 'content-type': TEXT_TYPES[extname(name)], 'cache-control': 'no-store' });
      return res.end(readFileSync(join(HERE, name)));
    }
    return failed(res, 405, '不支持的请求');
  };

  return createServer((req, res) => {
    handle(req, res).catch((error) => {
      console.error('request failed', error);
      if (!res.headersSent) failed(res, 500, '服务内部错误');
    });
  });
}

function parseArgs(argv) {
  const args = { port: 4790, refs: null };
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    if (!(key in args) || argv[i + 1] === undefined) throw new Error(`unknown or incomplete argument: ${argv[i]}`);
    args[key] = key === 'port' ? Number(argv[i + 1]) : resolve(argv[i + 1]);
  }
  if (!Number.isInteger(args.port) || args.port < 1024 || args.port > 65535) throw new Error('port must be 1024-65535');
  return args;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const args = parseArgs(process.argv.slice(2));
    createEditorServer({ refsDir: args.refs }).listen(args.port, HOST, () => {
      console.log(`水豚编辑器: http://${HOST}:${args.port}/`);
    });
  } catch (error) {
    console.error(`启动失败: ${error.message}`);
    process.exit(1);
  }
}
