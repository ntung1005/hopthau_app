'use client';
// Bản đo là đối tượng sửa trực tiếp rồi vẽ lại (như app Flutter); dự án không bật React Compiler.
/* eslint-disable react-hooks/immutability */

// Dựng / sửa bản đo: mặt bằng 2D (kéo xếp phòng) hoặc khung 3D, số đo từng phòng, đồ cần làm, góc cắt, cửa.
// Màn rộng: bản vẽ trái, thông số phải. Màn hẹp: bản vẽ trên, bảng thông số dưới (thu gọn được).
// /do-nha/moi mở bản nháp từ danh sách (mẫu / bản vẽ), chưa lưu.

import { useParams, useRouter } from 'next/navigation';
import { useEffect, useReducer, useRef, useState } from 'react';
import { api, type Json } from '@/lib/api';
import { m2 } from '@/lib/format';
import {
  clampOpenings, copyRoom, cornerNames, cutKinds, cutOf, door, floorArea, furnitureSuggestions, itemCount, newRoomId, perimeter,
  planFromJson, planToJson, room as makeRoom, roomTypes, wallArea, wallLength, wallNames, wallSpan, windowOf,
  type CornerCut, type Item, type Opening, type Plan, type Room,
} from '@/lib/measure';
import { roomColor } from '@/lib/draw';
import { useApp, useAuthLoad } from '@/ui/app';
import { Field, Icon, Loaded, PhotoViewer, Segmented, Sheet, TopBar } from '@/ui/kit';
import { MeasureGuide } from '@/ui/shared';
import { MeterField, PlanCanvas, PlanSummary, ViewToggle } from '@/ui/plan-canvas';
import { clearDraft, takeDraft } from '../draft';

export default function MeasurementEditorPage() {
  const { id } = useParams<{ id: string }>();
  const state = useAuthLoad<{ saved: Json | null; plan: Plan; name: string }>(async () => {
    if (id === 'moi') return { saved: null, ...takeDraft() };
    const m = await api.getAuth(`/measurements/${id}`);
    return { saved: m, plan: planFromJson(m.data), name: m.name };
  }, [id]);
  return <Loaded state={state}>{(d) => <Editor {...d} />}</Loaded>;
}

type Dialog =
  | { kind: 'cut'; room: Room; existing: CornerCut | null }
  | { kind: 'opening'; room: Room; existing: Opening | null }
  | { kind: 'item'; room: Room; existing: Item | null };

