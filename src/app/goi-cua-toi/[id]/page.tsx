'use client';

// Tạo / sửa gói: chọn dự án và mẫu căn, thông tin chung, ảnh, danh sách hạng mục.
// Lưu là lưu cả gói trong một lần (BE: save_package). Sửa gói đang hiển thị thì gói về chờ duyệt.
// /goi-cua-toi/moi là gói mới; còn lại lấy gói từ danh sách /contractor/packages (BE không có GET một gói).

import { useParams, useRouter } from 'next/navigation';
import { useState } from 'react';
import { api, ApiError, type Json } from '@/lib/api';
import { errorMessage, parseMillions, parseNum, vnd, vnDecimal } from '@/lib/format';
import { useApp, useAuthLoad, useLoad } from '@/ui/app';
import { BottomBar, Field, Icon, Loaded, Pill, PhotoPicker, SectionTitle, Sheet, TopBar, statusOf } from '@/ui/kit';
import { packageStatus } from '@/ui/shared';

const ITEM_KEYS = ['room', 'name', 'material', 'size', 'qty', 'unit', 'unit_price', 'is_optional'];

export default function PackageEditorPage() {
  const { id } = useParams<{ id: string }>();
  const state = useAuthLoad<Json | null>(async () => {
    if (id === 'moi') return null;
    const pkg = ((await api.getAuth('/contractor/packages')) as Json[]).find((p) => p.id === id);
    if (!pkg) throw new ApiError(404, 'package_not_found');
    return pkg;
  }, [id]);
  return <Loaded state={state}>{(pkg) => <Editor key={pkg?.id ?? 'new'} initial={pkg} />}</Loaded>;
}

function Editor({ initial }: { initial: Json | null }) {
  const router = useRouter();
  const { toast, showError } = useApp();
  const [pkg, setPkg] = useState<Json | null>(initial);
  const [f, setF] = useState({
    name: initial?.name ?? '',
    style: initial?.style ?? '',
    days: initial?.duration_days != null ? String(initial.duration_days) : '',
    warranty: initial?.warranty_months != null ? String(initial.warranty_months) : '',
  });
  const [items, setItems] = useState<Json[]>(() => (initial?.items ?? []).map((i: Json) => ({ ...i, qty: Number(i.qty) })));
  const [images, setImages] = useState<string[]>(initial?.images ?? []);
  const [projectSlug, setProjectSlug] = useState<string>(initial?.unit_type?.project?.slug ?? '');
  const [unitTypeId, setUnitTypeId] = useState<string>(initial?.unit_type?.id ?? '');
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState<number | 'new' | null>(null);
  const projects = useLoad<Json[]>(() => api.get('/projects'), []);
  const project = useLoad<Json | null>(() => (projectSlug ? api.get(`/projects/${projectSlug}`) : Promise.resolve(null)), [projectSlug]);

  const status: string = pkg?.status ?? 'draft';
  const [label, tone] = statusOf(packageStatus, status);
  const total = items.filter((i) => !i.is_optional).reduce((s, i) => s + Math.round(i.qty * i.unit_price), 0);

  const run = async (action: () => Promise<void>) => {
    setBusy(true);
    try {
      await action();
    } catch (e) {
      showError(e);
    } finally {
      setBusy(false);
    }
  };

  const save = () => run(async () => {
    const int = (s: string) => (/^\d+$/.test(s.trim()) ? parseInt(s, 10) : null);
    const body = {
      unit_type_id: unitTypeId || null,
      name: f.name,
      style: f.style,
      duration_days: int(f.days),
      warranty_months: int(f.warranty),
      images,
      items: items.map((i) => Object.fromEntries(ITEM_KEYS.map((k) => [k, i[k]]))),
    };
    const saved: Json = pkg ? await api.putAuth(`/contractor/packages/${pkg.id}`, body) : await api.postAuth('/contractor/packages', body);
    setPkg(saved);
    toast(saved.status === 'pending' && initial?.status === 'published' ? 'Đã lưu. Gói tạm ẩn chờ duyệt lại vì có thay đổi.' : 'Đã lưu gói');
    if (!pkg) router.replace(`/goi-cua-toi/${saved.id}`);
  });

  const submit = () => run(async () => {
    setPkg(await api.postAuth(`/contractor/packages/${pkg!.id}/submit`));
    toast('Đã gửi duyệt. Thường duyệt trong 1 ngày làm việc.');
  });

  const remove = () => run(async () => {
    if (!confirm('Xoá gói này?')) return;
    await api.deleteAuth(`/contractor/packages/${pkg!.id}`);
    router.push('/goi-cua-toi');
  });

  return (
    <>
      <TopBar
        title={pkg ? 'Sửa gói' : 'Gói mới'}
        fallback="/goi-cua-toi"
        actions={pkg && (status === 'draft' || status === 'pending') && (
          <button className="icon-btn" title="Xoá gói" aria-label="Xoá gói" disabled={busy} onClick={remove}><Icon name="delete" /></button>
        )}
      />
      <main className="page has-bar">
        <div className="form">
          {pkg && <span><Pill tone={tone}>{label}</Pill></span>}
          <SectionTitle>Mẫu căn</SectionTitle>
          <Field label="Dự án">
            <select value={projectSlug} onChange={(e) => { setProjectSlug(e.target.value); setUnitTypeId(''); }}>
              <option value="" disabled>Chọn dự án</option>
              {(projects.data ?? []).map((p) => <option key={p.slug} value={p.slug}>{p.name}</option>)}
            </select>
          </Field>
          <Field label="Mẫu căn">
            <select value={unitTypeId} onChange={(e) => setUnitTypeId(e.target.value)} disabled={!project.data}>
              <option value="" disabled>Chọn mẫu căn</option>
              {(project.data?.unit_types ?? []).map((u: Json) => (
                <option key={u.id} value={u.id}>{u.name} · {vnDecimal(u.area_m2)} m²</option>
              ))}
            </select>
          </Field>

          <SectionTitle>Thông tin gói</SectionTitle>
          <Field label="Tên gói"><input placeholder="Gói Cơ Bản" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></Field>
          <Field label="Phong cách"><input placeholder="Hiện đại" value={f.style} onChange={(e) => setF({ ...f, style: e.target.value })} /></Field>
          <div className="form-row">
            <Field label="Ngày thi công"><input inputMode="numeric" value={f.days} onChange={(e) => setF({ ...f, days: e.target.value })} /></Field>
            <Field label="Bảo hành (tháng)"><input inputMode="numeric" value={f.warranty} onChange={(e) => setF({ ...f, warranty: e.target.value })} /></Field>
          </div>

          <SectionTitle>Ảnh gói</SectionTitle>
          <p className="muted small">Ảnh render hoặc ảnh công trình thực tế của gói này. Ảnh đầu tiên làm ảnh bìa.</p>
          <PhotoPicker photos={images} onChange={setImages} />

          <SectionTitle>Hạng mục ({items.length})</SectionTitle>
          <div>
            {items.map((it, i) => (
              <button key={i} className="card row-card" onClick={() => setEditing(i)}>
                <span className="grow">
                  <span className="t-title" style={{ fontWeight: 500 }}>{it.room} · {it.name}{it.is_optional ? ' (tuỳ chọn)' : ''}</span>
                  <span className="muted">{vnDecimal(it.qty)} {it.unit || 'bộ'} × {vnd(it.unit_price)}</span>
                </span>
                <b>{vnd(Math.round(it.qty * it.unit_price))}</b>
              </button>
            ))}
          </div>
          <button className="btn outline" onClick={() => setEditing('new')}><Icon name="add" /> Thêm hạng mục</button>
        </div>
      </main>

      <BottomBar>
        <div className="row">
          <span className="muted grow">Giá trọn gói</span>
          <span className="t-price">{vnd(total)}</span>
        </div>
        <div className="btn-row">
          <button className="btn" disabled={busy} onClick={save}>Lưu</button>
          {pkg && (status === 'draft' || status === 'hidden') && (
            <button className="btn outline" disabled={busy} onClick={submit}>Gửi duyệt</button>
          )}
        </div>
      </BottomBar>

      <Sheet open={editing != null} onClose={() => setEditing(null)}>
        {editing != null && (
          <ItemForm
            initial={editing === 'new' ? null : items[editing]}
            onDone={(item) => {
              if (editing === 'new') setItems([...items, item!]);
              else setItems(items.flatMap((x, j) => (j !== editing ? [x] : item ? [item] : [])));
              setEditing(null);
            }}
          />
        )}
      </Sheet>
    </>
  );
}

