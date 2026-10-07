'use client';

// Đo nhà: danh sách bản đo của tôi. Tạo mới từ mẫu căn, hoặc từ ảnh bản vẽ (BE gọi hopthau_ai nhận diện).
// ponytail: nhập số đo bằng tay; đo bằng camera (AR) để dành cho bản native.

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useRef, useState } from 'react';
import { api, uploadPhoto, type Json } from '@/lib/api';
import { m2, parseNum } from '@/lib/format';
import { planFloorArea, planFromJson, planTemplates, type Plan } from '@/lib/measure';
import { errorText, useApp, useAuthLoad } from '@/ui/app';
import { EmptyState, Field, Icon, IconBadge, Loaded, Sheet, TopBar } from '@/ui/kit';
import { PlanCanvas } from '@/ui/plan-canvas';
import { MeasureGuide } from '@/ui/shared';
import { putDraft } from './draft';

export default function MeasurementsPage() {
  const router = useRouter();
  const state = useAuthLoad<Json[]>(() => api.getAuth('/measurements'), []);
  const [guide, setGuide] = useState(false);
  const [creating, setCreating] = useState(false);
  const [drawing, setDrawing] = useState(false);

  const start = (plan: Plan, name: string) => {
    putDraft(plan, name);
    router.push('/do-nha/moi');
  };

  return (
    <>
      <TopBar
        title="Bản đo nhà"
        actions={<button className="icon-btn" title="Cách đo" aria-label="Cách đo" onClick={() => setGuide(true)}><Icon name="help" /></button>}
      />
      <main className="page" style={{ paddingBottom: 120 }}>
        <Loaded state={state}>
          {(rows) =>
            rows.length === 0 ? (
              <>
                <EmptyState
                  icon="straighten"
                  title="Tự đo nhà, nhận báo giá sát hơn"
                  body="Đo dài, rộng, cao từng phòng và vị trí cửa bằng thước. App dựng mặt bằng, khung 3D và tính diện tích để nhà thầu báo giá sơ bộ, đỡ phải đến khảo sát nhiều lần."
                />
                <div className="center"><button className="btn text" onClick={() => setGuide(true)}>Xem cách đo</button></div>
              </>
            ) : (
              <div style={{ paddingTop: 8 }}>
                {rows.map((m) => (
                  <Link key={m.id} className="card row" href={`/do-nha/${m.id}`} style={{ gap: 14 }}>
                    <PlanCanvas plan={planFromJson(m.data)} threeD interactive={false} className="thumb" />
                    <span className="grow" style={{ padding: '10px 0' }}>
                      <span className="t-title">{m.name}</span>
                      <span className="muted pre">
                        {m.data.rooms.length} phòng · sàn {m2(m.summary.floor_m2)} m²
                        {m.unit_type ? `\n${m.unit_type.project.name} · ${m.unit_type.name}` : ''}
                      </span>
                    </span>
                    <Icon name="chevron_right" className="muted" />
                    <span style={{ width: 8 }} />
                  </Link>
                ))}
              </div>
            )
          }
        </Loaded>
        <div style={{ position: 'fixed', left: 0, right: 0, bottom: 24, display: 'flex', justifyContent: 'center', padding: '0 16px', zIndex: 20 }}>
          <button className="btn" style={{ boxShadow: '0 4px 12px rgb(48 79 254 / .35)' }} onClick={() => setCreating(true)}>
            <Icon name="straighten" /> Đo nhà mới
          </button>
        </div>
      </main>

      <Sheet open={creating} onClose={() => setCreating(false)}>
        <button className="list-line" onClick={() => { setCreating(false); setDrawing(true); }}>
          <IconBadge icon="architecture" size={40} />
          <span className="grow">
            <span className="t-title" style={{ fontWeight: 500 }}>Từ bản vẽ thiết kế</span>
            <span className="muted">Tải ảnh mặt bằng, app dựng lại 2D / 3D để bạn soát và sửa</span>
          </span>
        </button>
        <hr className="divider" style={{ margin: '4px 0' }} />
        <h2 className="sheet-title">Bắt đầu từ mẫu</h2>
        <p className="muted">Chọn mẫu gần giống nhà bạn, rồi sửa lại theo số đo thật.</p>
        {Object.entries(planTemplates).map(([name, make]) => (
          <button key={name} className="list-line" onClick={() => start(make(), 'Nhà của tôi')}>
            <IconBadge icon="grid_view" size={40} />
            <span className="t-title grow" style={{ fontWeight: 500 }}>{name}</span>
          </button>
        ))}
      </Sheet>

      <DrawingFlow open={drawing} onClose={() => setDrawing(false)} onPlan={(p) => start(p, 'Nhà theo bản vẽ')} />
      <MeasureGuide open={guide} onClose={() => setGuide(false)} />
    </>
  );
}