function Editor({ saved: initialSaved, plan, name: initialName }: { saved: Json | null; plan: Plan; name: string }) {
  const router = useRouter();
  const { toast, showError } = useApp();
  const [saved, setSaved] = useState(initialSaved);
  const [name, setName] = useState(initialName);
  const [selected, setSelected] = useState<string | null>(plan.rooms[0]?.id ?? null);
  const [threeD, setThreeD] = useState(false);
  const [dirty, setDirty] = useState(initialSaved == null);
  const [busy, setBusy] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [dialog, setDialog] = useState<Dialog | null>(null);
  const [guide, setGuide] = useState(false);
  const [drawingShown, setDrawingShown] = useState(false);
  // Bản đo được sửa trực tiếp; tăng số để vẽ lại.
  const [, bump] = useReducer((n: number) => n + 1, 0);
  const dirtyRef = useRef(dirty);
  useEffect(() => {
    dirtyRef.current = dirty;
  });

  const changed = () => {
    setDirty(true);
    bump();
  };

  // Rời trang khi chưa lưu: trình duyệt hỏi lại.
  useEffect(() => {
    const warn = (e: BeforeUnloadEvent) => {
      if (dirtyRef.current) e.preventDefault();
    };
    addEventListener('beforeunload', warn);
    return () => removeEventListener('beforeunload', warn);
  }, []);

  const room = plan.rooms.find((r) => r.id === selected) ?? null;

  const save = async (): Promise<Json | null> => {
    setBusy(true);
    try {
      const body = { name, data: planToJson(plan), unit_type_id: saved?.unit_type_id ?? null };
      const res: Json = saved ? await api.putAuth(`/measurements/${saved.id}`, body) : await api.postAuth('/measurements', body);
      if (!saved) {
        clearDraft();
        // Đổi URL sang bản đo đã lưu mà không tải lại trang.
        history.replaceState(null, '', `/do-nha/${res.id}`);
      }
      setSaved(res);
      setDirty(false);
      toast('Đã lưu bản đo');
      return res;
    } catch (e) {
      showError(e);
      return null;
    } finally {
      setBusy(false);
    }
  };

  const send = async () => {
    // Nhà thầu báo giá theo món, nên phải biết chủ nhà muốn làm những gì.
    if (itemCount(plan) === 0) {
      alert('Chọn đồ cần làm trước\n\nỞ mỗi phòng, chọn các món muốn đóng / lắp (giường, tủ, kệ, bàn làm việc...) để nhà thầu báo giá sát hơn.');
      setCollapsed(false);
      return;
    }
    const m = dirty || !saved ? await save() : saved;
    if (m) router.push(`/yeu-cau/moi?measurement=${m.id}`);
  };

  const back = () => {
    if (dirty && !confirm('Chưa lưu thay đổi. Thoát mà không lưu?')) return;
    dirtyRef.current = false;
    router.push('/do-nha');
  };

  const rename = () => {
    const v = prompt('Tên bản đo', name)?.trim();
    if (v) {
      setName(v);
      setDirty(true);
    }
  };

  const remove = async () => {
    if (!saved || !confirm('Xoá bản đo?')) return;
    try {
      await api.deleteAuth(`/measurements/${saved.id}`);
      dirtyRef.current = false;
      router.push('/do-nha');
    } catch (e) {
      showError(e);
    }
  };

  const addRoom = () => {
    const maxX = plan.rooms.length ? Math.max(...plan.rooms.map((r) => r.x + r.w)) : 0;
    const r = makeRoom({ id: newRoomId(plan), name: 'Phòng mới', type: 'other', x: maxX, y: 0, w: 3, l: 3, openings: [door('w', 1)] });
    plan.rooms.push(r);
    setSelected(r.id);
    changed();
  };

  const select = (id: string | null) => {
    if (id) setSelected(id);
    // Chạm vào phòng khi bảng đang thu gọn: mở lên để sửa ngay.
    if (id) setCollapsed(false);
  };

  return (
    <>
      <TopBar
        onBack={back}
        title={<button onClick={rename} title="Đổi tên" style={{ fontWeight: 600 }}>{name}</button>}
        actions={
          <>
            {plan.drawing_url && (
              <button className="icon-btn" title="Bản vẽ gốc" aria-label="Bản vẽ gốc" onClick={() => setDrawingShown(true)}><Icon name="image" /></button>
            )}
            <button className="icon-btn" title="Cách đo" aria-label="Cách đo" onClick={() => setGuide(true)}><Icon name="help" /></button>
            {saved && <button className="icon-btn" title="Xoá bản đo" aria-label="Xoá bản đo" onClick={remove}><Icon name="delete" /></button>}
          </>
        }
      />
      <div className="editor" style={{ maxWidth: 1400, margin: '0 auto' }}>
        <div className="editor-draw">
          <ViewToggle threeD={threeD} onChange={setThreeD} />
          <PlanCanvas plan={plan} threeD={threeD} selectedId={selected} onSelect={select} onChanged={changed} />
          <p className="muted xs">{threeD ? 'Tường phía trước cắt thấp để nhìn vào trong; kéo để xoay.' : 'Chạm để chọn phòng, kéo để xếp phòng.'}</p>
        </div>
        <aside className={`editor-panel${collapsed ? ' collapsed' : ''}`}>
          <button className="editor-toggle-btn" aria-label={collapsed ? 'Mở rộng thông số' : 'Thu gọn thông số'} onClick={() => setCollapsed(!collapsed)}>
            <span className="editor-toggle" />
          </button>
          <div className="chips scroll">
            {plan.rooms.map((r) => (
              <button key={r.id} className={`chip${r.id === selected ? ' on' : ''}`} onClick={() => select(r.id)}>
                <span className="swatch" style={{ background: roomColor(r.type) }} />
                {r.name}
              </button>
            ))}
            <button className="chip" onClick={addRoom}><Icon name="add" size={18} /> Thêm phòng</button>
          </div>
          <div className="gap-t8"><PlanSummary plan={plan} /></div>
          {room && (
            <RoomPanel
              key={room.id}
              room={room}
              onChanged={changed}
              open={(d) => setDialog(d)}
              onDelete={plan.rooms.length <= 1 ? undefined : () => {
                plan.rooms.splice(plan.rooms.indexOf(room), 1);
                setSelected(plan.rooms[0].id);
                changed();
              }}
            />
          )}
        </aside>
      </div>
      <div className="bottom-bar">
        <div className="bottom-bar-inner" style={{ flexDirection: 'row', maxWidth: 1400, borderRadius: 0 }}>
          <button className="btn outline" style={{ flex: 1 }} disabled={busy || (!dirty && !!saved)} onClick={save}>
            {dirty || !saved ? 'Lưu' : 'Đã lưu'}
          </button>
          <button className="btn" style={{ flex: 2 }} disabled={busy} onClick={send}>
            <Icon name="send" /> Gửi nhà thầu báo giá
          </button>
        </div>
      </div>

      <Sheet open={!!dialog} onClose={() => setDialog(null)}>
        {dialog?.kind === 'cut' && (
          <CornerForm
            room={dialog.room}
            initial={dialog.existing}
            onDone={(corner, cut) => {
              const r = dialog.room;
              r.cuts = r.cuts.filter((c) => c.corner !== corner && c !== dialog.existing);
              if (cut) r.cuts.push(cut);
              clampOpenings(r);
              setDialog(null);
              changed();
            }}
          />
        )}
        {dialog?.kind === 'opening' && (
          <OpeningForm
            room={dialog.room}
            initial={dialog.existing}
            onDone={(o) => {
              const r = dialog.room;
              if (!o) r.openings = r.openings.filter((x) => x !== dialog.existing);
              else if (!dialog.existing) r.openings.push(o);
              else r.openings[r.openings.indexOf(dialog.existing)] = o;
              clampOpenings(r);
              setDialog(null);
              changed();
            }}
          />
        )}
        {dialog?.kind === 'item' && (
          <ItemForm
            initial={dialog.existing}
            onDone={(n, note) => {
              if (dialog.existing) Object.assign(dialog.existing, { name: n, note });
              else dialog.room.items.push({ name: n, qty: 1, note });
              setDialog(null);
              changed();
            }}
          />
        )}
      </Sheet>
      <MeasureGuide open={guide} onClose={() => setGuide(false)} />
      <PhotoViewer url={drawingShown ? plan.drawing_url ?? null : null} onClose={() => setDrawingShown(false)} />
    </>
  );
}

