'use client';

// Thành phần giao diện dùng chung (port từ common.dart, theme.dart, photos.dart).

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { uploadPhoto, type Json } from '@/lib/api';
import { localPhone, vnDecimal, vndShort } from '@/lib/format';
import { errorText, useApp } from './app';

/** Màu trạng thái: tên token trong globals.css. */
export type Tone = 'primary' | 'accent' | 'success' | 'error' | 'muted';
export type StatusMap = Record<string, [string, Tone]>;
export const statusOf = (map: StatusMap, key: unknown): [string, Tone] => map[String(key)] ?? [String(key), 'muted'];

/** Icon Material Symbols (font Google), cùng bộ icon với app Flutter. */
export function Icon({ name, fill, size, className }: { name: string; fill?: boolean; size?: number; className?: string }) {
  return (
    <span
      className={`ms${fill ? ' fill' : ''}${className ? ` ${className}` : ''}`}
      style={size ? { fontSize: size } : undefined}
      aria-hidden
    >
      {name}
    </span>
  );
}

/** Thanh tiêu đề: nút quay lại, tiêu đề giữa, hành động bên phải. */
export function TopBar({ title, back = true, actions, fallback = '/', onBack }: {
  title?: ReactNode; back?: boolean; actions?: ReactNode; fallback?: string;
  /** Thay hành vi quay lại mặc định (ví dụ hỏi trước khi bỏ thay đổi chưa lưu). */
  onBack?: () => void;
}) {
  const router = useRouter();
  return (
    <header className="topbar">
      <div className="topbar-side">
        {back && (
          <button
            className="icon-btn"
            aria-label="Quay lại"
            onClick={onBack ?? (() => (history.length > 1 ? router.back() : router.push(fallback)))}
          >
            <Icon name="arrow_back" />
          </button>
        )}
      </div>
      <h1 className="topbar-title">{title}</h1>
      <div className="topbar-side end">{actions}</div>
    </header>
  );
}

export const Spinner = () => <div className="center-pad"><div className="spinner" /></div>;

/** Hiện vòng quay khi chờ, lỗi thì có nút thử lại, xong thì gọi [children] với dữ liệu. */
export function Loaded<T>({ state, children }: {
  state: { data?: T; error?: unknown; loading: boolean; reload: () => void };
  children: (data: T) => ReactNode;
}) {
  if (state.error) {
    return (
      <div className="center-pad">
        <Icon name="wifi_off" size={40} className="muted" />
        <p style={{ textAlign: 'center' }}>{errorText(state.error)}</p>
        <button className="btn outline" onClick={state.reload}>Thử lại</button>
      </div>
    );
  }
  if (state.loading && state.data === undefined) return <Spinner />;
  return <>{children(state.data as T)}</>;
}

export const SectionTitle = ({ children }: { children: ReactNode }) => <h2 className="section-title">{children}</h2>;

/** Icon trong vòng tròn nền xanh nhạt, dùng ở đầu dòng danh sách. */
export function IconBadge({ icon, size = 44 }: { icon: string; size?: number }) {
  return (
    <span className="badge" style={{ width: size, height: size }}>
      <Icon name={icon} size={size * 0.5} />
    </span>
  );
}

/** Hình minh hoạ: icon lớn trên các vòng tròn đồng tâm. */
export function Illustration({ icon }: { icon: string }) {
  return (
    <div className="illus" aria-hidden>
      <span style={{ width: 200, height: 200, opacity: 0.35 }} />
      <span style={{ width: 150, height: 150, opacity: 0.6 }} />
      <span style={{ width: 104, height: 104 }} />
      <Icon name={icon} size={52} />
    </div>
  );
}

/** Màn trống: minh hoạ, tiêu đề, mô tả, tuỳ chọn một nút. */
export function EmptyState({ icon, title, body, action }: { icon: string; title: string; body: string; action?: ReactNode }) {
  return (
    <div className="empty">
      <Illustration icon={icon} />
      <h3>{title}</h3>
      <p className="muted">{body}</p>
      {action && <div style={{ marginTop: 24 }}>{action}</div>}
    </div>
  );
}

