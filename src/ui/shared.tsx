'use client';

// Thành phần nghiệp vụ dùng ở nhiều màn: trạng thái, thẻ đánh giá, hướng dẫn đo, chọn bản đo, form hồ sơ nhà thầu.

import Link from 'next/link';
import { useState } from 'react';
import { api, meta, type Json } from '@/lib/api';
import { m2, vnDecimal } from '@/lib/format';
import { useApp, useLoad } from './app';
import {
  ChipPicker, Field, Icon, InfoPanel, Loaded, Pill, PhotoGrid, Sheet, requestPlace, servicesLine, statusOf, type StatusMap,
} from './kit';

export const requestStatus: StatusMap = {
  open: ['Đang nhận báo giá', 'accent'],
  matched: ['Đã chọn nhà thầu', 'success'],
  closed: ['Đã đóng', 'muted'],
};

export const jobStatus: StatusMap = {
  active: ['Đang thi công', 'primary'],
  completed: ['Đã bàn giao', 'success'],
  cancelled: ['Đã huỷ', 'muted'],
};

/** Nơi của công trình: dự án · mẫu căn, hoặc địa chỉ. */
export const jobPlace = (job: Json) => {
  const unit = job.request?.unit_type;
  return unit ? `${unit.project.name} · ${unit.name}` : `${job.request?.address ?? ''}`;
};

export const packageStatus: StatusMap = {
  draft: ['Nháp', 'muted'],
  pending: ['Chờ duyệt', 'accent'],
  published: ['Đang hiển thị', 'success'],
  hidden: ['Đã ẩn', 'muted'],
};

export const leadStatus: StatusMap = {
  sent: ['Cần báo giá', 'accent'],
  quoted: ['Đã báo giá', 'primary'],
  accepted: ['Khách đã chọn bạn', 'success'],
  declined: ['Khách chọn nhà thầu khác', 'muted'],
};

/** Tóm tắt yêu cầu của khách cho nhà thầu: nơi (kèm diện tích), hạng mục, gói, có bản đo. */
export const leadLines = (r: Json): string[] =>
  [requestPlace(r, true), servicesLine(r), r.package && `Gói: ${r.package.name}`, r.measurement && 'Có bản đo nhà'].filter(Boolean);

export const profileStatus: StatusMap = {
  pending: ['Chờ xác minh', 'accent'],
  verified: ['Đã xác minh', 'success'],
  rejected: ['Bị từ chối', 'error'],
};

export const reviewCriteria: Record<string, string> = {
  quality: 'Chất lượng',
  punctuality: 'Đúng hạn',
  price_honesty: 'Đúng giá',
  attitude: 'Thái độ',
};

/** Đánh giá: điểm 4 tiêu chí, nội dung, ảnh, trả lời của nhà thầu. Dùng ở công trình và hồ sơ nhà thầu. */
export function ReviewCard({ review: r, onReply }: { review: Json; onReply?: () => void }) {
  const keys = Object.keys(reviewCriteria);
  const avg = keys.reduce((s, k) => s + Number(r[k]), 0) / keys.length;
  return (
    <div className="card pad stack-8">
      <div className="row">
        <span className="t-title grow">{r.owner_name || 'Chủ nhà'}</span>
        <Icon name="star" fill size={20} className="c-accent" />
        <b>{vnDecimal(avg.toFixed(1))}</b>
      </div>
      <div className="row wrap">
        {keys.map((k) => <Pill key={k}>{reviewCriteria[k]} {r[k]}/5</Pill>)}
      </div>
      {r.content && <p>{r.content}</p>}
      {r.photos?.length > 0 && <PhotoGrid urls={r.photos} size={72} />}
      {r.reply && <div className="note-box">Nhà thầu trả lời: {r.reply}</div>}
      {onReply && (
        <div style={{ textAlign: 'right' }}>
          <button className="btn text" onClick={onReply}>{r.reply ? 'Sửa trả lời' : 'Trả lời'}</button>
        </div>
      )}
    </div>
  );
}

const guideSteps: [string, string][] = [
  ['Đo sát chân tường', 'Đo chiều dài và chiều rộng phòng ở sát sàn, từ mép tường này sang mép tường kia. Đo 2 lần, lấy số nhỏ hơn.'],
  ['Chiều cao trần', 'Đo từ sàn lên trần ở giữa phòng. Căn hộ thường 2,7 - 3,0 m; WC thấp hơn nếu có trần giả.'],
  ['Cửa đi, cửa sổ', 'Đo khoảng cách từ góc tường tới mép cửa, rồi đo rộng, cao của cửa. Cửa sổ đo thêm từ sàn tới bậu.'],
  ['Xếp phòng', 'Kéo các phòng trên mặt bằng cho sát nhau như thực tế. Phòng tự hít vào mép phòng bên cạnh.'],
  ['Chụp ảnh bổ sung', 'Khi gửi yêu cầu, ghi chú những chỗ đặc biệt: cột, dầm, ống nước, ổ điện cần giữ.'],
];

