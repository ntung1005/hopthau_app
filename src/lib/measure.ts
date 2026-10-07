// Bản đo nhà: phòng hình chữ nhật trên mặt bằng (mét), cửa đi / cửa sổ trên tường, góc cắt, đồ cần làm.
// Cùng định dạng và công thức với BE (hopthau_be/src/measurement.ts):
// x sang phải, y xuống dưới, phòng đặt ở góc trên trái; tường n / s dài w, tường e / w dài l.
// Đối tượng là JSON thuần, sửa trực tiếp (như app Flutter) rồi vẽ lại.

export const roomTypes: Record<string, string> = {
  living: 'Phòng khách',
  bedroom: 'Phòng ngủ',
  kitchen: 'Bếp',
  bathroom: 'WC',
  balcony: 'Ban công',
  other: 'Khác',
};

/** Gợi ý đồ cần làm theo loại phòng; chủ nhà vẫn thêm được món khác. */
export const furnitureSuggestions: Record<string, string[]> = {
  living: ['Kệ tivi', 'Sofa', 'Bàn trà', 'Tủ giày', 'Tủ trang trí', 'Bàn ăn + ghế'],
  bedroom: ['Giường', 'Tủ quần áo', 'Bàn làm việc', 'Bàn trang điểm', 'Kệ sách', 'Tab đầu giường'],
  kitchen: ['Tủ bếp trên + dưới', 'Bàn ăn + ghế', 'Kệ gia vị', 'Tủ lạnh âm tủ'],
  bathroom: ['Tủ lavabo', 'Gương', 'Kệ để đồ', 'Vách kính tắm'],
  balcony: ['Tủ / kệ để đồ', 'Giàn phơi', 'Chậu rửa'],
  other: ['Tủ', 'Kệ', 'Bàn làm việc', 'Giường gấp'],
};

export const wallNames: Record<string, string> = { n: 'Tường trên', e: 'Tường phải', s: 'Tường dưới', w: 'Tường trái' };
export const cornerNames: Record<string, string> = {
  nw: 'Góc trên trái', ne: 'Góc trên phải', se: 'Góc dưới phải', sw: 'Góc dưới trái',
};
export const cutKinds: Record<string, string> = {
  notch: 'Cắt vuông (cột, hộp kỹ thuật)',
  chamfer: 'Cắt chéo (góc vát)',
};

export interface Item { name: string; qty: number; note?: string | null }
/** Góc phòng bị cắt: khoét dx × dy (notch) hoặc vát chéo (chamfer). dx theo chiều rộng, dy theo chiều dài. */
export interface CornerCut { corner: string; kind: string; dx: number; dy: number }
export interface Opening { wall: string; kind: string; offset: number; width: number; height: number; sill: number }
export interface Room {
  id: string; name: string; type: string;
  x: number; y: number; w: number; l: number; h: number;
  openings: Opening[]; cuts: CornerCut[]; items: Item[];
}
export interface Plan { rooms: Room[]; drawing_url?: string | null }

/** Một cạnh đa giác phòng. side: n / e / s / w là tường chính (có thể có cửa), cut là cạnh do cắt góc. */
export interface Edge { x0: number; y0: number; x1: number; y1: number; side: string }

const r2 = (v: number) => Math.round(v * 100) / 100;
const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

/** Cửa đi mặc định 0,9 × 2,1 m; cửa sổ 1,2 × 1,4 m cách sàn 0,9 m. */
export const door = (wall: string, offset: number): Opening => ({ wall, kind: 'door', offset, width: 0.9, height: 2.1, sill: 0 });
export const windowOf = (wall: string, offset: number): Opening =>
  ({ wall, kind: 'window', offset, width: 1.2, height: 1.4, sill: 0.9 });

export function room(r: Partial<Room> & Pick<Room, 'id' | 'name' | 'type' | 'x' | 'y' | 'w' | 'l'>): Room {
  return { h: 2.8, openings: [], cuts: [], items: [], ...r };
}

