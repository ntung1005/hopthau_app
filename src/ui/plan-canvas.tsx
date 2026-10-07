'use client';

// Khung vẽ 2D / 3D dùng chung cho trình dựng, màn xem, danh sách và banner trang chủ.
// 2D: chạm để chọn phòng, kéo để xếp phòng (tự hít vào mép phòng bên cạnh).
// 3D: kéo ngang xoay, kéo dọc nghiêng, chụm 2 ngón / cuộn chuột phóng to, chạm đúp đặt lại, nút xoay 90°.

import { useEffect, useRef, useState } from 'react';
import { drawFrame, drawPlan, initialView, insideRoom, PlanTransform, withView, type ViewAngle } from '@/lib/draw';
import { m2, parseNum } from '@/lib/format';
import { itemCount, planFloorArea, planWallArea, type Plan, type Room } from '@/lib/measure';
import { Field, Icon, Segmented } from './kit';

/** Hít vào mép phòng khác trong 15 cm, còn lại làm tròn 5 cm. */
function snap(v: number, size: number, edges: number[]) {
  for (const e of edges) {
    if (Math.abs(v - e) < 0.15) return e;
    if (Math.abs(v + size - e) < 0.15) return e - size;
  }
  return Math.round(v * 20) / 20;
}

export function PlanCanvas({ plan, threeD, selectedId, onSelect, onChanged, height, interactive = true, className }: {
  plan: Plan;
  threeD: boolean;
  selectedId?: string | null;
  onSelect?: (id: string | null) => void;
  /** Có thì cho kéo phòng (chỉ ở 2D). */
  onChanged?: () => void;
  /** Không có thì giãn theo khung cha. */
  height?: number;
  interactive?: boolean;
  className?: string;
}) {
  const box = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const [size, setSize] = useState<[number, number]>([0, 0]);
  // Góc nhìn 3D giữ nguyên khi chuyển qua lại 2D / 3D.
  const [view, setView] = useState<ViewAngle>(initialView);
  const drag = useRef<{
    t?: PlanTransform; room?: Room; sx: number; sy: number; rx: number; ry: number; moved: boolean;
  } | null>(null);
  const pointers = useRef(new Map<number, [number, number]>());
  const pinch = useRef<{ d: number; zoom: number } | null>(null);
  const [, redraw] = useState(0);

  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setSize([e.contentRect.width, e.contentRect.height]));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // Bản đo được sửa trực tiếp, nên vẽ lại sau mỗi lần render.
  useEffect(() => {
    const c = canvas.current;
    const [w, h] = size;
    if (!c || !w || !h) return;
    const dpr = window.devicePixelRatio || 1;
    c.width = Math.round(w * dpr);
    c.height = Math.round(h * dpr);
    const ctx = c.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    if (threeD) drawFrame(ctx, plan, w, h, selectedId, view);
    else drawPlan(ctx, plan, w, h, selectedId, drag.current?.t);
  });

  const local = (e: React.PointerEvent): [number, number] => {
    const r = canvas.current!.getBoundingClientRect();
    return [e.clientX - r.left, e.clientY - r.top];
  };

  const hit = (t: PlanTransform, px: number, py: number) => {
    const [x, y] = t.toPlan(px, py);
    return [...plan.rooms].reverse().find((r) => insideRoom(r, x, y)) ?? null;
  };

  const down = (e: React.PointerEvent) => {
    if (!interactive) return;
    canvas.current!.setPointerCapture(e.pointerId);
    const [px, py] = local(e);
    pointers.current.set(e.pointerId, [px, py]);
    if (threeD) {
      if (pointers.current.size === 2) {
        const [a, b] = [...pointers.current.values()];
        pinch.current = { d: Math.hypot(a[0] - b[0], a[1] - b[1]), zoom: view.zoom };
      }
      return;
    }
    const t = new PlanTransform(plan, size[0], size[1]);
    const r = hit(t, px, py);
    drag.current = { sx: px, sy: py, rx: r?.x ?? 0, ry: r?.y ?? 0, moved: false, ...(onChanged && r ? { t, room: r } : {}) };
    if (onChanged && r) onSelect?.(r.id);
  };

  const move = (e: React.PointerEvent) => {
    const prev = pointers.current.get(e.pointerId);
    if (!prev) return;
    const [px, py] = local(e);
    pointers.current.set(e.pointerId, [px, py]);
    if (threeD) {
      if (pinch.current && pointers.current.size === 2) {
        const [a, b] = [...pointers.current.values()];
        const zoom = pinch.current.zoom * (Math.hypot(a[0] - b[0], a[1] - b[1]) / pinch.current.d);
        setView((v) => withView(v, { zoom }));
      } else if (pointers.current.size === 1) {
        const dx = px - prev[0], dy = py - prev[1];
        setView((v) => withView(v, { yaw: v.yaw - dx * 0.012, pitch: v.pitch + dy * 0.006 }));
      }
      return;
    }
    const d = drag.current;
    if (!d) return;
    if (Math.hypot(px - d.sx, py - d.sy) > 4) d.moved = true;
    const r = d.room, t = d.t;
    if (!r || !t || !d.moved) return;
    const others = plan.rooms.filter((o) => o !== r);
    r.x = snap(d.rx + (px - d.sx) / t.scale, r.w, others.flatMap((o) => [o.x, o.x + o.w]));
    r.y = snap(d.ry + (py - d.sy) / t.scale, r.l, others.flatMap((o) => [o.y, o.y + o.l]));
    redraw((n) => n + 1);
    onChanged?.();
  };

  const up = (e: React.PointerEvent) => {
    pointers.current.delete(e.pointerId);
    if (pointers.current.size < 2) pinch.current = null;
    const d = drag.current;
    if (!threeD && d && !d.moved) {
      const [px, py] = local(e);
      onSelect?.(hit(new PlanTransform(plan, size[0], size[1]), px, py)?.id ?? null);
    }
    drag.current = null;
    redraw((n) => n + 1);
  };

  // Cuộn chuột phóng to: cần listener không passive để chặn cuộn trang.
  useEffect(() => {
    const c = canvas.current;
    if (!c || !threeD || !interactive) return;
    const wheel = (e: WheelEvent) => {
      e.preventDefault();
      setView((v) => withView(v, { zoom: v.zoom * (e.deltaY > 0 ? 0.9 : 1.1) }));
    };
    c.addEventListener('wheel', wheel, { passive: false });
    return () => c.removeEventListener('wheel', wheel);
  }, [threeD, interactive]);

  const rotate = (by: number) => setView((v) => withView(v, { yaw: v.yaw + by }));

  return (
    <div ref={box} className={className ?? 'canvas-box'} style={height ? { height } : undefined}>
      <canvas
        ref={canvas}
        onPointerDown={down}
        onPointerMove={move}
        onPointerUp={up}
        onPointerCancel={up}
        onDoubleClick={() => threeD && setView(initialView)}
        role="img"
        aria-label={threeD ? 'Khung 3D của bản đo' : 'Mặt bằng 2D của bản đo'}
      />
      {threeD && interactive && (
        <>
          <span className="canvas-hint">Kéo để xoay · chụm hoặc cuộn để phóng to</span>
          <div className="canvas-tools">
            <button title="Xoay trái 90°" aria-label="Xoay trái 90°" onClick={() => rotate(Math.PI / 2)}><Icon name="rotate_left" size={20} /></button>
            <button title="Xoay phải 90°" aria-label="Xoay phải 90°" onClick={() => rotate(-Math.PI / 2)}><Icon name="rotate_right" size={20} /></button>
            <button title="Góc nhìn ban đầu" aria-label="Góc nhìn ban đầu" onClick={() => setView(initialView)}><Icon name="center_focus_strong" size={20} /></button>
          </div>
        </>
      )}
    </div>
  );
}

