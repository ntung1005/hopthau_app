'use client';

// Chi tiết gói: ảnh, nhà thầu, hạng mục theo phòng, chọn hạng mục tuỳ chọn, tổng trọn gói, nhận tư vấn.

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api, type Json } from '@/lib/api';
import { vnd } from '@/lib/format';
import { packageTotal } from '@/lib/measure';
import { useGoAuthed, useLoad } from '@/ui/app';
import { BottomBar, ContractorLine, Icon, Loaded, Pill, SectionTitle, TopBar } from '@/ui/kit';

const itemLine = (i: Json) =>
  [i.material, i.size, `${i.qty} ${i.unit} × ${vnd(i.unit_price)}`].filter(Boolean).join(' · ');

export default function PackagePage() {
  const { id } = useParams<{ id: string }>();
  const state = useLoad<Json>(() => api.get(`/packages/${id}`), [id]);
  const [chosen, setChosen] = useState<Set<string>>(new Set());
  const goAuthed = useGoAuthed();

  return (
    <>
      <TopBar title={state.data?.name} />
      <main className="page has-bar">
        <Loaded state={state}>
          {(pkg) => {
            const items: Json[] = pkg.items;
            const rooms = new Map<string, Json[]>();
            for (const i of items) rooms.set(i.room, [...(rooms.get(i.room) ?? []), i]);
            const total = packageTotal(items, chosen);
            const requestQuote = () => {
              const options = items.filter((i) => chosen.has(i.id)).map((i) => i.name).join(', ');
              const q = new URLSearchParams({ unit: pkg.unit_type.id, package: pkg.id, title: pkg.name });
              if (options) q.set('note', `Thêm tuỳ chọn: ${options}`);
              goAuthed(`/yeu-cau/moi?${q}`);
            };
            return (
              <>
                {pkg.images.length > 0 && <Gallery urls={pkg.images} />}
                <div className="info" style={{ marginTop: 8 }}>
                  <span className="primary t-strong">{pkg.unit_type.project.name} · {pkg.unit_type.name}</span>
                  <Link href={`/nha-thau/${pkg.contractor.id}`} className="row primary" style={{ gap: 2, marginTop: 4 }}>
                    <ContractorLine c={pkg.contractor} className="t-title" />
                    <Icon name="chevron_right" />
                  </Link>
                  <span className="muted">
                    {pkg.style} · {pkg.duration_days} ngày thi công · bảo hành {pkg.warranty_months} tháng
                  </span>
                </div>
                {[...rooms].map(([room, list]) => (
                  <section key={room}>
                    <SectionTitle>{room}</SectionTitle>
                    {list.map((i) =>
                      i.is_optional ? (
                        <label key={i.id} className="check-row">
                          <input
                            type="checkbox"
                            checked={chosen.has(i.id)}
                            onChange={(e) => {
                              const next = new Set(chosen);
                              if (e.target.checked) next.add(i.id);
                              else next.delete(i.id);
                              setChosen(next);
                            }}
                          />
                          <span>
                            <span className="t-title" style={{ fontWeight: 500 }}>{i.name} (tuỳ chọn)</span>
                            <span className="muted">{itemLine(i)}</span>
                          </span>
                        </label>
                      ) : (
                        <div key={i.id} style={{ padding: '10px 4px' }}>
                          <span className="t-title" style={{ fontWeight: 500 }}>{i.name}</span>
                          <span className="muted">{itemLine(i)}</span>
                        </div>
                      ),
                    )}
                  </section>
                ))}
                <BottomBar>
                  <div className="row">
                    <span className="muted grow">Tổng trọn gói</span>
                    <span className="t-price">{vnd(total)}</span>
                  </div>
                  <button className="btn" onClick={requestQuote}>Nhận tư vấn gói này</button>
                </BottomBar>
              </>
            );
          }}
        </Loaded>
      </main>
    </>
  );
}

/** Ảnh gói, vuốt ngang (cuộn có điểm dừng). */
function Gallery({ urls }: { urls: string[] }) {
  const [page, setPage] = useState(0);
  return (
    <div style={{ position: 'relative', marginTop: 8, borderRadius: 16, overflow: 'hidden', aspectRatio: '4 / 3', background: 'var(--field)' }}>
      <div
        style={{ display: 'flex', overflowX: 'auto', scrollSnapType: 'x mandatory', height: '100%', scrollbarWidth: 'none' }}
        onScroll={(e) => setPage(Math.round(e.currentTarget.scrollLeft / e.currentTarget.clientWidth))}
      >
        {urls.map((u) => (
          // eslint-disable-next-line @next/next/no-img-element
          <img key={u} src={u} alt="" style={{ flex: '0 0 100%', height: '100%', objectFit: 'cover', scrollSnapAlign: 'start' }} />
        ))}
      </div>
      {urls.length > 1 && <span style={{ position: 'absolute', right: 12, bottom: 12 }}><Pill>{page + 1}/{urls.length}</Pill></span>}
    </div>
  );
}
