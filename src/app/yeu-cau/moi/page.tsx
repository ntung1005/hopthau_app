'use client';

// Gửi yêu cầu báo giá. Có ?package khi đi từ một gói; không có ?unit thì là yêu cầu tự do theo địa chỉ
// (nhà không thuộc dự án có sẵn). ?measurement đính kèm sẵn bản đo.

import { useRouter, useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { api, meta } from '@/lib/api';
import { errorMessage } from '@/lib/format';
import { useApp, useAuthLoad } from '@/ui/app';
import { ChipPicker, Field, Illustration, Loaded, TopBar } from '@/ui/kit';
import { MeasurementPicker } from '@/ui/shared';

export default function QuoteRequestPage() {
  const params = useSearchParams();
  const router = useRouter();
  const { showError, toast } = useApp();
  const unitTypeId = params.get('unit');
  const packageId = params.get('package');
  const freeForm = !unitTypeId;
  const metaState = useAuthLoad(meta, []);
  const [note, setNote] = useState(params.get('note') ?? '');
  const [budget, setBudget] = useState('');
  const [address, setAddress] = useState('');
  const [province, setProvince] = useState('');
  const [services, setServices] = useState<string[]>([]);
  const [measurementId, setMeasurementId] = useState<string | null>(params.get('measurement'));
  const [busy, setBusy] = useState(false);
  const [matched, setMatched] = useState<number | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    // Mẫu căn đã biết tỉnh của dự án; yêu cầu tự do cần tỉnh để ghép nhà thầu cùng khu vực.
    if (freeForm && !province) return toast(errorMessage('missing_province'));
    setBusy(true);
    const millions = parseInt(budget.trim(), 10);
    try {
      const sent = await api.postAuth('/quote-requests', {
        ...(unitTypeId && { unit_type_id: unitTypeId }),
        ...(packageId && { package_id: packageId }),
        ...(freeForm && { province }),
        ...(freeForm && address.trim() && { address: address.trim() }),
        services,
        ...(!Number.isNaN(millions) && { budget: millions * 1000000 }),
        ...(measurementId && { measurement_id: measurementId }),
        note,
      });
      setMatched(sent.quotes.length);
    } catch (err) {
      showError(err);
    } finally {
      setBusy(false);
    }
  };

  if (matched != null) {
    return (
      <main className="page center-screen" style={{ maxWidth: 480 }}>
        <div className="stack-16" style={{ alignItems: 'center', textAlign: 'center' }}>
          <Illustration icon="mark_email_read" />
          <h1 className="t-display">Đã gửi yêu cầu</h1>
          <p className="muted">
            {matched > 0
              ? `Đã gửi tới ${matched} nhà thầu phù hợp. Họ xem bản đo và báo giá, thường trong 24 giờ. Theo dõi ở mục Yêu cầu.`
              : 'Chưa có nhà thầu đã xác minh khớp khu vực của bạn. Đội vận hành sẽ tìm và ghép trong 24 giờ. Theo dõi ở mục Yêu cầu.'}
          </p>
          <button className="btn block" onClick={() => router.replace('/yeu-cau')}>Xong</button>
        </div>
      </main>
    );
  }

  return (
    <>
      <TopBar title={params.get('title') ?? 'Yêu cầu báo giá'} />
      <main className="page" style={{ maxWidth: 560 }}>
        <Loaded state={metaState}>
          {(m) => (
            <form className="form" onSubmit={submit} style={{ paddingTop: 8 }}>
              <p className="muted">
                {freeForm
                  ? 'Chọn khu vực và việc cần làm, chúng tôi gửi tới tối đa 5 nhà thầu đã xác minh phù hợp.'
                  : 'Nhà thầu sẽ liên hệ để khảo sát và chốt báo giá cho căn của bạn.'}
              </p>
              {freeForm && (
                <>
                  <Field label="Tỉnh / thành phố">
                    <select value={province} onChange={(e) => setProvince(e.target.value)}>
                      <option value="" disabled>Chọn tỉnh / thành phố</option>
                      {m.provinces.map((p: string) => <option key={p}>{p}</option>)}
                    </select>
                  </Field>
                  <Field label="Địa chỉ" helper="Không bắt buộc, chỉ gửi cho nhà thầu được ghép">
                    <input placeholder="Phường / xã, toà nhà" maxLength={300} value={address} onChange={(e) => setAddress(e.target.value)} />
                  </Field>
                </>
              )}
              <ChipPicker label="Cần làm những gì?" options={m.services} selected={services} onChange={setServices} />
              <Field label="Ngân sách (triệu đồng)" helper="Không bắt buộc">
                <input inputMode="numeric" value={budget} onChange={(e) => setBudget(e.target.value)} />
              </Field>
              <MeasurementPicker value={measurementId} onChange={setMeasurementId} />
              <Field label="Ghi chú">
                <textarea
                  rows={4}
                  maxLength={2000}
                  placeholder="Ngày nhận nhà, số phòng cần làm, phong cách..."
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
              </Field>
              <button className="btn" disabled={busy}>Gửi yêu cầu</button>
            </form>
          )}
        </Loaded>
      </main>
    </>
  );
}
