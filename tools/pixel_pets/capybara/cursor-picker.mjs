// Offline selection only; this tool never reads or writes ICU runtime assets.
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const OUTPUT_PATH = '/tmp/icu-cursor-picker.html';
export const REFERENCE_DIR = fileURLToPath(new URL('../../../assets/references/interaction/hands/kenney-tiles/', import.meta.url));
export const CANDIDATE_IDS = Object.freeze([134, 135, 136, 137, 138, 139, 154, 155, 156, 157, 158, 159, 175, 176, 177, 178, 179]);
export const ACTIONS = Object.freeze({ pat: '摸头', tickle: '挠痒', grabbing: '拎起', poke: '轻戳' });
export const DEFAULT_SELECTION = Object.freeze({ pat: 136, tickle: 135, grabbing: 139, poke: 175 });

export function selectCursor(selection, action, tile) {
  if (!Object.hasOwn(ACTIONS, action)) throw new RangeError(`Unknown action: ${action}`);
  if (!CANDIDATE_IDS.includes(tile)) throw new RangeError(`Unknown tile: ${tile}`);
  return { ...selection, [action]: tile };
}

function mountPicker() {
  let selection = { ...DEFAULT_SELECTION };
  let currentAction = 'pat';
  const actionButtons = document.querySelectorAll('[data-action]');
  const candidateButtons = document.querySelectorAll('[data-tile]');
  const output = document.getElementById('selection');
  const status = document.getElementById('status');

  function render() {
    for (const button of actionButtons) {
      const action = button.dataset.action;
      const tile = selection[action];
      button.setAttribute('aria-pressed', String(action === currentAction));
      button.setAttribute('aria-label', `${ACTIONS[action]}，已选 ${tile}，点击切换编辑动作`);
      button.querySelector('.tile-id').textContent = `#${tile}`;
      for (const image of button.querySelectorAll('img')) image.src = images[tile];
    }
    for (const button of candidateButtons) {
      button.setAttribute('aria-pressed', String(Number(button.dataset.tile) === selection[currentAction]));
    }
    document.getElementById('current-action').textContent = `正在选择：${ACTIONS[currentAction]} · #${selection[currentAction]}`;
    output.value = JSON.stringify(selection, null, 2);
  }

  for (const button of actionButtons) {
    button.addEventListener('click', () => {
      currentAction = button.dataset.action;
      status.textContent = '';
      render();
    });
  }
  for (const button of candidateButtons) {
    button.addEventListener('click', () => {
      const tile = Number(button.dataset.tile);
      selection = selectCursor(selection, currentAction, tile);
      status.textContent = `${ACTIONS[currentAction]}已选 #${tile}`;
      render();
    });
  }
  document.getElementById('copy').addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(output.value);
      status.textContent = '已复制选择，请把 JSON 发给助手统一应用。';
    } catch {
      output.focus();
      output.select();
      status.textContent = '未能自动复制，已选中文本，请按 ⌘C / Ctrl+C 手动复制。';
    }
  });
  render();
}

