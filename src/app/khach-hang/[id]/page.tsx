'use client';

// Chi tiết khách: thông tin yêu cầu, gửi hoặc sửa báo giá (theo món, trọn gói, hoặc làm việc trực tiếp).
// BE không có GET một khách: lấy từ danh sách /contractor/leads theo id yêu cầu.

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useState } from 'react';
import { api, ApiError, type Json } from '@/lib/api';
import { errorMessage, parseMillions, vnd, vnDecimal } from '@/lib/format';
import { askedItems, planFromJson, quoteDiff, type AskedItem } from '@/lib/measure';
import { useApp, useAuthLoad } from '@/ui/app';
import { Field, Icon, IconBadge, InfoPanel, Loaded, Pill, PhoneRow, SectionTitle, Segmented, Sheet, TopBar, statusOf } from '@/ui/kit';
import { leadLines, leadStatus } from '@/ui/shared';

export default function LeadPage() {
  const { id } = useParams<{ id: string }>();
  const state = useAuthLoad(async () => {
    const lead = ((await api.getAuth('/contractor/leads')) as Json[]).find((l) => l.request.id === id);
    if (!lead) throw new ApiError(404, 'request_not_found');
    // Đồ chủ nhà chọn trong bản đo (để đánh dấu món thêm / bỏ) và tên các phòng.
    let asked: AskedItem[] = [], rooms: string[] = [];
    const mid = lead.request.measurement?.id;
    if (mid) {
      try {
        const plan = planFromJson((await api.getAuth(`/measurements/${mid}`)).data);
        asked = askedItems(plan);
        rooms = plan.rooms.map((r) => r.name);
      } catch {
        // Không tải được bản đo thì vẫn báo giá trọn gói được.
      }
    }
    return { lead, asked, rooms };
  }, [id]);
  return (
    <>
      <TopBar title="Yêu cầu của khách" fallback="/khach-hang" />
      <main className="page">
        <Loaded state={state}>{(d) => <Lead {...d} />}</Loaded>
      </main>
    </>
  );
}

/** Một món đang sửa trong báo giá; đơn giá nhập theo triệu đồng. */
interface Line { room: string; name: string; qty: number; note: string | null; price: string }

const toLine = (j: AskedItem): Line => ({
  room: j.room ?? 'Chung',
  name: j.name,
  qty: j.qty ?? 1,
  note: j.note ?? null,
  price: j.unit_price ? vnDecimal(j.unit_price / 1000000) : '',
});

const lineJson = (l: Line): AskedItem => ({
  room: l.room, name: l.name, qty: l.qty, unit_price: parseMillions(l.price) ?? 0, ...(l.note ? { note: l.note } : {}),
});