/** Một dòng danh sách dạng card: icon tròn, tiêu đề, mô tả, mũi tên. [href] là link, [onClick] là nút. */
export function RowCard({ icon, title, subtitle, href, onClick, trailing }: {
  icon: string; title: ReactNode; subtitle?: ReactNode; href?: string; onClick?: () => void; trailing?: ReactNode;
}) {
  const body = (
    <>
      <IconBadge icon={icon} />
      <span className="grow">
        <span className="t-title">{title}</span>
        {subtitle && <span className="muted pre">{subtitle}</span>}
      </span>
      {trailing ?? ((href || onClick) && <Icon name="chevron_right" className="muted" />)}
    </>
  );
  if (href) return <Link className="card row-card" href={href}>{body}</Link>;
  if (onClick) return <button className="card row-card" onClick={onClick}>{body}</button>;
  return <div className="card row-card">{body}</div>;
}

/** Nhãn nhỏ nền xám (phong cách, số ngày...). [tone] cho nhãn trạng thái. */
export function Pill({ children, tone }: { children: ReactNode; tone?: Tone }) {
  return <span className={`pill${tone ? ` tone-${tone}` : ''}`}>{children}</span>;
}

/** Khung nền xanh nhạt tóm tắt thông tin ở đầu màn chi tiết. */
export const InfoPanel = ({ children }: { children: ReactNode }) => <div className="info">{children}</div>;

/** Số điện thoại hiện sau khi hai bên đã chốt: bấm để gọi, nút sao chép. */
export function PhoneRow({ phone }: { phone: string }) {
  const { toast } = useApp();
  const p = localPhone(phone);
  return (
    <div className="phone-row">
      <Icon name="call" />
      <a href={`tel:${p}`} className="grow t-strong">{p}</a>
      <button
        className="btn text sm"
        onClick={async () => {
          await navigator.clipboard?.writeText(p).catch(() => undefined);
          toast('Đã sao chép số điện thoại');
        }}
      >
        Sao chép
      </button>
    </div>
  );
}

/** "từ 32 triệu" ở cuối dòng dự án / mẫu căn. Chưa có gói: mũi tên. */
export function FromPrice({ price }: { price?: number | null }) {
  if (price == null) return <Icon name="chevron_right" className="muted" />;
  return (
    <span className="from-price">
      <span className="muted xs">từ</span>
      <b>{vndShort(price)}</b>
    </span>
  );
}

/** Chọn nhiều giá trị trong danh sách cố định bằng chip (tỉnh / thành, hạng mục). */
export function ChipPicker({ label, options, selected, onChange }: {
  label: string; options: string[]; selected: string[]; onChange: (v: string[]) => void;
}) {
  return (
    <fieldset className="chip-picker">
      <legend>{label}</legend>
      <div className="chips">
        {options.map((o) => {
          const on = selected.includes(o);
          return (
            <button
              type="button"
              key={o}
              className={`chip${on ? ' on' : ''}`}
              aria-pressed={on}
              onClick={() => onChange(on ? selected.filter((x) => x !== o) : [...selected, o])}
            >
              {on && <Icon name="check" size={16} />}
              {o}
            </button>
          );
        })}
      </div>
    </fieldset>
  );
}

/** Nút chọn một trong vài giá trị (SegmentedButton). */
export function Segmented<T extends string | boolean>({ value, options, onChange }: {
  value: T; options: [T, string, string?][]; onChange: (v: T) => void;
}) {
  return (
    <div className="seg" role="radiogroup">
      {options.map(([v, label, icon]) => (
        <button
          type="button"
          key={String(v)}
          role="radio"
          aria-checked={v === value}
          className={v === value ? 'on' : ''}
          onClick={() => onChange(v)}
        >
          {v === value ? <Icon name="check" size={18} /> : icon && <Icon name={icon} size={18} />}
          {label}
        </button>
      ))}
    </div>
  );
}

/** Ô nhập có nhãn, gợi ý dưới ô. */
export function Field({ label, helper, error, suffix, children }: {
  label: string; helper?: ReactNode; error?: string | null; suffix?: string; children: ReactNode;
}) {
  return (
    <label className={`field${error ? ' has-error' : ''}`}>
      <span className="field-label">{label}</span>
      <span className="field-box">
        {children}
        {suffix && <span className="field-suffix">{suffix}</span>}
      </span>
      {(error || helper) && <small className={error ? 'error' : 'muted'}>{error ?? helper}</small>}
    </label>
  );
}

/** "Tên nhà thầu ✓ ★ 4.7" (✓ khi đã xác minh). */
export function ContractorLine({ c, className }: { c: Json; className?: string }) {
  return (
    <span className={`contractor-line ${className ?? 'muted small'}`}>
      {c.name}
      {c.status === 'verified' && <span title="Đã xác minh" className="verified"><Icon name="verified" fill size={16} /></span>}
      {c.rating != null && (
        <>
          <Icon name="star" fill className="star" />
          {c.rating}
        </>
      )}
    </span>
  );
}