/** Đọc JSON từ BE, điền giá trị mặc định như Room.fromJson. */
export function planFromJson(j: { rooms?: Partial<Room>[]; drawing_url?: string | null } | null | undefined): Plan {
  return {
    rooms: (j?.rooms ?? []).map((r) => ({
      id: String(r.id), name: String(r.name), type: r.type ?? 'other',
      x: Number(r.x), y: Number(r.y), w: Number(r.w), l: Number(r.l), h: Number(r.h ?? 2.8),
      openings: (r.openings ?? []).map((o) => ({ ...o, sill: o.sill ?? 0 })),
      cuts: (r.cuts ?? []).map((c) => ({ ...c })),
      items: (r.items ?? []).map((i) => ({ name: i.name, qty: i.qty ?? 1, note: i.note ?? null })),
    })),
    drawing_url: j?.drawing_url ?? null,
  };
}

export function planToJson(p: Plan) {
  return {
    rooms: p.rooms.map((r) => ({
      id: r.id, name: r.name, type: r.type,
      x: r2(r.x), y: r2(r.y), w: r2(r.w), l: r2(r.l), h: r2(r.h),
      openings: r.openings.map((o) => ({
        wall: o.wall, kind: o.kind, offset: r2(o.offset), width: r2(o.width), height: r2(o.height), sill: r2(o.sill),
      })),
      cuts: r.cuts.map((c) => ({ corner: c.corner, kind: c.kind, dx: r2(c.dx), dy: r2(c.dy) })),
      items: r.items.map((i) => ({ name: i.name, qty: i.qty, ...(i.note?.trim() ? { note: i.note.trim() } : {}) })),
    })),
    ...(p.drawing_url ? { drawing_url: p.drawing_url } : {}),
  };
}

export const copyRoom = (r: Room): Room => planFromJson(planToJson({ rooms: [r] })).rooms[0];

export const wallLength = (r: Room, wall: string) => (wall === 'n' || wall === 's' ? r.w : r.l);

export const cutOf = (r: Room, corner: string) => r.cuts.find((c) => c.corner === corner);

function cutSize(r: Room, corner: string): [number, number] {
  const c = cutOf(r, corner);
  return c ? [c.dx, c.dy] : [0, 0];
}

/** Đoạn tường còn lại (theo offset của cửa) sau khi cắt hai góc ở hai đầu tường. Cùng công thức với BE (wallSpan). */
export function wallSpan(r: Room, wall: string): [number, number] {
  switch (wall) {
    case 'n': return [cutSize(r, 'nw')[0], r.w - cutSize(r, 'ne')[0]];
    case 's': return [cutSize(r, 'sw')[0], r.w - cutSize(r, 'se')[0]];
    case 'w': return [cutSize(r, 'nw')[1], r.l - cutSize(r, 'sw')[1]];
    default: return [cutSize(r, 'ne')[1], r.l - cutSize(r, 'se')[1]];
  }
}

/** Các cạnh đa giác phòng (m), chiều kim đồng hồ từ góc trên trái. Cùng thuật toán với BE (outline). */
export function edges(r: Room): Edge[] {
  const { x, y, w, l } = r;
  const pts: [number, number, string][] = []; // điểm và nhãn cạnh đi ra từ điểm đó
  type P = [number, number];
  const corner = (k: string, at: P, pin: P, mid: P, pout: P, next: string) => {
    const c = cutOf(r, k);
    if (!c) return void pts.push([at[0], at[1], next]);
    pts.push([pin[0], pin[1], 'cut']);
    if (c.kind === 'notch') pts.push([mid[0], mid[1], 'cut']);
    pts.push([pout[0], pout[1], next]);
  };
  const [nw, ne, se, sw] = ['nw', 'ne', 'se', 'sw'].map((k) => cutSize(r, k));
  corner('nw', [x, y], [x, y + nw[1]], [x + nw[0], y + nw[1]], [x + nw[0], y], 'n');
  corner('ne', [x + w, y], [x + w - ne[0], y], [x + w - ne[0], y + ne[1]], [x + w, y + ne[1]], 'e');
  corner('se', [x + w, y + l], [x + w, y + l - se[1]], [x + w - se[0], y + l - se[1]], [x + w - se[0], y + l], 's');
  corner('sw', [x, y + l], [x + sw[0], y + l], [x + sw[0], y + l - sw[1]], [x, y + l - sw[1]], 'w');
  return pts.map((p, i) => {
    const q = pts[(i + 1) % pts.length];
    return { x0: p[0], y0: p[1], x1: q[0], y1: q[1], side: p[2] };
  });
}

