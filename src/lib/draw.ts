// Vẽ bản đo lên canvas: mặt bằng 2D (tường, cửa đi có cung mở, cửa sổ, kích thước) và khung 3D isometric
// kiểu "nhà búp bê" (tường sau dựng đủ cao, tường trước cắt thấp để nhìn vào trong). Port từ painters.dart.

import { vnDecimal } from './format';
import { bounds, edgeLength, edges, floorArea, outward, type Opening, type Plan, type Room } from './measure';

const C = {
  primary: '#304FFE',
  text: '#1B1D28',
  muted: '#6B7280',
  border: '#E6E8EC',
};

const roomColors: Record<string, string> = {
  living: '#E8ECFF',
  bedroom: '#FFF3D6',
  kitchen: '#E3F5EA',
  bathroom: '#DDF1F8',
  balcony: '#EFEFF2',
  other: '#F4F5F7',
};

export const roomColor = (type: string) => roomColors[type] ?? roomColors.other;

const FONT = '"Be Vietnam Pro", system-ui, sans-serif';

/** Mét ↔ điểm ảnh của mặt bằng 2D, để vẽ và để chạm chọn / kéo phòng dùng chung một phép đổi. */
export class PlanTransform {
  scale: number;
  ox: number;
  oy: number;

  constructor(plan: Plan, width: number, height: number, padding = 28) {
    const [minX, minY, maxX, maxY] = bounds(plan);
    const w = Math.max(maxX - minX, 1), h = Math.max(maxY - minY, 1);
    this.scale = Math.min((width - 2 * padding) / w, (height - 2 * padding) / h);
    this.ox = (width - w * this.scale) / 2 - minX * this.scale;
    this.oy = (height - h * this.scale) / 2 - minY * this.scale;
  }

  toScreen = (x: number, y: number): [number, number] => [this.ox + x * this.scale, this.oy + y * this.scale];
  toPlan = (px: number, py: number): [number, number] => [(px - this.ox) / this.scale, (py - this.oy) / this.scale];
}

/** Điểm trong đa giác phòng (tia ngang, đếm số lần cắt cạnh): phần góc đã cắt không bắt chạm. */
export function insideRoom(r: Room, x: number, y: number): boolean {
  let inside = false;
  for (const e of edges(r)) {
    if ((e.y0 > y) !== (e.y1 > y) && x < ((e.x1 - e.x0) * (y - e.y0)) / (e.y1 - e.y0) + e.x0) inside = !inside;
  }
  return inside;
}

const fmt = (v: number) => {
  const digits = v === Math.round(v) ? 0 : v * 10 === Math.round(v * 10) ? 1 : 2;
  return vnDecimal(v.toFixed(digits));
};

function polygon(ctx: CanvasRenderingContext2D, pts: [number, number][]) {
  ctx.beginPath();
  pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
  ctx.closePath();
}

function line(ctx: CanvasRenderingContext2D, a: [number, number], b: [number, number], color: string, width: number) {
  ctx.beginPath();
  ctx.moveTo(a[0], a[1]);
  ctx.lineTo(b[0], b[1]);
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.stroke();
}

/** Đoạn cửa trên tường (điểm ảnh) và hướng vào trong phòng. */
function openingSegment(t: PlanTransform, r: Room, o: Opening): [[number, number], [number, number], [number, number]] {
  switch (o.wall) {
    case 'n': return [t.toScreen(r.x + o.offset, r.y), t.toScreen(r.x + o.offset + o.width, r.y), [0, 1]];
    case 's': return [t.toScreen(r.x + o.offset, r.y + r.l), t.toScreen(r.x + o.offset + o.width, r.y + r.l), [0, -1]];
    case 'w': return [t.toScreen(r.x, r.y + o.offset), t.toScreen(r.x, r.y + o.offset + o.width), [1, 0]];
    default: return [t.toScreen(r.x + r.w, r.y + o.offset), t.toScreen(r.x + r.w, r.y + o.offset + o.width), [-1, 0]];
  }
}

