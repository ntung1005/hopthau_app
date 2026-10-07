'use client';

// Chi tiết yêu cầu: các báo giá nhận được, chọn một nhà thầu.
// Số điện thoại nhà thầu chỉ hiện sau khi chọn (BE ẩn trước đó).

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api, type Json } from '@/lib/api';
import { vnd } from '@/lib/format';
import { askedItems, planFromJson, quoteDiff, type AskedItem, type QuoteLine } from '@/lib/measure';
import { useApp, useAuthLoad } from '@/ui/app';
import {
  ContractorLine, Icon, IconBadge, InfoPanel, Loaded, Pill, PhoneRow, RowCard, SectionTitle, TopBar, requestPlace, servicesLine,
  statusOf, type StatusMap,
} from '@/ui/kit';
import { requestStatus } from '@/ui/shared';

const quoteStatus: StatusMap = {
  sent: ['Chờ báo giá', 'muted'],
  quoted: ['Đã báo giá', 'primary'],
  offline: ['Muốn gặp trực tiếp', 'accent'],
  accepted: ['Bạn đã chọn', 'success'],
  declined: ['Không chọn', 'muted'],
};

export default function RequestDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { showError } = useApp();
  const [busy, setBusy] = useState(false);
  const state = useAuthLoad(async () => {
    const r: Json = await api.getAuth(`/quote-requests/${id}`);
    // Đồ đã chọn trong bản đo, để thấy nhà thầu thêm / bớt món nào.
    const mid = r.measurement?.id;
    const asked = mid ? askedItems(planFromJson((await api.getAuth(`/measurements/${mid}`)).data)) : [];
    return { r, asked };
  }, [id]);

  const accept = async (q: Json) => {
    const c = q.contractor;
    const detail = q.mode === 'offline'
      ? 'Làm việc trực tiếp: hai bên tự khảo sát và thoả thuận giá, app theo dõi tiến độ các mốc.'
      : `Báo giá ${vnd(q.price)}, ${q.duration_days} ngày thi công.`;
    if (!confirm(`Chọn ${c.name}?\n\n${detail} Hai bên sẽ thấy số điện thoại của nhau, các nhà thầu khác sẽ được báo là bạn không chọn.`)) return;
    setBusy(true);
    try {
      await api.postAuth(`/quote-requests/${id}/accept`, { contractor_id: c.id });
      state.reload();
    } catch (e) {
      showError(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <TopBar title="Yêu cầu báo giá" fallback="/yeu-cau" />
      <main className="page">
        <Loaded state={state}>
          {({ r, asked }) => {
            const [label, tone] = statusOf(requestStatus, r.status);
            const big = Number.MAX_SAFE_INTEGER;
            const quotes: Json[] = [...r.quotes].sort((a, b) => (a.price ?? big) - (b.price ?? big));
            const open = r.status === 'open';
            return (
              <>
                <InfoPanel>
                  <span className="t-title">{r.package?.name ?? 'Yêu cầu theo địa chỉ'}</span>
                  <span className="muted">{requestPlace(r)}</span>
                  {servicesLine(r) && <span className="muted">{servicesLine(r)}</span>}
                  {r.budget != null && <span className="muted">Ngân sách {vnd(r.budget)}</span>}
                  {r.note && <p className="pre gap-t8">{r.note}</p>}
                  <Pill tone={tone}>{label}</Pill>
                </InfoPanel>
                {r.measurement && (
                  <div className="gap-t">
                    <RowCard
                      icon="straighten"
                      title={`Bản đo đính kèm: ${r.measurement.name}`}
                      subtitle="Nhà thầu dùng để báo giá sơ bộ"
                      href={`/ban-do/${r.measurement.id}`}
                    />
                  </div>
                )}
                {r.job && (
                  <Link className="btn block gap-t" href={`/cong-trinh/${r.job.id}`}>
                    <Icon name="construction" /> Theo dõi công trình
                  </Link>
                )}
                <SectionTitle>{quotes.length === 0 ? 'Đang tìm nhà thầu' : `Báo giá (${quotes.length})`}</SectionTitle>
                {quotes.length === 0 && <p className="muted">Chúng tôi đang ghép nhà thầu phù hợp, thường trong 24 giờ.</p>}
                {quotes.map((q) => (
                  <QuoteCard key={q.contractor.id} quote={q} asked={asked} canAccept={open && !busy} onAccept={() => accept(q)} />
                ))}
              </>
            );
          }}
        </Loaded>
      </main>
    </>
  );
}

function QuoteCard({ quote: q, asked, canAccept, onAccept }: { quote: Json; asked: AskedItem[]; canAccept: boolean; onAccept: () => void }) {
  const c = q.contractor;
  const offline = q.mode === 'offline';
  const [label, tone] = statusOf(quoteStatus, offline && q.status === 'quoted' ? 'offline' : q.status);
  const items: AskedItem[] = q.items ?? [];
  const accepted = q.status === 'accepted';
  return (
    <div className={`card pad stack-8${accepted ? ' accepted' : ''}`}>
      <div className="row">
        <IconBadge icon="handyman" size={40} />
        <Link className="grow" href={`/nha-thau/${c.id}`}><ContractorLine c={c} className="t-title" /></Link>
        <Pill tone={tone}>{label}</Pill>
      </div>
      {q.price != null && (
        <div className="gap-t8">
          <div className="t-price">{vnd(q.price)}</div>
          <div className="muted">{q.duration_days} ngày thi công</div>
        </div>
      )}
      {offline && q.status !== 'sent' && (
        <p className="muted small">
          Nhà thầu muốn gặp để khảo sát và thoả thuận giá trực tiếp. Chọn thì hai bên thấy số điện thoại; app theo dõi tiến độ
          các mốc, không ghi nhận tiền.
        </p>
      )}
      {items.length > 0 && <QuoteItems lines={quoteDiff(asked, items)} />}
      {q.message && <p className="pre">{q.message}</p>}
      {accepted && c.phone && <PhoneRow phone={c.phone} />}
      {canAccept && q.status === 'quoted' && (
        <button className="btn gap-t8" onClick={onAccept}>{offline ? 'Chọn, làm việc trực tiếp' : 'Chọn nhà thầu này'}</button>
      )}
    </div>
  );
}

/** Báo giá theo món: thành tiền từng món; đánh dấu món nhà thầu thêm, đổi số lượng hoặc bỏ so với đồ bạn chọn. */
function QuoteItems({ lines }: { lines: QuoteLine[] }) {
  const changed = lines.filter((l) => l.tag).length;
  return (
    <details open={changed > 0}>
      <summary style={{ cursor: 'pointer', padding: '8px 0' }}>
        <span className="t-strong">Chi tiết {lines.filter((l) => l.tag !== 'removed').length} món</span>
        {changed > 0 && <span className="small" style={{ color: '#b07a00', marginLeft: 8 }}>{changed} thay đổi so với đồ bạn chọn</span>}
      </summary>
      {lines.map((l) => (
        <div key={`${l.room}|${l.name}`} className="row top" style={{ padding: '6px 0' }}>
          <div className="grow stack-8" style={{ gap: 2, alignItems: 'flex-start' }}>
            <span className={`t-strong${l.tag === 'removed' ? ' strike' : ''}`}>{l.name} × {l.qty}</span>
            <span className="muted xs">{[l.room, l.note].filter(Boolean).join(' · ')}</span>
            {l.tag === 'added' && <Pill tone="success">Nhà thầu đề xuất thêm</Pill>}
            {l.tag === 'changed' && <Pill tone="accent">Bạn chọn {l.askedQty}</Pill>}
            {l.tag === 'removed' && <Pill tone="error">Nhà thầu bỏ</Pill>}
          </div>
          {l.unitPrice != null && <span>{vnd(l.unitPrice * l.qty)}</span>}
        </div>
      ))}
    </details>
  );
}