export const edgeLength = (e: Edge) => Math.hypot(e.x1 - e.x0, e.y1 - e.y0);

/** Pháp tuyến hướng ra ngoài phòng (đa giác theo chiều kim đồng hồ, trục y hướng xuống). */
export function outward(e: Edge): [number, number] {
  const len = edgeLength(e);
  return len === 0 ? [0, 0] : [(e.y1 - e.y0) / len, -(e.x1 - e.x0) / len];
}

/** Diện tích sàn theo đa giác (công thức shoelace). */
export function floorArea(r: Room): number {
  let a = 0;
  for (const e of edges(r)) a += e.x0 * e.y1 - e.x1 * e.y0;
  return Math.abs(a) / 2;
}

export const perimeter = (r: Room) => edges(r).reduce((s, e) => s + edgeLength(e), 0);

/** Diện tích tường đã trừ cửa: để bóc khối lượng sơn, ốp. */
export const wallArea = (r: Room) => perimeter(r) * r.h - r.openings.reduce((s, o) => s + o.width * o.height, 0);

/** Góc cắt và cửa nằm gọn trong phòng, không cao hơn trần. Gọi sau khi đổi kích thước phòng hoặc góc cắt. */
export function clampOpenings(r: Room) {
  // Như BE: hai góc cùng một cạnh chừa ít nhất 10 cm tường.
  const alongX: Record<string, string> = { nw: 'ne', ne: 'nw', sw: 'se', se: 'sw' };
  const alongY: Record<string, string> = { nw: 'sw', sw: 'nw', ne: 'se', se: 'ne' };
  for (const c of r.cuts) {
    c.dx = clamp(c.dx, 0.05, Math.max(0.05, r.w - 0.1 - cutSize(r, alongX[c.corner])[0]));
    c.dy = clamp(c.dy, 0.05, Math.max(0.05, r.l - 0.1 - cutSize(r, alongY[c.corner])[1]));
  }
  for (const o of r.openings) {
    const [from, to] = wallSpan(r, o.wall);
    o.width = clamp(o.width, 0.2, Math.max(0.2, to - from));
    o.offset = clamp(o.offset, from, Math.max(from, to - o.width));
    o.height = clamp(o.height, 0.2, r.h);
    o.sill = clamp(o.sill, 0, Math.max(0, r.h - o.height));
  }
}

export const planFloorArea = (p: Plan) => r2(p.rooms.reduce((s, r) => s + floorArea(r), 0));
export const planWallArea = (p: Plan) => r2(p.rooms.reduce((s, r) => s + wallArea(r), 0));

/** Khung bao (mét) của mọi phòng: [minX, minY, maxX, maxY]. */
export function bounds(p: Plan): [number, number, number, number] {
  if (!p.rooms.length) return [0, 0, 1, 1];
  return [
    Math.min(...p.rooms.map((r) => r.x)),
    Math.min(...p.rooms.map((r) => r.y)),
    Math.max(...p.rooms.map((r) => r.x + r.w)),
    Math.max(...p.rooms.map((r) => r.y + r.l)),
  ];
}

export interface AskedItem { room: string; name: string; qty: number; note?: string | null; unit_price?: number | null }

/** Đồ chủ nhà chọn, dạng món báo giá (phòng, tên, số lượng, ghi chú) để nhà thầu điền đơn giá. */
export const askedItems = (p: Plan): AskedItem[] =>
  p.rooms.flatMap((r) => r.items.map((i) => ({ room: r.name, name: i.name, qty: i.qty, note: i.note ?? null })));

/** Tổng số món đồ chủ nhà chọn làm, ở mọi phòng. */
export const itemCount = (p: Plan) => p.rooms.reduce((s, r) => s + r.items.reduce((t, i) => t + i.qty, 0), 0);

export function newRoomId(p: Plan): string {
  let i = p.rooms.length + 1;
  while (p.rooms.some((r) => r.id === `r${i}`)) i++;
  return `r${i}`;
}