/** Mặt bằng 2D. [transform] giữ cố định khi đang kéo phòng, để mặt bằng không tự co giãn dưới ngón tay. */
export function drawPlan(
  ctx: CanvasRenderingContext2D, plan: Plan, width: number, height: number,
  selectedId?: string | null, transform?: PlanTransform | null,
) {
  const t = transform ?? new PlanTransform(plan, width, height);
  // Lưới 1 m.
  const [sx0, sy0] = t.toPlan(0, 0), [sx1, sy1] = t.toPlan(width, height);
  for (let x = Math.floor(sx0); x <= sx1; x++) line(ctx, [t.toScreen(x, 0)[0], 0], [t.toScreen(x, 0)[0], height], 'rgba(230,232,236,.6)', 1);
  for (let y = Math.floor(sy0); y <= sy1; y++) line(ctx, [0, t.toScreen(0, y)[1]], [width, t.toScreen(0, y)[1]], 'rgba(230,232,236,.6)', 1);
  // Phòng đang chọn vẽ sau cùng để viền nổi lên trên.
  const rooms = [...plan.rooms].sort((a, b) => (a.id === selectedId ? 1 : 0) - (b.id === selectedId ? 1 : 0));
  for (const r of rooms) drawRoom(ctx, t, r, r.id === selectedId);
}

function drawRoom(ctx: CanvasRenderingContext2D, t: PlanTransform, r: Room, selected: boolean) {
  const [left, top] = t.toScreen(r.x, r.y), [right, bottom] = t.toScreen(r.x + r.w, r.y + r.l);
  const rw = right - left, rh = bottom - top;
  const shape = edges(r).map((e) => t.toScreen(e.x0, e.y0));
  polygon(ctx, shape);
  ctx.fillStyle = roomColor(r.type);
  ctx.fill();
  ctx.strokeStyle = selected ? C.primary : C.text;
  ctx.lineWidth = selected ? 4 : 3;
  ctx.lineJoin = 'miter';
  ctx.stroke();

  // Phần bị cắt góc: gạch chéo nhẹ để thấy đó là cột / hộp kỹ thuật, không phải khoảng trống.
  if (r.cuts.length) {
    ctx.save();
    ctx.beginPath();
    ctx.rect(left, top, rw, rh);
    shape.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
    ctx.closePath();
    ctx.clip('evenodd');
    for (let d = -rh; d < rw; d += 6) line(ctx, [left + d, top + rh], [left + d + rh, top], 'rgba(107,114,128,.45)', 1);
    ctx.restore();
  }

  for (const o of r.openings) {
    const [a, b, inward] = openingSegment(t, r, o);
    // Xoá đoạn tường chỗ cửa, rồi vẽ ký hiệu.
    line(ctx, a, b, roomColor(r.type), 6);
    const dx = b[0] - a[0], dy = b[1] - a[1], len = Math.hypot(dx, dy);
    if (len === 0) continue;
    if (o.kind === 'door') {
      line(ctx, a, [a[0] + inward[0] * len, a[1] + inward[1] * len], C.muted, 1.2);
      const angle = Math.atan2(dy, dx);
      const sweep = inward[0] * dy - inward[1] * dx > 0 ? -Math.PI / 2 : Math.PI / 2;
      ctx.beginPath();
      ctx.arc(a[0], a[1], len, angle, angle + sweep, sweep < 0);
      ctx.strokeStyle = C.muted;
      ctx.lineWidth = 1.2;
      ctx.stroke();
    } else {
      const nx = (-dy / len) * 2.5, ny = (dx / len) * 2.5;
      line(ctx, [a[0] + nx, a[1] + ny], [b[0] + nx, b[1] + ny], '#3AA0E0', 2);
      line(ctx, [a[0] - nx, a[1] - ny], [b[0] - nx, b[1] - ny], '#3AA0E0', 2);
    }
  }

  // Nhãn: tên + diện tích; phòng quá nhỏ trên màn hình thì bỏ.
  const cx = left + rw / 2, cy = top + rh / 2;
  if (rh > 30 && rw > 30) {
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `700 11px ${FONT}`;
    ctx.fillStyle = selected ? C.primary : C.text;
    ctx.fillText(ellipsize(ctx, r.name, rw - 6), cx, cy - 7);
    ctx.font = `400 10px ${FONT}`;
    ctx.fillStyle = C.muted;
    ctx.fillText(`${fmt(floorArea(r))} m²`, cx, cy + 7);
  }

  if (selected) {
    tag(ctx, `${fmt(r.w)} m`, cx, top - 14, false);
    tag(ctx, `${fmt(r.l)} m`, left - 14, cy, true);
  }
}

