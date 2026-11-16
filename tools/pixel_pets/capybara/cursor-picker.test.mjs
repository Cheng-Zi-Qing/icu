import assert from 'node:assert/strict';
import { test } from 'node:test';
import { access, readFile, readdir, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inflateSync } from 'node:zlib';
import { ACTIONS, CANDIDATE_IDS, DEFAULT_SELECTION, OUTPUT_PATH, REFERENCE_DIR, selectCursor } from './cursor-picker.mjs';

const EXPECTED_IDS = [134, 135, 136, 137, 138, 139, 154, 155, 156, 157, 158, 159, 175, 176, 177, 178, 179];
const GENERATOR = fileURLToPath(new URL('./cursor-picker.mjs', import.meta.url));

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function assertPNG(png) {
  assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  const chunks = [];
  const compressed = [];
  let offset = 8;
  while (offset < png.length) {
    const size = png.readUInt32BE(offset);
    const end = offset + size + 12;
    assert.ok(end <= png.length);
    const type = png.toString('ascii', offset + 4, offset + 8);
    assert.equal(crc32(png.subarray(offset + 4, end - 4)), png.readUInt32BE(end - 4), `${type} checksum`);
    chunks.push(type);
    if (type === 'IDAT') compressed.push(png.subarray(offset + 8, end - 4));
    offset = end;
  }
  assert.equal(chunks[0], 'IHDR');
  assert.equal(chunks.at(-1), 'IEND');
  assert.ok(chunks.includes('PLTE'));
  assert.deepEqual([png.readUInt32BE(16), png.readUInt32BE(20)], [16, 16]);
  const bitDepth = png[24];
  assert.ok([1, 2, 4, 8].includes(bitDepth));
  assert.equal(png[25], 3, 'original indexed PNG');
  assert.deepEqual([...png.subarray(26, 29)], [0, 0, 0], 'standard compression/filter, no interlace');
  const raw = inflateSync(Buffer.concat(compressed));
  const rowLength = 1 + Math.ceil(16 * bitDepth / 8);
  assert.equal(raw.length, rowLength * 16);
  for (let y = 0; y < 16; y += 1) assert.ok(raw[y * rowLength] <= 4, 'valid PNG row filter');
}

test('all 17 original references are valid 16px PNGs, with the original CC0 license', async () => {
  assert.deepEqual(CANDIDATE_IDS, EXPECTED_IDS);
  assert.deepEqual((await readdir(REFERENCE_DIR)).sort(), ['License.txt', ...EXPECTED_IDS.map((id) => `tile_${String(id).padStart(4, '0')}.png`)].sort());
  for (const id of CANDIDATE_IDS) {
    assertPNG(await readFile(`${REFERENCE_DIR}/tile_${String(id).padStart(4, '0')}.png`));
  }
  const license = await readFile(`${REFERENCE_DIR}/License.txt`, 'utf8');
  assert.match(license, /Kenney/);
  assert.match(license, /Creative Commons Zero, CC0/);
});

test('selecting one action preserves the other three and leaves the input unchanged', () => {
  assert.deepEqual(DEFAULT_SELECTION, { pat: 136, tickle: 135, grabbing: 139, poke: 175 });
  const result = selectCursor(DEFAULT_SELECTION, 'pat', 176);
  assert.deepEqual(result, { pat: 176, tickle: 135, grabbing: 139, poke: 175 });
  assert.equal(DEFAULT_SELECTION.pat, 136);
  assert.notEqual(result, DEFAULT_SELECTION);
});

test('every action accepts every candidate and duplicate selections serialize to the four-action JSON', () => {
  for (const action of Object.keys(ACTIONS)) {
    for (const tile of CANDIDATE_IDS) assert.equal(selectCursor(DEFAULT_SELECTION, action, tile)[action], tile);
  }
  let selection = DEFAULT_SELECTION;
  for (const action of Object.keys(ACTIONS)) selection = selectCursor(selection, action, 139);
  assert.deepEqual(JSON.parse(JSON.stringify(selection)), { pat: 139, tickle: 139, grabbing: 139, poke: 139 });
});

test('invalid actions and tile IDs are rejected', () => {
  for (const action of ['grab', 'constructor', '__proto__', '', null]) {
    assert.throws(() => selectCursor(DEFAULT_SELECTION, action, 136), RangeError);
  }
  for (const tile of [0, 133, 140, 180, 220, '136', null, NaN, 136.5]) {
    assert.throws(() => selectCursor(DEFAULT_SELECTION, 'pat', tile), RangeError);
  }
});

