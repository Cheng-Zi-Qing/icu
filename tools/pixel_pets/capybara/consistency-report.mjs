// 命令行：node consistency-report.mjs
// 把全部素材帧过一遍体型检查，同一组帧（同一个动作）的同一种问题合成一行
import { writeFileSync } from 'node:fs';
import { DEFAULT_MODEL, PALETTE } from './model.mjs';
import { allFrames } from './render.mjs';
import { encodePNG } from './png.mjs';
import { checkConsistency } from './consistency.mjs';
import { GUIDE_COLOR, GUIDE_INK, turnaround } from './turnaround.mjs';

/** 路径去掉帧号：idle/main/12.png → idle/main */
const groupOf = (path) => path.replace(/_?[-0-9]+(_[-0-9]+)*\.png$/, '').replace(/\.png$/, '').replace(/\/$/, '');

export function groupedIssues(issues) {
  const groups = new Map();
  for (const found of issues) {
    const key = `${groupOf(found.path)} · ${found.check}`;
    const entry = groups.get(key) ?? { key, expected: found.expected, actual: new Set(), frames: 0 };
    groups.set(key, { ...entry, actual: new Set([...entry.actual, found.actual]), frames: entry.frames + 1 });
  }
  return [...groups.values()];
}

export function formatReport(result) {
  const lines = [`检查了 ${result.checked} 帧，${result.issues.length} 处不一致`];
  for (const group of groupedIssues(result.issues)) {
    const actual = [...group.actual];
    const shown = actual.length > 3 ? `${actual.slice(0, 3).join('；')} …` : actual.join('；');
    lines.push(`✗ ${group.key}（${group.frames} 帧）  应为 ${group.expected}，实际 ${shown}`);
  }
  if (result.missingViews.length) lines.push(`· 还没有的视角：${result.missingViews.join('、')}`);
  lines.push(`· 头被挡住、没算错的帧：${result.notes.length}`);
  return lines.join('\n');
}

/** 三视图对照图写成 PNG（8 倍） */
function writeSheet(path) {
  const { grid } = turnaround(DEFAULT_MODEL);
  writeFileSync(path, encodePNG(grid, { scale: 8, palette: { ...PALETTE, [GUIDE_INK]: GUIDE_COLOR } }));
  console.log(`三视图对照图：${path}`);
}

// 用法：node consistency-report.mjs [--sheet 对照图.png]
if (import.meta.url === `file://${process.argv[1]}`) {
  const result = checkConsistency(allFrames(DEFAULT_MODEL), DEFAULT_MODEL);
  console.log(formatReport(result));
  const sheetAt = process.argv.indexOf('--sheet');
  if (sheetAt > 0) {
    const path = process.argv[sheetAt + 1];
    if (!path) throw new Error('--sheet 后面要给输出的 PNG 路径');
    writeSheet(path);
  }
  process.exitCode = result.issues.length ? 1 : 0;
}