/** Chọn ảnh bản vẽ, upload, để BE nhận diện thành bản đo nháp; chủ nhà xem kết quả rồi mở trình sửa. */
function DrawingFlow({ open, onClose, onPlan }: { open: boolean; onClose: () => void; onPlan: (p: Plan) => void }) {
  const [area, setArea] = useState('');
  const [step, setStep] = useState<'ask' | 'busy' | { plan: Plan; notes: string }>('ask');
  const [error, setError] = useState<string | null>(null);
  const file = useRef<HTMLInputElement>(null);
  const { me } = useApp();

  const close = () => {
    setStep('ask');
    setError(null);
    onClose();
  };

  const read = async (f: File | undefined) => {
    if (!f || !me) return;
    // Bản vẽ thường không ghi tỉ lệ: diện tích sàn (sổ hồng, hợp đồng) giúp quy đổi kích thước chính xác.
    const a = parseNum(area);
    setStep('busy');
    setError(null);
    try {
      // Giữ độ phân giải đủ thấy nét tường, cửa trên bản vẽ.
      const url = await uploadPhoto(f, 2400, 0.9);
      const res = await api.postAuth('/measurements/from-drawing', { image_url: url, ...(a != null && a > 0 && { area_m2: a }) });
      setStep({ plan: planFromJson(res.data), notes: res.notes ?? '' });
    } catch (e) {
      setError(errorText(e));
      setStep('ask');
    } finally {
      if (file.current) file.current.value = '';
    }
  };

  return (
    <Sheet open={open} onClose={step === 'busy' ? () => {} : close}>
      {step === 'ask' && (
        <>
          <h2 className="sheet-title">Dựng từ bản vẽ</h2>
          <p className="muted">Chọn ảnh mặt bằng nhìn từ trên xuống, chụp thẳng hoặc ảnh chụp màn hình file thiết kế.</p>
          <Field label="Diện tích sàn (m², không bắt buộc)" helper="Ghi trên hợp đồng / sổ hồng, giúp kích thước chính xác hơn" suffix="m²">
            <input inputMode="decimal" value={area} onChange={(e) => setArea(e.target.value)} />
          </Field>
          {error && <p className="error">{error}</p>}
          <input ref={file} type="file" accept="image/*" hidden onChange={(e) => read(e.target.files?.[0])} />
          <div className="btn-row">
            <button className="btn outline" onClick={close}>Huỷ</button>
            <button className="btn" onClick={() => file.current?.click()}>Chọn ảnh</button>
          </div>
        </>
      )}
      {step === 'busy' && (
        <div className="row" style={{ padding: '24px 0' }}>
          <div className="spinner" />
          <span className="grow">Đang nhận diện phòng, cửa và dựng lại mặt bằng...</span>
        </div>
      )}
      {typeof step === 'object' && (
        <>
          <h2 className="sheet-title">Đã dựng {step.plan.rooms.length} phòng · {m2(planFloorArea(step.plan))} m²</h2>
          <p className="pre">
            {`${step.notes}\n\nĐây là bản dựng tự động: đối chiếu với bản vẽ gốc (nút ảnh trên thanh tiêu đề), sửa lại kích thước nếu lệch rồi lưu.`.trim()}
          </p>
          <div className="btn-row">
            <button className="btn outline" onClick={close}>Huỷ</button>
            <button className="btn" onClick={() => { const p = step.plan; close(); onPlan(p); }}>Xem 2D / 3D</button>
          </div>
        </>
      )}
    </Sheet>
  );
}
