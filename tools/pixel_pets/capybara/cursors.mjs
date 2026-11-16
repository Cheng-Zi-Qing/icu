// Kenney Cursor Pixel Pack hands, with the original black pixels mapped to ICU outline.
// 16x16 source pixels export at 3x (24pt on Retina).
import { Grid } from './raster.mjs';

export const CURSOR_SIZE = 16;
export const CURSOR_SCALE = 3;
/** 光标在屏幕上的边长（pt）：16px × 1.5pt */
export const CURSOR_POINT_SIZE = 24;

// Kenney tile_0136.png; https://kenney.nl/assets/cursor-pixel-pack
const PAT = [
  '................', '................', '....XXXXXXXXX...', '...XXXXXXXXXXX..',
  '..XXX#X##X##XXX.', '..XX#########XX.', '..XX#########XX.', '.XXXX########XXX',
  '.XX###########XX', '.XX###########XX', '.XX###########XX', '.XXX##########XX',
  '..XXXX#######XXX', '...XXXX#####XXX.', '.....XXXXXXXXX..', '......XXXXXXX...',
];
// Kenney tile_0135.png; https://kenney.nl/assets/cursor-pixel-pack
const TICKLE = [
  '......XXXX......', '...XXXXXXXXXX...', '..XXXXX##XXXXX..', '..XX##X##X##XX..',
  '..XX##X##X##XXX.', '..XX###X##X##XX.', '..XX#########XX.', '.XXXX########XXX',
  'XXXXX#########XX', 'XX############XX', 'XX############XX', 'XXXX##########XX',
  '.XXXXX#######XXX', '...XXXX#####XXX.', '.....XXXXXXXXX..', '......XXXXXXX...',
];
// Kenney tile_0139.png; https://kenney.nl/assets/cursor-pixel-pack
const GRABBING = [
  '................', '................', '................', '....XXXXXXXXXX..',
  '...XXXXXXXXXXXX.', '..XXX##X##X##XX.', '.XXXX########XXX', '.XX###########XX',
  '.XX###########XX', '.XX###########XX', '.XXX##########XX', '..XXX########XXX',
  '...XX########XX.', '...XXX######XXX.', '....XXXXXXXXXX..', '.....XXXXXXXX...',
];
// Kenney tile_0175.png; https://kenney.nl/assets/cursor-pixel-pack
const POKE = [
  '..XXX...........', '.XXXXX..........', 'XXX#XXXXXX......', 'XX###XXXXXXX....',
  'XX#######XXXX...', 'XXX########XXX..', 'XXXX########XX..', 'XX##X#######XXX.',
  'XX###########XXX', 'XXX###########XX', '.XXX##########XX', '..XXXXXX######XX',
  '...XXXXX#####XXX', '......XX###XXXX.', '......XXXXXXXX..', '.......XXXXX....',
];
// Kenney tile_0138.png; https://kenney.nl/assets/cursor-pixel-pack
const GRAB = [
  '.......XXXX.....', '....XXXXXXXXXX..', '...XXXXX##XXXXX.', '...XX##X##X##XX.',
  '...XX##X##X##XX.', '.XXXX##X##X##XX.', 'XXXXX########XXX', 'XX##X#########XX',
  'XX############XX', 'XXX###########XX', '.XXX##########XX', '..XXX########XXX',
  '...XX########XX.', '...XXX######XXX.', '....XXXXXXXXXX..', '.....XXXXXXXX...',
];

function fromRows(rows) {
  return new Grid(CURSOR_SIZE, CURSOR_SIZE, rows.join('').split('').map((pixel) => (
    pixel === 'X' ? 'outline' : pixel === '#' ? 'white' : 'clear'
  )));
}

/** 光标定义：网格 + 热点（像素坐标，左上角原点） */
export function cursorDefinitions() {
  return {
    pat: { grid: fromRows(PAT), hotSpot: [7, 5] },
    tickle: { grid: fromRows(TICKLE), hotSpot: [4, 3] },
    grabbing: { grid: fromRows(GRABBING), hotSpot: [8, 7] },
    poke: { grid: fromRows(POKE), hotSpot: [3, 2] },
    grab: { grid: fromRows(GRAB), hotSpot: [8, 3] },
  };
}

/** 光标元数据（Swift 端按它设热点），热点按像素给，scale 是导出倍数 */
export function cursorManifest() {
  const definitions = cursorDefinitions();
  return {
    pixelSize: CURSOR_SIZE,
    pointSize: CURSOR_POINT_SIZE,
    cursors: Object.fromEntries(Object.entries(definitions).map(([name, { hotSpot }]) => [name, { file: `${name}.png`, hotSpot }])),
  };
}
