// 像素栅格：不可变网格 + 形状判定 + 描边。浏览器编辑器和命令行渲染共用。
//
// 坐标：x 向右、y 向下，像素 (x, y) 的中心是 (x + 0.5, y + 0.5)。

export const INKS = [
  'clear', 'outline', 'body', 'shade', 'light', 'dark', 'muzzle', 'belly',
  'white', 'blush', 'grass', 'sweat', 'star', 'dust', 'bird', 'birdWing', 'orange',
  'straw', 'strawShade', 'band', 'leaf', 'metal', 'metalDark',
];

/**
 * 部位标签：每个像素除了颜色，还记着它是水豚的哪一块（体型检查按部位量，不按颜色量）。
 * 颜色会变（腿改深色、肚皮去掉），部位不会
 */
export const TAGS = Object.freeze(['head', 'body', 'leg', 'paw', 'prop', 'outline']);

/** 身体部件按 id 归到部位：爪 / 脚 → paw，腿 → leg，其余是身体（头的部件由画头时统一标 head） */
export function partTag(id = '') {
  if (/paw|foot/i.test(id)) return 'paw';
  if (/leg/i.test(id)) return 'leg';
  return 'body';
}

/** 没指定部位时：涂在已有颜色上沿用原来的部位（脸上的眼睛还是头）；涂在空白处是描边或道具 */
function inferredTag(ink, currentInk, currentTag) {
  if (ink === 'clear') return null;
  if (currentInk !== 'clear') return currentTag;
  return ink === 'outline' ? 'outline' : 'prop';
}

export class Grid {
  constructor(width, height, cells, tags) {
    this.width = width;
    this.height = height;
    this.cells = cells ?? new Array(width * height).fill('clear');
    this.tags = tags ?? new Array(width * height).fill(null);
    Object.freeze(this.cells);
    Object.freeze(this.tags);
    Object.freeze(this);
  }

  static empty(width, height) {
    return new Grid(width, height);
  }

  get(x, y) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return 'clear';
    return this.cells[y * this.width + x];
  }

  /** 这个像素属于哪个部位（TAGS 之一；空白为 null） */
  tagAt(x, y) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return null;
    return this.tags[y * this.width + x];
  }

  /** 按坐标搬像素：新网格 (x, y) 取原网格 source(x, y) 那一格，颜色和部位一起搬 */
  sampled(width, height, source) {
    const cells = [];
    const tags = [];
    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const [sx, sy] = source(x, y);
        cells.push(this.get(sx, sy));
        tags.push(this.tagAt(sx, sy));
      }
    }
    return new Grid(width, height, cells, tags);
  }

  /** 返回新网格：test(x, y, current) 为真的格子涂成 ink；tag 是这些格子的部位（不给就按 inferredTag 推） */
  paint(ink, test, tag = null) {
    const cells = [];
    const tags = [];
    this.cells.forEach((current, i) => {
      const hit = test(i % this.width, Math.floor(i / this.width), current);
      cells.push(hit ? ink : current);
      tags.push(hit ? (tag ?? inferredTag(ink, current, this.tags[i])) : this.tags[i]);
    });
    return new Grid(this.width, this.height, cells, tags);
  }

  /** 按 mask 填色；onlyOver 指定时只覆盖该颜色 */
  fill(ink, mask, onlyOver = null, tag = null) {
    return this.paint(ink, (x, y, current) => mask(x, y) && (onlyOver === null || current === onlyOver), tag);
  }

  dots(ink, points, tag = null) {
    const keys = new Set(points.map(([x, y]) => `${x},${y}`));
    return this.paint(ink, (x, y) => keys.has(`${x},${y}`), tag);
  }

  /** 剪影外圈 1px 描边（4 邻接） */
  outlined() {
    return this.paint('outline', (x, y, current) => {
      if (current !== 'clear') return false;
      return NEIGHBORS.some(([dx, dy]) => {
        const n = this.get(x + dx, y + dy);
        return n !== 'clear' && n !== 'outline';
      });
    });
  }

  /** 剪影内部分界线：mask 外侧、紧贴 mask 的已上色像素涂成轮廓色 */
  edged(mask, sides) {
    return this.paint('outline', (x, y, current) => {
      if (mask(x, y) || current === 'clear' || current === 'outline') return false;
      return sides.some(([dx, dy]) => mask(x + dx, y + dy));
    });
  }

  /** 按行水平错切：pivotRow 以下的行按坡度平移（正角度下半往右） */
  sheared(degrees, pivotRow) {
    const slope = Math.tan((degrees * Math.PI) / 180);
    return this.sampled(this.width, this.height, (x, y) => [x - Math.round(slope * Math.max(0, y - pivotRow)), y]);
  }

  translated(dx, dy) {
    return this.sampled(this.width, this.height, (x, y) => [x - dx, y - dy]);
  }

  /** 叠加另一层（透明处保留下层） */
  overlaid(top) {
    const cells = this.cells.map((current, i) => (top.cells[i] === 'clear' ? current : top.cells[i]));
    const tags = this.tags.map((current, i) => (top.cells[i] === 'clear' ? current : top.tags[i]));
    return new Grid(this.width, this.height, cells, tags);
  }

  /** 截取 [x0, x0 + width) 列 */
  cropped(x0, width) {
    return this.sampled(width, this.height, (x, y) => [x0 + x, y]);
  }

  /** 取一个窗口 [x0, x0 + width) × [y0, y0 + height)，超出部分透明 */
  windowed(x0, y0, width, height) {
    return this.sampled(width, height, (x, y) => [x0 + x, y0 + y]);
  }

  /** 按 90° 整格旋转（不重采样）：turns = 1 顺时针，-1 逆时针，2 半圈 */
  rotatedQuarter(turns) {
    const t = ((turns % 4) + 4) % 4;
    if (t === 0) return this;
    if (t === 2) return this.mirrored().flippedVertically();
    const { width: w, height: h } = this;
    // 新网格宽 h、高 w
    return this.sampled(h, w, (x, y) => (t === 1 ? [y, h - 1 - x] : [w - 1 - y, x]));
  }

  flippedVertically() {
    return this.sampled(this.width, this.height, (x, y) => [x, this.height - 1 - y]);
  }

  mirrored() {
    return this.sampled(this.width, this.height, (x, y) => [this.width - 1 - x, y]);
  }
}