/** Số liệu tổng: số phòng, sàn, tường trừ cửa, số món đồ. */
export function PlanSummary({ plan }: { plan: Plan }) {
  return (
    <div className="card stats">
      <div><b>{plan.rooms.length}</b><span className="muted xs">phòng</span></div>
      <div><b>{m2(planFloorArea(plan))} m²</b><span className="muted xs">sàn</span></div>
      <div><b>{m2(planWallArea(plan))} m²</b><span className="muted xs">tường (trừ cửa)</span></div>
      <div><b>{itemCount(plan)}</b><span className="muted xs">món đồ</span></div>
    </div>
  );
}

export function ViewToggle({ threeD, onChange }: { threeD: boolean; onChange: (v: boolean) => void }) {
  return <Segmented value={threeD} onChange={onChange} options={[[false, 'Mặt bằng 2D', 'grid_on'], [true, 'Khung 3D', 'view_in_ar']]} />;
}

/** Ô nhập số mét ("3,45"); chỉ báo [onChange] khi số hợp lệ trong [min, max]. */
export function MeterField({ label, value, min, max, onChange }: {
  label: string; value: number; min: number; max: number; onChange: (v: number) => void;
}) {
  const [text, setText] = useState(m2(value));
  const [error, setError] = useState<string | null>(null);
  return (
    <Field label={label} suffix="m" error={error}>
      <input
        inputMode="decimal"
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          const v = parseNum(e.target.value);
          const ok = v != null && v >= min && v <= max;
          setError(ok ? null : `${m2(min)} - ${m2(max)} m`);
          if (ok) onChange(v);
        }}
      />
    </Field>
  );
}