/** Hộp thoại / bottom sheet (thẻ dialog gốc: có khoá focus, phím Esc, bấm nền để đóng). */
export function Sheet({ open, onClose, title, children, wide }: {
  open: boolean; onClose: () => void; title?: ReactNode; children: ReactNode; wide?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog
      ref={ref}
      className={`sheet${wide ? ' wide' : ''}`}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && onClose()}
    >
      {open && (
        <div className="sheet-body">
          <div className="sheet-handle" />
          {title && <h2 className="sheet-title">{title}</h2>}
          {children}
        </div>
      )}
    </dialog>
  );
}

/** Xem ảnh to. */
export function PhotoViewer({ url, onClose }: { url: string | null; onClose: () => void }) {
  return (
    <Sheet open={!!url} onClose={onClose} wide>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      {url && <img src={url} alt="" className="photo-full" />}
      <button className="btn outline" onClick={onClose}>Đóng</button>
    </Sheet>
  );
}

/** Lưới ảnh; bấm để xem to. [onRemove] có thì hiện nút xoá trên từng ảnh. */
export function PhotoGrid({ urls, onRemove, size = 88 }: { urls: string[]; onRemove?: (u: string) => void; size?: number }) {
  const [shown, setShown] = useState<string | null>(null);
  return (
    <div className="photo-grid">
      {urls.map((u) => (
        <span key={u} className="photo-cell" style={{ width: size, height: size }}>
          <button onClick={() => setShown(u)} aria-label="Xem ảnh">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={u} alt="" loading="lazy" />
          </button>
          {onRemove && (
            <button className="photo-remove" aria-label="Bỏ ảnh" onClick={() => onRemove(u)}>
              <Icon name="close" size={14} />
            </button>
          )}
        </span>
      ))}
      <PhotoViewer url={shown} onClose={() => setShown(null)} />
    </div>
  );
}

/** Ô chọn ảnh trong form: ảnh đã chọn + nút thêm. Ảnh được nén rồi upload ngay. */
export function PhotoPicker({ photos, onChange, max = 10 }: { photos: string[]; onChange: (p: string[]) => void; max?: number }) {
  const [busy, setBusy] = useState(false);
  const { toast } = useApp();
  const input = useRef<HTMLInputElement>(null);
  const add = async (files: FileList | null) => {
    if (!files?.length) return;
    setBusy(true);
    try {
      const added: string[] = [];
      for (const f of [...files].slice(0, max - photos.length)) added.push(await uploadPhoto(f));
      onChange([...photos, ...added]);
    } catch {
      toast('Không tải được ảnh, thử lại nhé');
    } finally {
      setBusy(false);
      if (input.current) input.current.value = '';
    }
  };
  return (
    <div className="stack-8">
      {photos.length > 0 && <PhotoGrid urls={photos} onRemove={(u) => onChange(photos.filter((x) => x !== u))} />}
      {photos.length < max && (
        <>
          <input ref={input} type="file" accept="image/*" multiple hidden onChange={(e) => add(e.target.files)} />
          <button type="button" className="btn outline" disabled={busy} onClick={() => input.current?.click()}>
            {busy ? <span className="spinner sm" /> : <Icon name="add_photo_alternate" />}
            {busy ? 'Đang tải ảnh...' : `Thêm ảnh (${photos.length}/${max})`}
          </button>
        </>
      )}
    </div>
  );
}

/** Thanh dính đáy màn hình (tổng giá + nút), như bottomSheet của Flutter. */
export const BottomBar = ({ children }: { children: ReactNode }) => <div className="bottom-bar"><div className="bottom-bar-inner">{children}</div></div>;

/** Nơi của yêu cầu: dự án · mẫu căn, hoặc địa chỉ + tỉnh / thành. */
export function requestPlace(r: Json, withArea = false): string {
  const unit = r.unit_type;
  if (unit) {
    const area = withArea && unit.area_m2 != null ? ` (${vnDecimal(unit.area_m2)} m²)` : '';
    return `${unit.project.name} · ${unit.name}${area}`;
  }
  return [r.address, r.province].filter((s) => typeof s === 'string' && s).join(', ');
}

/** "Cần làm: Tủ bếp, Sơn bả", rỗng khi chủ nhà không chọn hạng mục. */
export function servicesLine(r: Json, prefix = 'Cần làm'): string {
  const s: string[] = r.services ?? [];
  return s.length ? `${prefix}: ${s.join(', ')}` : '';
}