export async function generatePicker() {
  const images = Object.fromEntries(await Promise.all(CANDIDATE_IDS.map(async (tile) => {
    const png = await readFile(`${REFERENCE_DIR}/tile_${String(tile).padStart(4, '0')}.png`);
    return [tile, `data:image/png;base64,${png.toString('base64')}`];
  })));
  const preview = (tile) => `<span class="preview"><img class="large" src="${images[tile]}" width="64" height="64" alt=""><img class="small" src="${images[tile]}" width="16" height="16" alt=""></span>`;
  const html = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; base-uri 'none'; form-action 'none'">
<title>ICU 手型选择</title>
<style>
  :root { --bg: #F6F4F0; --panel: #FFFFFF; --ink: #2B2420; --muted: #7A706A; --line: #E2DCD4; --accent: #B0714A; --select: #E8F6FC; --stage: #EDE8E1; }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 14px/1.5 -apple-system, "PingFang SC", sans-serif; }
  main { max-width: 1060px; margin: 0 auto; padding: 16px; display: grid; gap: 12px; }
  .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 14px; }
  h1 { font-size: 20px; margin: 0 0 6px; }
  h2 { font-size: 15px; margin: 0 0 8px; }
  p { margin: 4px 0; }
  .hint { color: var(--muted); font-size: 12px; }
  button { font: inherit; color: var(--ink); background: var(--panel); border: 2px solid var(--line); border-radius: 8px; padding: 10px; cursor: pointer; min-height: 44px; }
  button:hover { border-color: var(--accent); }
  button:focus-visible, textarea:focus-visible, a:focus-visible { outline: 3px solid var(--accent); outline-offset: 3px; }
  button[aria-pressed="true"] { background: var(--select); border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
  .actions { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px; margin-top: 12px; }
  .actions button, .candidates button { display: flex; align-items: center; justify-content: center; flex-direction: column; gap: 5px; }
  .actions strong { font-size: 16px; }
  .preview { display: flex; align-items: end; justify-content: center; gap: 8px; padding: 6px; background: var(--stage); border-radius: 6px; }
  img { image-rendering: pixelated; object-fit: contain; }
  .candidates { display: grid; grid-template-columns: repeat(auto-fit, minmax(116px, 1fr)); gap: 8px; }
  .tile-id { font-variant-numeric: tabular-nums; }
  textarea { display: block; width: 100%; height: 120px; resize: vertical; border: 1px solid var(--line); border-radius: 6px; background: var(--bg); color: var(--ink); padding: 8px; font: 13px/1.4 ui-monospace, Menlo, monospace; margin: 8px 0; }
  #copy { background: var(--accent); color: white; border-color: var(--accent); }
  #status { display: inline-block; margin: 6px 8px; }
  a { color: #895435; }
  @media (max-width: 580px) { main { padding: 8px; } .actions { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
</style>
</head>
<body>
<main>
  <section class="panel" aria-labelledby="title">
    <h1 id="title">ICU 手型选择</h1>
    <p>这里只选图，不会直接修改ICU；选好后复制结果给助手统一应用</p>
    <p class="hint">先点动作，再点下面的手型。四个动作可以共用同一张图；普通抓手 grab（#138）保持现行，不在此编辑。</p>
    <div class="actions" role="group" aria-label="选择要编辑的动作">
      ${Object.entries(ACTIONS).map(([action, label]) => `<button type="button" data-action="${action}" aria-pressed="${action === 'pat'}"><strong>${label}</strong>${preview(DEFAULT_SELECTION[action])}<span class="tile-id">#${DEFAULT_SELECTION[action]}</span></button>`).join('\n      ')}
    </div>
  </section>
  <section class="panel" aria-labelledby="current-action">
    <h2 id="current-action">正在选择：摸头 · #${DEFAULT_SELECTION.pat}</h2>
    <p class="hint">Kenney 原始手型 · 大图 4 倍 / 小图 16px。握拳可看 #136、#139。Tab 切换，空格或回车选择。</p>
    <div class="candidates" role="group" aria-label="17 张手型候选">
      ${CANDIDATE_IDS.map((tile) => `<button type="button" data-tile="${tile}" aria-label="选择手型 ${tile}" aria-pressed="${tile === DEFAULT_SELECTION.pat}">${preview(tile)}<span class="tile-id">#${tile}</span></button>`).join('\n      ')}
    </div>
  </section>
  <section class="panel" aria-labelledby="result-title">
    <h2 id="result-title"><label for="selection">选择结果（JSON）</label></h2>
    <textarea id="selection" readonly spellcheck="false">${JSON.stringify(DEFAULT_SELECTION, null, 2)}</textarea>
    <button type="button" id="copy">复制选择</button><span id="status" role="status" aria-live="polite"></span>
    <p class="hint">来源：<a href="https://kenney.nl/assets/cursor-pixel-pack" target="_blank" rel="noreferrer">Kenney · Cursor Pixel Pack</a> · <a href="https://creativecommons.org/publicdomain/zero/1.0/" target="_blank" rel="noreferrer">CC0</a>。本页所有图片均已内嵌，可离线使用。</p>
  </section>
</main>
<script>
const ACTIONS = ${JSON.stringify(ACTIONS)};
const CANDIDATE_IDS = ${JSON.stringify(CANDIDATE_IDS)};
const DEFAULT_SELECTION = ${JSON.stringify(DEFAULT_SELECTION)};
const images = ${JSON.stringify(images)};
${selectCursor.toString()}
(${mountPicker.toString()})();
</script>
</body>
</html>
`;
  await writeFile(OUTPUT_PATH, html);
  return OUTPUT_PATH;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(await generatePicker());
}