/** Hướng dẫn cách đo nhà. */
export function MeasureGuide({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <Sheet open={open} onClose={onClose} title="Cách đo nhà trong 15 phút">
      <p className="muted">Cần: thước dây hoặc thước laser, điện thoại. Nên đo khi nhà còn trống.</p>
      <div className="steps">
        {guideSteps.map(([title, body], i) => (
          <div key={title} className="row top">
            <span className="step-no">{i + 1}</span>
            <div className="grow">
              <div className="t-strong">{title}</div>
              <div className="muted">{body}</div>
            </div>
          </div>
        ))}
      </div>
      <InfoPanel>
        <span className="primary">Số đo để nhà thầu báo giá sơ bộ. Trước khi sản xuất, nhà thầu vẫn đo lại tại nhà để chốt kích thước.</span>
      </InfoPanel>
      <button className="btn outline" onClick={onClose}>Đã hiểu</button>
    </Sheet>
  );
}

/** Chọn bản đo để đính kèm yêu cầu báo giá. */
export function MeasurementPicker({ value, onChange }: { value: string | null; onChange: (v: string | null) => void }) {
  const state = useLoad<Json[]>(() => api.getAuth('/measurements'), []);
  const rows = state.data ?? [];
  return (
    <div className="stack-8">
      <Field label="Đính kèm bản đo nhà">
        <select value={rows.some((m) => m.id === value) ? value! : ''} onChange={(e) => onChange(e.target.value || null)}>
          <option value="">Không đính kèm</option>
          {rows.map((m) => <option key={m.id} value={m.id}>{m.name} · {m2(m.summary.floor_m2)} m²</option>)}
        </select>
      </Field>
      {state.data && rows.length === 0 && (
        <Link className="btn text" href="/do-nha" style={{ alignSelf: 'flex-start' }}>
          <Icon name="add" /> Tự đo nhà để báo giá sát hơn
        </Link>
      )}
    </div>
  );
}

/** Dải trạng thái xác minh, chỉ hiện khi chưa xác minh. */
export function VerifyBanner({ profile }: { profile: Json }) {
  if (profile.status === 'verified') return null;
  const [label, tone] = statusOf(profileStatus, profile.status);
  return (
    <InfoPanel>
      <Pill tone={tone}>{label}</Pill>
      <p className="muted small gap-t8">
        {profile.status === 'rejected'
          ? 'Hồ sơ chưa được duyệt. Liên hệ đội vận hành để bổ sung giấy tờ.'
          : 'Đội vận hành sẽ gọi xác minh trong 1 ngày làm việc. Gói của bạn hiển thị với chủ nhà sau khi được xác minh.'}
      </p>
    </InfoPanel>
  );
}

const splitList = (s: string) => s.split(',').map((x) => x.trim()).filter(Boolean);

/** Form hồ sơ nhà thầu: đăng ký (initial null, POST) hoặc sửa (PATCH). */
export function ProfileForm({ initial, submitLabel, onSaved }: { initial: Json | null; submitLabel: string; onSaved: () => void }) {
  const { showError } = useApp();
  const metaState = useLoad(meta, []);
  const [f, setF] = useState({
    name: initial?.name ?? '',
    address: initial?.address ?? '',
    years: initial?.years_experience != null ? String(initial.years_experience) : '',
    website: initial?.website ?? '',
    styles: (initial?.styles ?? []).join(', '),
    bio: initial?.bio ?? '',
    tax: '',
  });
  const [areas, setAreas] = useState<string[]>(initial?.areas ?? []);
  const [services, setServices] = useState<string[]>(initial?.services ?? []);
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value });

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    const years = parseInt(f.years.trim(), 10);
    const body = {
      name: f.name,
      address: f.address,
      areas,
      services,
      years_experience: Number.isNaN(years) ? null : years,
      website: f.website.trim(),
      styles: splitList(f.styles),
      bio: f.bio,
      ...(f.tax.trim() && { tax_code: f.tax.trim() }),
    };
    try {
      if (initial) await api.patchAuth('/contractor', body);
      else await api.postAuth('/contractor', body);
      onSaved();
    } catch (err) {
      showError(err);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Loaded state={metaState}>
      {(m) => (
        <form className="form" onSubmit={submit}>
          <Field label="Tên xưởng / công ty"><input value={f.name} onChange={set('name')} /></Field>
          <Field label="Mã số thuế" helper={initial ? 'Để trống nếu không đổi' : 'Để xác minh, không hiển thị với chủ nhà'}>
            <input value={f.tax} onChange={set('tax')} />
          </Field>
          <Field label="Địa chỉ xưởng"><input value={f.address} onChange={set('address')} /></Field>
          <Field label="Số năm kinh nghiệm"><input inputMode="numeric" value={f.years} onChange={set('years')} /></Field>
          <Field label="Fanpage / website">
            <input type="url" placeholder="facebook.com/xuong-cua-ban" value={f.website} onChange={set('website')} />
          </Field>
          <ChipPicker label="Hạng mục nhận làm" options={m.services} selected={services} onChange={setServices} />
          <ChipPicker label="Tỉnh / thành nhận thi công" options={m.provinces} selected={areas} onChange={setAreas} />
          <Field label="Phong cách" helper="Ví dụ: Hiện đại, Japandi, Tối giản"><input value={f.styles} onChange={set('styles')} /></Field>
          <Field label="Giới thiệu"><textarea rows={3} maxLength={2000} value={f.bio} onChange={set('bio')} /></Field>
          <button className="btn" disabled={busy}>{submitLabel}</button>
        </form>
      )}
    </Loaded>
  );
}