function Lead({ lead, asked, rooms }: { lead: Json; asked: AskedItem[]; rooms: string[] }) {
  const router = useRouter();
  const { toast, showError } = useApp();
  const r = lead.request;
  const [price, setPrice] = useState(lead.price == null ? '' : vnDecimal(lead.price / 1000000));
  const [days, setDays] = useState(lead.duration_days != null ? String(lead.duration_days) : '');
  const [message, setMessage] = useState<string>(lead.message ?? '');
  const [offline, setOffline] = useState(lead.mode === 'offline');
  const [busy, setBusy] = useState(false);
  // Món đang báo: bắt đầu từ báo giá cũ, chưa báo thì từ đồ chủ nhà chọn (đơn giá để trống).
  const [lines, setLines] = useState<Line[]>(() => ((lead.items as AskedItem[] | null)?.length ? lead.items : asked).map(toLine));
  const [adding, setAdding] = useState(false);

  const [label, tone] = statusOf(leadStatus, lead.status);
  const canQuote = r.status === 'open' && (lead.status === 'sent' || lead.status === 'quoted');

  let total: number | null = 0;
  for (const l of lines) {
    const p = parseMillions(l.price);
    if (p == null) {
      total = null;
      break;
    }
    total += p * l.qty;
  }

  const update = (i: number, l: Line | null) => setLines(lines.flatMap((x, j) => (j !== i ? [x] : l ? [l] : [])));

  const submit = async () => {
    const d = /^\d+$/.test(days.trim()) ? parseInt(days, 10) : null;
    let body: Json;
    if (offline) {
      if (!message.trim()) return toast(errorMessage('missing_message'));
      body = { mode: 'offline', message, ...(d != null && { duration_days: d }) };
    } else {
      if (d == null || d <= 0) return toast(errorMessage('invalid_duration_days'));
      if (!lines.length) {
        const p = parseMillions(price);
        if (p == null) return toast(errorMessage('invalid_price'));
        body = { mode: 'in_app', price: p, duration_days: d, message };
      } else {
        if (total == null) return toast(errorMessage('invalid_price'));
        body = { mode: 'in_app', duration_days: d, message, items: lines.map(lineJson) };
      }
    }
    setBusy(true);
    try {
      await api.postAuth(`/contractor/leads/${r.id}/quote`, body);
      toast(offline ? 'Đã gửi đề nghị làm việc trực tiếp' : 'Đã gửi báo giá cho chủ nhà');
      router.push('/khach-hang');
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  const diff = quoteDiff(asked, lines.map(lineJson));

  return (
    <>
      <InfoPanel>
        <span className="t-title">{lead.owner.full_name || 'Chủ nhà'}</span>
        {leadLines(r).map((s) => <span key={s} className="muted">{s}</span>)}
        {r.budget != null && <span className="muted">Ngân sách {vnd(r.budget)}</span>}
        {r.note && <p className="pre gap-t8">{r.note}</p>}
        <Pill tone={tone}>{label}</Pill>
      </InfoPanel>
      {r.measurement && (
        <Link className="card soft row-card gap-t" href={`/ban-do/${r.measurement.id}`}>
          <IconBadge icon="view_in_ar" size={40} />
          <span className="grow">
            <span className="t-strong" style={{ display: 'block' }}>Khách đã tự đo nhà</span>
            <span className="muted">Mặt bằng, khung 3D, diện tích{asked.length ? `, ${asked.length} món đồ khách chọn` : ''}</span>
          </span>
          <Icon name="chevron_right" />
        </Link>
      )}
      {r.job && (
        <Link className="btn block gap-t" href={`/cong-trinh/${r.job.id}`}><Icon name="construction" /> Mở công trình</Link>
      )}
      {lead.owner.phone ? (
        <>
          <SectionTitle>Liên hệ khách</SectionTitle>
          <PhoneRow phone={lead.owner.phone} />
        </>
      ) : lead.status !== 'declined' && (
        <p className="muted small gap-t">Số điện thoại của khách hiện khi khách chọn bạn.</p>
      )}

      {canQuote && (
        <div className="form">
          <SectionTitle>{lead.status === 'quoted' ? 'Sửa trả lời' : 'Trả lời khách'}</SectionTitle>
          <Segmented
            value={offline}
            onChange={setOffline}
            options={[[false, 'Báo giá trong app', 'request_quote'], [true, 'Làm việc trực tiếp', 'handshake']]}
          />
          {offline ? (
            <p className="muted small">
              Bạn và khách tự gặp, khảo sát và thoả thuận giá bên ngoài. Nếu khách chọn bạn, hai bên thấy số điện thoại; app chỉ theo
              dõi tiến độ 4 mốc (báo xong kèm ảnh, khách nghiệm thu), không ghi nhận tiền.
            </p>
          ) : lines.length || asked.length ? (
            <div className="stack-8">
              <p className="muted small">Sửa số lượng, bỏ hoặc đề xuất thêm món; nhập đơn giá từng món. Tổng giá tự cộng.</p>
              {lines.map((l, i) => (
                <div key={`${l.room}|${l.name}|${i}`} className="card" style={{ padding: '8px 4px 8px 12px', margin: 0 }}>
                  <div className="row" style={{ gap: 4 }}>
                    <div className="grow stack-8" style={{ gap: 2, alignItems: 'flex-start' }}>
                      <span className="t-strong">{l.name}</span>
                      <span className="muted xs">{[l.room, l.note].filter(Boolean).join(' · ')}</span>
                      {diff[i]?.tag === 'added' && <Pill tone="success">Bạn đề xuất thêm</Pill>}
                      {diff[i]?.tag === 'changed' && <Pill tone="accent">Khách chọn {diff[i].askedQty}</Pill>}
                    </div>
                    <span className="qty">
                      <button className="icon-btn sm" title={l.qty > 1 ? 'Bớt' : 'Bỏ món'} onClick={() => update(i, l.qty > 1 ? { ...l, qty: l.qty - 1 } : null)}>
                        <Icon name={l.qty > 1 ? 'remove_circle' : 'delete'} size={22} />
                      </button>
                      <b>{l.qty}</b>
                      <button className="icon-btn sm" title="Thêm" disabled={l.qty >= 99} onClick={() => update(i, { ...l, qty: l.qty + 1 })}>
                        <Icon name="add_circle" size={22} />
                      </button>
                    </span>
                    <span className="field dense" style={{ width: 96 }}>
                      <span className="field-box">
                        <input inputMode="decimal" placeholder="Giá" aria-label={`Đơn giá ${l.name}`} value={l.price} onChange={(e) => update(i, { ...l, price: e.target.value })} />
                        <span className="field-suffix">tr</span>
                      </span>
                    </span>
                  </div>
                </div>
              ))}
              {diff.filter((d) => d.tag === 'removed').map((d) => (
                <div key={`rm-${d.room}|${d.name}`} className="row" style={{ padding: '4px 0' }}>
                  <span className="grow">
                    <span className="strike" style={{ display: 'block' }}>{d.name} × {d.qty}</span>
                    <span className="muted xs">{d.room} · khách chọn, bạn đã bỏ</span>
                  </span>
                  <button className="btn text" onClick={() => setLines([...lines, toLine({ room: d.room, name: d.name, qty: d.qty, note: d.note })])}>
                    Thêm lại
                  </button>
                </div>
              ))}
              <button className="btn text" style={{ alignSelf: 'flex-start' }} onClick={() => setAdding(true)}>
                <Icon name="add" /> Đề xuất thêm món
              </button>
              <div className="info" style={{ flexDirection: 'row', alignItems: 'center' }}>
                <span className="muted grow">Tổng báo giá</span>
                <b className="primary" style={{ fontSize: 16 }}>{total == null ? 'Nhập đủ đơn giá' : vnd(total)}</b>
              </div>
            </div>
          ) : (
            <Field label="Giá trọn gói (triệu đồng)">
              <input inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} />
            </Field>
          )}
          <Field label="Số ngày thi công" helper={offline ? 'Không bắt buộc' : undefined}>
            <input inputMode="numeric" value={days} onChange={(e) => setDays(e.target.value)} />
          </Field>
          <Field label={offline ? 'Lời nhắn cho khách (bắt buộc)' : 'Lời nhắn cho khách'}>
            <textarea
              rows={4}
              maxLength={2000}
              placeholder={offline ? 'Lịch hẹn khảo sát, cách làm việc...' : 'Lịch khảo sát, vật liệu đề xuất, điều kiện thanh toán...'}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
            />
          </Field>
          <button className="btn" disabled={busy} onClick={submit}>{offline ? 'Gửi đề nghị làm việc trực tiếp' : 'Gửi báo giá'}</button>
        </div>
      )}

      <Sheet open={adding} onClose={() => setAdding(false)} title="Đề xuất thêm món">
        <AddLine rooms={[...rooms, 'Chung']} onDone={(l) => { setLines([...lines, l]); setAdding(false); }} onCancel={() => setAdding(false)} />
      </Sheet>
    </>
  );
}

function AddLine({ rooms, onDone, onCancel }: { rooms: string[]; onDone: (l: Line) => void; onCancel: () => void }) {
  const [room, setRoom] = useState(rooms[0]);
  const [name, setName] = useState('');
  const [note, setNote] = useState('');
  return (
    <form
      className="form"
      onSubmit={(e) => {
        e.preventDefault();
        if (name.trim()) onDone({ room, name: name.trim(), qty: 1, note: note.trim() || null, price: '' });
      }}
    >
      <Field label="Phòng">
        <select value={room} onChange={(e) => setRoom(e.target.value)}>{rooms.map((r) => <option key={r}>{r}</option>)}</select>
      </Field>
      <Field label="Tên món">
        <input autoFocus maxLength={50} placeholder="Ví dụ: Nhân công lắp đặt" value={name} onChange={(e) => setName(e.target.value)} />
      </Field>
      <Field label="Ghi chú"><input maxLength={100} value={note} onChange={(e) => setNote(e.target.value)} /></Field>
      <div className="btn-row">
        <button type="button" className="btn outline" onClick={onCancel}>Huỷ</button>
        <button className="btn">Thêm</button>
      </div>
    </form>
  );
}