export const NEIGHBORS = [[1, 0], [-1, 0], [0, 1], [0, -1]];
export const SIDES = {
  below: [[0, -1]],
  above: [[0, 1]],
  around: NEIGHBORS,
  inner: [[0, -1], [-1, 0], [1, 0]],
};

// ---------- 形状（局部坐标判定） ----------

/** 点 (px, py) 是否在形状里；形状参数都在同一坐标系 */
export function shapeContains(part, px, py) {
  switch (part.shape) {
    case 'ellipse': {
      const [lx, ly] = rotateAround(px, py, part.cx, part.cy, -(part.rot ?? 0));
      const dx = (lx - part.cx) / Math.max(part.rx, 0.01);
      const dy = (ly - part.cy) / Math.max(part.ry, 0.01);
      return dx * dx + dy * dy <= 1;
    }
    case 'rbox': {
      const [lx, ly] = rotateAround(px, py, part.cx, part.cy, -(part.rot ?? 0));
      const hw = part.w / 2;
      const hh = part.h / 2;
      const r = Math.min(part.r ?? 0, hw, hh);
      const qx = Math.abs(lx - part.cx) - (hw - r);
      const qy = Math.abs(ly - part.cy) - (hh - r);
      if (qx <= 0 && qy <= 0) return true;
      return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) <= r;
    }
    case 'capsule': {
      const vx = part.x2 - part.x1;
      const vy = part.y2 - part.y1;
      const len2 = vx * vx + vy * vy || 1e-6;
      const t = Math.max(0, Math.min(1, ((px - part.x1) * vx + (py - part.y1) * vy) / len2));
      return Math.hypot(px - (part.x1 + t * vx), py - (part.y1 + t * vy)) <= part.r;
    }
    default:
      return false;
  }
}

export function rotateAround(x, y, cx, cy, degrees) {
  const a = (degrees * Math.PI) / 180;
  const cos = Math.cos(a);
  const sin = Math.sin(a);
  const dx = x - cx;
  const dy = y - cy;
  return [cx + dx * cos - dy * sin, cy + dx * sin + dy * cos];
}

/** 组变换：局部点 → 画布点 */
export function toCanvas(transform, lx, ly) {
  const s = transform.scale ?? 1;
  const [rx, ry] = rotateAround(lx * s, ly * s, 0, 0, transform.rot ?? 0);
  return [transform.x + rx, transform.y + ry];
}

/** 组变换：画布点 → 局部点 */
export function toLocal(transform, px, py) {
  const s = transform.scale ?? 1;
  const [rx, ry] = rotateAround(px - transform.x, py - transform.y, 0, 0, -(transform.rot ?? 0));
  return [rx / s, ry / s];
}

/** 形状在画布像素上的 mask（可选组变换） */
export function partMask(part, transform = null) {
  return (x, y) => {
    const cx = x + 0.5;
    const cy = y + 0.5;
    if (!transform) return shapeContains(part, cx, cy);
    const [lx, ly] = toLocal(transform, cx, cy);
    return shapeContains(part, lx, ly);
  };
}

/** 局部坐标点 → 取整后的画布像素 */
export function canvasPixel(transform, lx, ly) {
  const [x, y] = toCanvas(transform, lx, ly);
  return [Math.floor(x), Math.floor(y)];
}
