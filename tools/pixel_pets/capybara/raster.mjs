// 像素栅格：不可变网格 + 形状判定 + 描边。浏览器编辑器和命令行渲染共用。
//
// 坐标：x 向右、y 向下，像素 (x, y) 的中心是 (x + 0.5, y + 0.5)。

export const INKS = [
  'clear', 'outline', 'body', 'shade', 'light', 'dark', 'muzzle', 'belly',
  'white', 'blush', 'grass', 'sweat', 'star', 'dust', 'bird', 'birdWing',
];

export class Grid {
  constructor(width, height, cells) {
    this.width = width;
    this.height = height;
    this.cells = cells ?? new Array(width * height).fill('clear');
    Object.freeze(this.cells);
    Object.freeze(this);
  }

  static empty(width, height) {
    return new Grid(width, height);
  }

  get(x, y) {
    if (x < 0 || y < 0 || x >= this.width || y >= this.height) return 'clear';
    return this.cells[y * this.width + x];
  }

  /** 返回新网格：test(x, y, current) 为真的格子涂成 ink */
  paint(ink, test) {
    const next = this.cells.map((current, i) => {
      const x = i % this.width;
      const y = Math.floor(i / this.width);
      return test(x, y, current) ? ink : current;
    });
    return new Grid(this.width, this.height, next);
  }

  /** 按 mask 填色；onlyOver 指定时只覆盖该颜色 */
  fill(ink, mask, onlyOver = null) {
    return this.paint(ink, (x, y, current) => mask(x, y) && (onlyOver === null || current === onlyOver));
  }

  dots(ink, points) {
    const keys = new Set(points.map(([x, y]) => `${x},${y}`));
    return this.paint(ink, (x, y) => keys.has(`${x},${y}`));
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
    const next = this.cells.map((_, i) => {
      const x = i % this.width;
      const y = Math.floor(i / this.width);
      const shift = Math.round(slope * Math.max(0, y - pivotRow));
      return this.get(x - shift, y);
    });
    return new Grid(this.width, this.height, next);
  }

  translated(dx, dy) {
    const next = this.cells.map((_, i) => this.get((i % this.width) - dx, Math.floor(i / this.width) - dy));
    return new Grid(this.width, this.height, next);
  }

  /** 叠加另一层（透明处保留下层） */
  overlaid(top) {
    const next = this.cells.map((current, i) => (top.cells[i] === 'clear' ? current : top.cells[i]));
    return new Grid(this.width, this.height, next);
  }

  /** 截取 [x0, x0 + width) 列 */
  cropped(x0, width) {
    const next = [];
    for (let y = 0; y < this.height; y += 1) {
      for (let x = 0; x < width; x += 1) next.push(this.get(x0 + x, y));
    }
    return new Grid(width, this.height, next);
  }

  /** 取一个窗口 [x0, x0 + width) × [y0, y0 + height)，超出部分透明 */
  windowed(x0, y0, width, height) {
    const next = [];
    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) next.push(this.get(x0 + x, y0 + y));
    }
    return new Grid(width, height, next);
  }

  /** 按 90° 整格旋转（不重采样）：turns = 1 顺时针，-1 逆时针，2 半圈 */
  rotatedQuarter(turns) {
    const t = ((turns % 4) + 4) % 4;
    if (t === 0) return this;
    if (t === 2) return this.mirrored().flippedVertically();
    const { width: w, height: h } = this;
    const next = [];
    for (let y = 0; y < w; y += 1) {
      for (let x = 0; x < h; x += 1) {
        // 新网格宽 h、高 w
        next.push(t === 1 ? this.get(y, h - 1 - x) : this.get(w - 1 - y, x));
      }
    }
    return new Grid(h, w, next);
  }

  flippedVertically() {
    const next = this.cells.map((_, i) => this.get(i % this.width, this.height - 1 - Math.floor(i / this.width)));
    return new Grid(this.width, this.height, next);
  }

  mirrored() {
    const next = this.cells.map((_, i) => this.get(this.width - 1 - (i % this.width), Math.floor(i / this.width)));
    return new Grid(this.width, this.height, next);
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