function ellipsize(ctx: CanvasRenderingContext2D, s: string, max: number) {
  if (ctx.measureText(s).width <= max) return s;
  while (s.length > 1 && ctx.measureText(`${s}…`).width > max) s = s.slice(0, -1);
  return `${s}…`;
}

/** Nhãn kích thước nền xanh, chữ trắng. */
function tag(ctx: CanvasRenderingContext2D, s: string, x: number, y: number, vertical: boolean) {
  ctx.save();
  ctx.translate(x, y);
  if (vertical) ctx.rotate(-Math.PI / 2);
  ctx.font = `700 11px ${FONT}`;
  const w = ctx.measureText(s).width + 10, h = 17;
  ctx.fillStyle = C.primary;
  ctx.beginPath();
  ctx.roundRect(-w / 2, -h / 2, w, h, 6);
  ctx.fill();
  ctx.fillStyle = '#fff';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(s, 0, 1);
  ctx.restore();
}

/** Góc nhìn khung 3D: xoay quanh trục đứng (yaw), nghiêng xuống (pitch), phóng to (zoom). */
export interface ViewAngle { yaw: number; pitch: number; zoom: number }

/** Mặc định: nhìn chéo từ góc dưới phải, nghiêng 35,3° (đúng isometric). */
export const initialView: ViewAngle = { yaw: Math.PI / 4, pitch: 0.6155, zoom: 1 };

export const withView = (v: ViewAngle, c: Partial<ViewAngle>): ViewAngle => ({
  yaw: c.yaw ?? v.yaw,
  pitch: Math.min(Math.max(c.pitch ?? v.pitch, 0.2), 1.4),
  zoom: Math.min(Math.max(c.zoom ?? v.zoom, 0.5), 4),
});

/** Tường quay về phía người xem chỉ dựng tới độ cao này (m) để nhìn thấy trong phòng. */
const CUTAWAY = 0.9;

function mix(a: string, b: string, t: number) {
  const pa = [1, 3, 5].map((i) => parseInt(a.slice(i, i + 2), 16));
  const pb = [1, 3, 5].map((i) => parseInt(b.slice(i, i + 2), 16));
  return `rgb(${pa.map((v, i) => Math.round(v + (pb[i] - v) * t)).join(',')})`;
}