test('actual CLI produces a self-contained page with four actions and 17 candidates, without runtime asset access', async () => {
  // Node permissions enforce read-only references and permit only the requested HTML write,
  // avoiding snapshots of runtime assets that another agent may be changing concurrently.
  const result = spawnSync(process.execPath, [
    '--permission', `--allow-fs-read=${GENERATOR}`, `--allow-fs-read=${REFERENCE_DIR}`, `--allow-fs-write=${OUTPUT_PATH}`, GENERATOR,
  ], { encoding: 'utf8', timeout: 10000 });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), OUTPUT_PATH);
  const html = await readFile(OUTPUT_PATH, 'utf8');
  assert.deepEqual([...html.matchAll(/data-action="(\w+)"/g)].map((match) => match[1]), Object.keys(ACTIONS));
  assert.deepEqual([...html.matchAll(/data-tile="(\d+)"/g)].map((match) => Number(match[1])), CANDIDATE_IDS);
  assert.equal([...html.matchAll(/<img\b/g)].length, (4 + 17) * 2);
  const resources = [...html.matchAll(/\bsrc="([^"]+)"/g)].map((match) => match[1]);
  assert.equal(resources.length, (4 + 17) * 2);
  for (const resource of resources) assert.match(resource, /^data:image\/png;base64,[A-Za-z0-9+/=]+$/);
  assert.doesNotMatch(html, /<(?:link|iframe|object|embed)\b|\b(?:fetch|XMLHttpRequest|WebSocket)\s*\(|@import|url\s*\(/i);
  assert.match(html, /connect-src 'none'/);
  assert.match(html, /image-rendering: pixelated/);
  assert.match(html, /这里只选图，不会直接修改ICU；选好后复制结果给助手统一应用/);
  assert.match(html, /https:\/\/kenney.nl\/assets\/cursor-pixel-pack/);
  assert.match(html, /https:\/\/creativecommons.org\/publicdomain\/zero\/1.0\//);
  assert.doesNotMatch(html, /assets\/pets|hotSpot|localhost/);

  const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  try { await access(chrome); } catch { return; }
  const browserCheck = `${OUTPUT_PATH.slice(0, -5)}-browser-check.html`;
  const checks = `
<script>
(async () => {
  try {
    const output = document.getElementById('selection');
    const getSelection = () => JSON.parse(output.value);
    const check = (value, message) => { if (!value) throw new Error(message); };
    document.querySelector('[data-tile="176"]').click();
    check(output.value === JSON.stringify({pat:176,tickle:135,grabbing:139,poke:175}, null, 2), 'pat preserves other actions');
    for (const action of ['pat', 'tickle', 'grabbing', 'poke']) {
      document.querySelector('[data-action="' + action + '"]').click();
      check(document.querySelectorAll('[data-action][aria-pressed="true"]').length === 1, 'one current action');
      for (const tile of [134,135,136,137,138,139,154,155,156,157,158,159,175,176,177,178,179]) {
        document.querySelector('[data-tile="' + tile + '"]').click();
        check(getSelection()[action] === tile, 'candidate click updates JSON');
        check(document.querySelector('[data-tile="' + tile + '"]').getAttribute('aria-pressed') === 'true', 'candidate highlighted');
        check(document.querySelectorAll('[data-tile][aria-pressed="true"]').length === 1, 'one current candidate');
        check(document.querySelector('[data-action="' + action + '"] .tile-id').textContent === '#' + tile, 'selection preview ID updates');
        check(document.querySelector('[data-action="' + action + '"] img').src === document.querySelector('[data-tile="' + tile + '"] img').src, 'selection preview image updates');
      }
      document.querySelector('[data-tile="139"]').click();
    }
    check(Object.values(getSelection()).every(tile => tile === 139), 'shared selections allowed');
    await Promise.all([...document.images].map(image => image.decode()));
    check([...document.images].every(image => image.naturalWidth === 16 && image.naturalHeight === 16), 'embedded PNGs decode');
    check([...document.images].every(image => getComputedStyle(image).imageRendering === 'pixelated'), 'pixelated rendering');
    let copied;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async text => { copied = text; } } });
    document.getElementById('copy').click();
    await Promise.resolve();
    check(copied === output.value, 'copy receives current JSON');
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async () => { throw new Error('denied'); } } });
    document.getElementById('copy').click();
    await Promise.resolve();
    check(document.activeElement === output && output.selectionStart === 0 && output.selectionEnd === output.value.length, 'failed copy selects entire JSON');
    check(document.getElementById('status').textContent.includes('手动复制'), 'manual copy hint');
    document.body.dataset.browserCheck = 'passed';
  } catch (error) {
    document.body.dataset.browserCheck = 'failed: ' + error.message;
  }
})();
</script>`;
  await writeFile(browserCheck, html.replace('</body>', `${checks}\n</body>`));
  const browser = spawnSync(chrome, [
    '--headless', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--disable-background-networking',
    `--user-data-dir=/tmp/icu-cursor-picker-chrome-${process.pid}`, '--virtual-time-budget=5000', '--dump-dom', `file://${browserCheck}`,
  ], { encoding: 'utf8', timeout: 30000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(browser.status, 0, browser.error?.message ?? browser.stderr);
  const outcome = browser.stdout.match(/data-browser-check="([^"]+)"/)?.[1];
  assert.equal(outcome, 'passed', `Chrome interaction checks: ${outcome ?? 'no result'}\n${browser.stderr}`);
});