/** Thêm / sửa một hạng mục. onDone(null) là xoá. */
function ItemForm({ initial, onDone }: { initial: Json | null; onDone: (item: Json | null) => void }) {
  const { toast } = useApp();
  const [f, setF] = useState({
    room: initial?.room ?? '',
    name: initial?.name ?? '',
    material: initial?.material ?? '',
    size: initial?.size ?? '',
    qty: initial ? vnDecimal(initial.qty) : '1',
    unit: initial?.unit ?? 'bộ',
    price: initial ? vnDecimal(initial.unit_price / 1000000) : '',
  });
  const [optional, setOptional] = useState<boolean>(initial?.is_optional === true);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value });

  const done = (e: React.FormEvent) => {
    e.preventDefault();
    const qty = parseNum(f.qty);
    const price = parseMillions(f.price);
    if (!f.room.trim() || !f.name.trim()) return toast(errorMessage('missing_name'));
    if (qty == null || qty <= 0) return toast(errorMessage('invalid_qty'));
    if (price == null) return toast(errorMessage('invalid_price'));
    onDone({
      room: f.room.trim(), name: f.name.trim(), material: f.material.trim(), size: f.size.trim(),
      qty, unit: f.unit.trim(), unit_price: price, is_optional: optional,
    });
  };

  return (
    <form className="form" onSubmit={done}>
      <h2 className="sheet-title">{initial ? 'Sửa hạng mục' : 'Thêm hạng mục'}</h2>
      <div className="form-row">
        <Field label="Phòng"><input placeholder="Bếp" value={f.room} onChange={set('room')} /></Field>
        <Field label="Hạng mục"><input placeholder="Tủ bếp dưới" value={f.name} onChange={set('name')} /></Field>
      </div>
      <div className="form-row">
        <Field label="Vật liệu"><input value={f.material} onChange={set('material')} /></Field>
        <Field label="Kích thước"><input value={f.size} onChange={set('size')} /></Field>
      </div>
      <div className="form-row">
        <Field label="Số lượng"><input inputMode="decimal" value={f.qty} onChange={set('qty')} /></Field>
        <Field label="Đơn vị"><input placeholder="bộ, md, m²" value={f.unit} onChange={set('unit')} /></Field>
        <Field label="Đơn giá (triệu)"><input inputMode="decimal" value={f.price} onChange={set('price')} /></Field>
      </div>
      <label className="switch-row">
        <span className="grow">
          <span className="t-strong" style={{ display: 'block' }}>Hạng mục tuỳ chọn</span>
          <span className="muted small">Không tính vào giá trọn gói, chủ nhà tự chọn thêm</span>
        </span>
        <input type="checkbox" role="switch" checked={optional} onChange={(e) => setOptional(e.target.checked)} />
      </label>
      <button className="btn">Xong</button>
      {initial && <button type="button" className="btn text danger" onClick={() => onDone(null)}>Xoá hạng mục</button>}
    </form>
  );
}