function RoomPanel({ room: r, onChanged, open, onDelete }: {
  room: Room; onChanged: () => void; open: (d: Dialog) => void; onDelete?: () => void;
}) {
  const size = (k: 'w' | 'l' | 'h') => (v: number) => {
    r[k] = v;
    clampOpenings(r);
    onChanged();
  };
  const suggestions = furnitureSuggestions[r.type] ?? furnitureSuggestions.other;
  return (
    <div className="card pad stack-12" style={{ marginTop: 12 }}>
      <div className="form-row">
        <Field label="Tên phòng">
          <input
            defaultValue={r.name}
            onChange={(e) => {
              r.name = e.target.value.trim() || 'Phòng';
              onChanged();
            }}
          />
        </Field>
        <Field label="Loại">
          <select value={r.type} onChange={(e) => { r.type = e.target.value; onChanged(); }}>
            {Object.entries(roomTypes).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </Field>
      </div>
      <div className="form-row">
        <MeterField label="Rộng (ngang)" value={r.w} min={0.3} max={30} onChange={size('w')} />
        <MeterField label="Dài (dọc)" value={r.l} min={0.3} max={30} onChange={size('l')} />
        <MeterField label="Cao trần" value={r.h} min={1.8} max={6} onChange={size('h')} />
      </div>
      <p className="muted small">Sàn {m2(floorArea(r))} m² · chu vi {m2(perimeter(r))} m · tường {m2(wallArea(r))} m²</p>

      <hr className="divider" style={{ margin: '4px 0' }} />
      <div>
        <h3 className="t-strong">Đồ cần làm ({r.items.length})</h3>
        <p className="muted xs">Chọn món muốn đóng / lắp để nhà thầu báo giá theo từng món. Chạm vào món để ghi kích thước, vật liệu.</p>
      </div>
      <div className="chips">
        {suggestions.map((n) => {
          const on = r.items.some((i) => i.name === n);
          return (
            <button
              key={n}
              className={`chip${on ? ' on' : ''}`}
              aria-pressed={on}
              onClick={() => {
                if (on) r.items = r.items.filter((i) => i.name !== n);
                else r.items.push({ name: n, qty: 1, note: null });
                onChanged();
              }}
            >
              {on && <Icon name="check" size={16} />}
              {n}
            </button>
          );
        })}
        {r.items.length < 30 && (
          <button className="chip" onClick={() => open({ kind: 'item', room: r, existing: null })}><Icon name="add" size={18} /> Món khác</button>
        )}
      </div>
      {r.items.map((i, idx) => (
        <div key={`${i.name}-${idx}`} className="row" style={{ gap: 4 }}>
          <button className="list-line grow" onClick={() => open({ kind: 'item', room: r, existing: i })}>
            <Icon name="chair" />
            <span className="grow">
              <span style={{ display: 'block' }}>{i.name}</span>
              <span className={`small${i.note ? '' : ' muted'}`}>{i.note ?? 'Thêm kích thước, vật liệu...'}</span>
            </span>
          </button>
          <span className="qty">
            <button
              className="icon-btn sm"
              title={i.qty > 1 ? 'Bớt' : 'Bỏ món'}
              onClick={() => {
                if (i.qty > 1) i.qty--;
                else r.items.splice(idx, 1);
                onChanged();
              }}
            >
              <Icon name={i.qty > 1 ? 'remove_circle' : 'delete'} size={22} />
            </button>
            <b>{i.qty}</b>
            <button className="icon-btn sm" title="Thêm" disabled={i.qty >= 20} onClick={() => { i.qty++; onChanged(); }}>
              <Icon name="add_circle" size={22} />
            </button>
          </span>
        </div>
      ))}

      <hr className="divider" style={{ margin: '4px 0' }} />
      <div>
        <h3 className="t-strong">Góc phòng</h3>
        <p className="muted xs">Góc có cột, hộp kỹ thuật hoặc bị vát thì cắt bớt để diện tích đúng thực tế.</p>
      </div>
      {r.cuts.map((c) => (
        <button key={c.corner} className="list-line" onClick={() => open({ kind: 'cut', room: r, existing: c })}>
          <Icon name={c.kind === 'notch' ? 'crop_square' : 'change_history'} />
          <span className="grow">
            <span style={{ display: 'block' }}>{cornerNames[c.corner]} · {c.kind === 'notch' ? 'cắt vuông' : 'cắt chéo'}</span>
            <span className="muted small">{m2(c.dx)} m theo chiều rộng × {m2(c.dy)} m theo chiều dài</span>
          </span>
          <Icon name="edit" size={18} />
        </button>
      ))}
      {r.cuts.length < 4 && (
        <button className="btn text" style={{ alignSelf: 'flex-start' }} onClick={() => open({ kind: 'cut', room: r, existing: null })}>
          <Icon name="content_cut" /> Cắt góc
        </button>
      )}

      <hr className="divider" style={{ margin: '4px 0' }} />
      <h3 className="t-strong">Cửa ({r.openings.length})</h3>
      {r.openings.map((o, idx) => (
        <button key={idx} className="list-line" onClick={() => open({ kind: 'opening', room: r, existing: o })}>
          <Icon name={o.kind === 'door' ? 'door_front' : 'window'} />
          <span className="grow">
            <span style={{ display: 'block' }}>{o.kind === 'door' ? 'Cửa đi' : 'Cửa sổ'} · {wallNames[o.wall]}</span>
            <span className="muted small">
              cách góc {m2(o.offset)} m · rộng {m2(o.width)} × cao {m2(o.height)} m{o.kind === 'door' ? '' : ` · bậu ${m2(o.sill)} m`}
            </span>
          </span>
          <Icon name="edit" size={18} />
        </button>
      ))}
      <div className="row">
        <button className="btn text grow" style={{ justifyContent: 'flex-start' }} onClick={() => open({ kind: 'opening', room: r, existing: null })}>
          <Icon name="add" /> Thêm cửa
        </button>
        {onDelete && <button className="btn text danger" onClick={onDelete}><Icon name="delete" /> Xoá phòng</button>}
      </div>
    </div>
  );
}

/** Thêm món khác hoặc sửa tên, ghi chú của một món. */
function ItemForm({ initial, onDone }: { initial: Item | null; onDone: (name: string, note: string | null) => void }) {
  const [name, setName] = useState(initial?.name ?? '');
  const [note, setNote] = useState(initial?.note ?? '');
  return (
    <form
      className="form"
      onSubmit={(e) => {
        e.preventDefault();
        if (name.trim()) onDone(name.trim(), note.trim() || null);
      }}
    >
      <h2 className="sheet-title">{initial ? 'Sửa món' : 'Thêm món'}</h2>
      <Field label="Tên món"><input autoFocus={!initial} maxLength={50} placeholder="Ví dụ: Tủ âm tường" value={name} onChange={(e) => setName(e.target.value)} /></Field>
      <Field label="Ghi chú">
        <input autoFocus={!!initial} maxLength={100} placeholder="Kích thước, vật liệu, màu..." value={note} onChange={(e) => setNote(e.target.value)} />
      </Field>
      <button className="btn">Lưu</button>
    </form>
  );
}

/** Cắt một góc phòng: chọn góc, kiểu cắt, kích thước; xem trước hình phòng. onDone(góc, null) là bỏ cắt góc đó. */
function CornerForm({ room, initial, onDone }: {
  room: Room; initial: CornerCut | null; onDone: (corner: string, cut: CornerCut | null) => void;
}) {
  const free = Object.keys(cornerNames).filter((k) => !cutOf(room, k) || cutOf(room, k) === initial);
  const [corner, setCorner] = useState(initial?.corner ?? free[0]);
  const [kind, setKind] = useState(initial?.kind ?? 'notch');
  const [dx, setDx] = useState(initial?.dx ?? 0.4);
  const [dy, setDy] = useState(initial?.dy ?? 0.4);
  if (!corner) return <p className="muted">Cả 4 góc đã cắt.</p>;

  // Phòng xem trước: bản sao đặt ở gốc toạ độ, thay góc đang sửa bằng giá trị trong form.
  const preview = copyRoom(room);
  Object.assign(preview, { x: 0, y: 0, openings: [] });
  preview.cuts = preview.cuts.filter((c) => c.corner !== corner && c.corner !== initial?.corner);
  preview.cuts.push({ corner, kind, dx, dy });
  clampOpenings(preview);
  const cut = cutOf(preview, corner)!;

  return (
    <>
      <h2 className="sheet-title">{initial ? 'Sửa góc cắt' : 'Cắt góc phòng'}</h2>
      <p className="muted">{room.name}: {m2(room.w)} × {m2(room.l)} m. Sàn còn {m2(floorArea(preview))} m².</p>
      <div className="row top">
        <div style={{ width: 150, height: 150, background: 'var(--field)', borderRadius: 12, flex: 'none' }}>
          <PlanCanvas plan={{ rooms: [preview] }} threeD={false} selectedId={preview.id} interactive={false} className="thumb" height={150} />
        </div>
        <div className="grow stack-8">
          <span className="t-strong">Góc</span>
          {/* Lưới 2 × 2 đúng vị trí góc trên mặt bằng. */}
          <div className="corner-grid">
            {['nw', 'ne', 'sw', 'se'].map((k) => (
              <button key={k} className={`chip${corner === k ? ' on' : ''}`} disabled={!free.includes(k)} onClick={() => setCorner(k)}>
                {cornerNames[k].replace('Góc ', '')}
              </button>
            ))}
          </div>
        </div>
      </div>
      <Segmented value={kind} onChange={setKind} options={[['notch', 'Cắt vuông', 'crop_square'], ['chamfer', 'Cắt chéo', 'change_history']]} />
      <p className="muted xs">{cutKinds[kind]}</p>
      <div className="form-row">
        <MeterField label="Theo chiều rộng" value={dx} min={0.05} max={room.w - 0.1} onChange={setDx} />
        <MeterField label="Theo chiều dài" value={dy} min={0.05} max={room.l - 0.1} onChange={setDy} />
      </div>
      {(Math.abs(cut.dx - dx) > 1e-9 || Math.abs(cut.dy - dy) > 1e-9) && (
        <p className="error xs">Góc bên cạnh cũng đã cắt nên kích thước được giới hạn còn {m2(cut.dx)} × {m2(cut.dy)} m.</p>
      )}
      <button className="btn" onClick={() => onDone(corner, cut)}>Cắt góc</button>
      {initial && <button className="btn text danger" onClick={() => onDone(initial.corner, null)}>Bỏ cắt góc này</button>}
    </>
  );
}

/** Thêm / sửa cửa đi, cửa sổ. onDone(null) là xoá cửa. */
function OpeningForm({ room, initial, onDone }: { room: Room; initial: Opening | null; onDone: (o: Opening | null) => void }) {
  const [o, setO] = useState<Opening>(() => (initial ? { ...initial } : door('s', 0.3)));
  const [rev, setRev] = useState(0); // đổi loại / tường thì dựng lại các ô số với giá trị mới
  const [from, to] = wallSpan(room, o.wall);
  const len = wallLength(room, o.wall);
  const trimmed = from > 0 || to < len;

  const setKind = (kind: string) => {
    const d = kind === 'door' ? door(o.wall, o.offset) : windowOf(o.wall, o.offset);
    setO({ ...o, kind, width: d.width, height: d.height, sill: d.sill });
    setRev(rev + 1);
  };

  return (
    <>
      <h2 className="sheet-title">{initial ? 'Sửa cửa' : 'Thêm cửa'}</h2>
      <Segmented value={o.kind} onChange={setKind} options={[['door', 'Cửa đi', 'door_front'], ['window', 'Cửa sổ', 'window']]} />
      <Segmented
        value={o.wall}
        onChange={(wall) => { setO({ ...o, wall }); setRev(rev + 1); }}
        options={Object.entries(wallNames).map(([k, v]): [string, string] => [k, v.replace('Tường ', '')])}
      />
      <p className="muted xs">
        {wallNames[o.wall]} dài {m2(len)} m
        {trimmed ? `, đặt cửa được từ ${m2(from)} đến ${m2(to)} m (phần còn lại đã cắt góc)` : ''}. Khoảng cách tính từ góc trái
        (tường trên / dưới) hoặc góc trên (tường trái / phải).
      </p>
      <div key={rev} className="form-row">
        <MeterField label="Cách góc" value={o.offset} min={from} max={to} onChange={(v) => setO((x) => ({ ...x, offset: v }))} />
        <MeterField label="Rộng" value={o.width} min={0.2} max={to - from} onChange={(v) => setO((x) => ({ ...x, width: v }))} />
        <MeterField label="Cao" value={o.height} min={0.2} max={room.h} onChange={(v) => setO((x) => ({ ...x, height: v }))} />
        {o.kind !== 'door' && <MeterField label="Bậu" value={o.sill} min={0} max={room.h} onChange={(v) => setO((x) => ({ ...x, sill: v }))} />}
      </div>
      <button className="btn" onClick={() => onDone(o)}>Xong</button>
      {initial && <button className="btn text danger" onClick={() => onDone(null)}>Xoá cửa</button>}
    </>
  );
}