/** Khung 3D: sàn theo màu phòng, tường dựng theo cạnh đa giác, cửa khoét trên tường. */
export function drawFrame(
  ctx: CanvasRenderingContext2D, plan: Plan, width: number, height: number,
  selectedId?: string | null, view: ViewAngle = initialView,
) {
  if (!plan.rooms.length) return;
  const [minX, minY, maxX, maxY] = bounds(plan);
  const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  const cosY = Math.cos(view.yaw), sinY = Math.sin(view.yaw);
  const cosP = Math.cos(view.pitch), sinP = Math.sin(view.pitch);

  /** Xoay mặt bằng quanh tâm: X ngang màn hình, D độ sâu (lớn là gần người xem). */
  const rot = (x: number, y: number): [number, number] => {
    const dx = x - cx, dy = y - cy;
    return [dx * cosY - dy * sinY, dx * sinY + dy * cosY];
  };

  // Co theo đường tròn bao mặt bằng (không theo khung sau khi xoay), để xoay không làm hình phình ra co lại.
  const radius = Math.max(0.5, Math.hypot(maxX - minX, maxY - minY) / 2);
  const hMax = Math.max(...plan.rooms.map((r) => r.h));
  const pad = 16;
  const spanY = 2 * radius * sinP + hMax * cosP;
  const s = Math.min((width - 2 * pad) / (2 * radius), (height - 2 * pad) / spanY) * view.zoom;
  const p = (x: number, y: number, z: number): [number, number] => {
    const [X, D] = rot(x, y);
    return [width / 2 + X * s, height / 2 + (D * sinP - z * cosP + (hMax * cosP) / 2) * s];
  };

  // Mặt phẳng cần vẽ, sắp theo độ sâu: thuật toán hoạ sĩ.
  const faces: [number, () => void][] = [];

  for (const r of plan.rooms) {
    const selected = r.id === selectedId;
    const es = edges(r);
    faces.push([-1e9, () => {
      polygon(ctx, es.map((e) => p(e.x0, e.y0, 0)));
      ctx.fillStyle = roomColor(r.type);
      ctx.fill();
      ctx.strokeStyle = C.border;
      ctx.lineWidth = 1;
      ctx.stroke();
    }]);

    for (const e of es) {
      if (edgeLength(e) < 1e-6) continue;
      // Tường có pháp tuyến quay về phía người xem (sau khi xoay) cắt thấp để nhìn vào trong.
      const [nx, ny] = outward(e);
      const nX = nx * cosY - ny * sinY, nD = nx * sinY + ny * cosY;
      const front = nD > 0.01;
      const top = front ? Math.min(CUTAWAY, r.h) : r.h;
      const depth = rot((e.x0 + e.x1) / 2, (e.y0 + e.y1) / 2)[1] + (front ? 0.3 : 0);
      faces.push([depth, () => {
        // Ánh sáng từ bên trái màn hình: tường càng quay sang phải càng tối.
        polygon(ctx, [p(e.x0, e.y0, 0), p(e.x1, e.y1, 0), p(e.x1, e.y1, top), p(e.x0, e.y0, top)]);
        ctx.globalAlpha = e.side === 'cut' || !front ? 1 : 0.92;
        ctx.fillStyle = e.side === 'cut' ? '#E4E7EE' : mix('#FFFFFF', '#E3E7F0', (nX + 1) / 2);
        ctx.fill();
        ctx.globalAlpha = 1;
        // Cửa trên tường chính: khung chữ nhật tô màu, cắt theo chiều cao tường đang dựng.
        for (const o of r.openings.filter((o) => o.wall === e.side)) {
          const z0 = o.sill, z1 = Math.min(o.sill + o.height, top);
          if (z1 <= z0) continue;
          const [a, b]: [number, number][] =
            o.wall === 'n' ? [[r.x + o.offset, r.y], [r.x + o.offset + o.width, r.y]]
            : o.wall === 's' ? [[r.x + o.offset, r.y + r.l], [r.x + o.offset + o.width, r.y + r.l]]
            : o.wall === 'w' ? [[r.x, r.y + o.offset], [r.x, r.y + o.offset + o.width]]
            : [[r.x + r.w, r.y + o.offset], [r.x + r.w, r.y + o.offset + o.width]];
          polygon(ctx, [p(a[0], a[1], z0), p(b[0], b[1], z0), p(b[0], b[1], z1), p(a[0], a[1], z1)]);
          ctx.fillStyle = o.kind === 'door' ? '#B98A5E' : '#9FD3F2';
          ctx.fill();
          ctx.strokeStyle = 'rgba(27,29,40,.5)';
          ctx.lineWidth = 1;
          ctx.stroke();
        }
        polygon(ctx, [p(e.x0, e.y0, 0), p(e.x1, e.y1, 0), p(e.x1, e.y1, top), p(e.x0, e.y0, top)]);
        ctx.strokeStyle = selected ? C.primary : 'rgba(27,29,40,.75)';
        ctx.lineWidth = selected ? 2.2 : 1.4;
        ctx.stroke();
      }]);
    }
  }

  faces.sort((a, b) => a[0] - b[0]);
  for (const [, draw] of faces) draw();
}