/** Mẫu để bắt đầu: kích thước điển hình của căn NOXH, người dùng sửa theo số đo thật. */
export const planTemplates: Record<string, () => Plan> = {
  'Căn 2 phòng ngủ (~56 m²)': () => ({
    rooms: [
      room({ id: 'r1', name: 'Phòng khách + bếp', type: 'living', x: 0, y: 0, w: 4.0, l: 6.0, openings: [door('s', 0.4), windowOf('w', 1.5)] }),
      room({ id: 'r2', name: 'Phòng ngủ 1', type: 'bedroom', x: 4.0, y: 0, w: 3.2, l: 3.4, openings: [door('w', 2.3), windowOf('n', 1.0)] }),
      room({ id: 'r3', name: 'Phòng ngủ 2', type: 'bedroom', x: 4.0, y: 3.4, w: 3.2, l: 2.9, openings: [door('w', 0.2), windowOf('e', 0.9)] }),
      room({ id: 'r4', name: 'WC', type: 'bathroom', x: 4.0, y: 6.3, w: 1.8, l: 2.0, h: 2.6, openings: [door('n', 0.4)] }),
      room({ id: 'r5', name: 'Ban công', type: 'balcony', x: 0, y: 6.0, w: 4.0, l: 1.3, openings: [door('n', 0.4)] }),
    ],
  }),
  'Căn 1 phòng ngủ (~42 m²)': () => ({
    rooms: [
      room({ id: 'r1', name: 'Phòng khách + bếp', type: 'living', x: 0, y: 0, w: 4.2, l: 5.0, openings: [door('s', 0.5), windowOf('w', 1.8)] }),
      room({ id: 'r2', name: 'Phòng ngủ', type: 'bedroom', x: 4.2, y: 0, w: 3.2, l: 3.6, openings: [door('w', 2.5), windowOf('e', 1.2)] }),
      room({ id: 'r3', name: 'WC', type: 'bathroom', x: 4.2, y: 3.6, w: 1.8, l: 2.2, h: 2.6, openings: [door('w', 0.6)] }),
      room({ id: 'r4', name: 'Ban công', type: 'balcony', x: 0, y: 5.0, w: 4.2, l: 1.2, openings: [door('n', 0.5)] }),
    ],
  }),
  'Một phòng (đo lẻ từng phòng)': () => ({
    rooms: [
      room({ id: 'r1', name: 'Phòng ngủ', type: 'bedroom', x: 0, y: 0, w: 3.5, l: 4.0, openings: [door('s', 0.3), windowOf('n', 1.1)] }),
    ],
  }),
};

/** Một dòng khi so báo giá theo món với đồ chủ nhà chọn. tag: 'added' nhà thầu thêm, 'changed' đổi số lượng
 * (chủ nhà chọn askedQty), 'removed' nhà thầu bỏ (không có đơn giá), null giữ nguyên. */
export interface QuoteLine {
  room: string; name: string; qty: number; unitPrice: number | null; note: string | null;
  tag: 'added' | 'changed' | 'removed' | null; askedQty: number | null;
}

/** So khớp theo (phòng, tên món). Món bị bỏ xếp cuối. */
export function quoteDiff(asked: AskedItem[], quoted: AskedItem[]): QuoteLine[] {
  const key = (m: AskedItem) => `${m.room}|${m.name}`;
  const askedBy = new Map(asked.map((a) => [key(a), a]));
  const quotedKeys = new Set(quoted.map(key));
  return [
    ...quoted.map((q): QuoteLine => {
      const a = askedBy.get(key(q));
      return {
        room: q.room, name: q.name, qty: q.qty, unitPrice: q.unit_price ?? null, note: q.note ?? null,
        tag: !a ? 'added' : a.qty !== q.qty ? 'changed' : null,
        askedQty: a?.qty ?? null,
      };
    }),
    ...asked.filter((a) => !quotedKeys.has(key(a))).map((a): QuoteLine => ({
      room: a.room, name: a.name, qty: a.qty, unitPrice: null, note: a.note ?? null, tag: 'removed', askedQty: a.qty,
    })),
  ];
}

/** Giá gói = tổng hạng mục bắt buộc + hạng mục tuỳ chọn đang chọn. Cùng công thức với BE (src/pricing.ts). */
export function packageTotal(items: Record<string, unknown>[], chosen: Set<string>) {
  return items
    .filter((i) => i.is_optional !== true || chosen.has(String(i.id)))
    .reduce((s, i) => s + Math.round(Number(i.qty) * Number(i.unit_price)), 0);
}
