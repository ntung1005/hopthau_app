'use client';

// Mẫu căn → danh sách gói (chọn 2-3 gói để so sánh), "Căn đã làm thực tế" cùng mẫu căn.

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api, type Json } from '@/lib/api';
import { vnd } from '@/lib/format';
import { useLoad } from '@/ui/app';
import { ContractorLine, Icon, IconBadge, Loaded, Pill, PhotoGrid, Sheet, TopBar } from '@/ui/kit';

const MAX_COMPARE = 3;

export default function PackagesPage() {
  const { slug, unitId } = useParams<{ slug: string; unitId: string }>();
  const [picked, setPicked] = useState<string[]>([]);
  const state = useLoad(async () => {
    const [project, packages] = await Promise.all([api.get(`/projects/${slug}`), api.get(`/unit-types/${unitId}/packages`)]);
    return { unit: (project.unit_types as Json[]).find((u) => u.id === unitId), packages: packages as Json[] };
  }, [slug, unitId]);

  const toggle = (id: string) =>
    setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : p.length < MAX_COMPARE ? [...p, id] : p));

  return (
    <>
      <TopBar title={state.data?.unit ? `Gói cho ${state.data.unit.name}` : ''} fallback={`/du-an/${slug}`} />
      <main className="page" style={{ paddingBottom: 96 }}>
        <Loaded state={state}>
          {({ packages }) =>
            packages.length === 0 ? (
              <p className="muted center" style={{ padding: 48 }}>Chưa có gói cho mẫu căn này</p>
            ) : (
              <>
                <Showcase unitTypeId={unitId} />
                <p className="muted" style={{ padding: '8px 4px' }}>Chọn 2-3 gói để so sánh</p>
                {packages.map((p) => {
                  const on = picked.includes(p.id);
                  return (
                    <div key={p.id} className={`card row top${on ? ' picked' : ''}`} style={{ padding: '16px 8px 16px 16px' }}>
                      <Link href={`/goi/${p.id}`} className="row top grow" style={{ gap: 14 }}>
                        {p.images?.length ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={p.images[0]} alt="" style={{ width: 72, height: 72, objectFit: 'cover', borderRadius: 12, flex: 'none' }} />
                        ) : (
                          <IconBadge icon="chair" />
                        )}
                        <span className="grow stack-8" style={{ gap: 4 }}>
                          <span className="t-title">{p.name}</span>
                          <span className="t-price">{vnd(p.price)}</span>
                          <span className="row wrap">
                            <Pill>{p.style}</Pill>
                            <Pill>{p.duration_days} ngày</Pill>
                            <Pill>BH {p.warranty_months} tháng</Pill>
                          </span>
                          <ContractorLine c={p.contractor} />
                        </span>
                      </Link>
                      <label className="icon-btn" title="Chọn để so sánh">
                        <input
                          type="checkbox"
                          checked={on}
                          disabled={!on && picked.length >= MAX_COMPARE}
                          onChange={() => toggle(p.id)}
                          style={{ width: 20, height: 20, accentColor: 'var(--primary)' }}
                          aria-label={`So sánh ${p.name}`}
                        />
                      </label>
                    </div>
                  );
                })}
              </>
            )
          }
        </Loaded>
        {picked.length >= 2 && (
          <Link
            href={`/so-sanh?unit=${unitId}&ids=${picked.join(',')}`}
            className="btn"
            style={{ position: 'fixed', right: 16, bottom: 24, zIndex: 30, boxShadow: '0 4px 12px rgb(48 79 254 / .35)', borderRadius: 16 }}
          >
            <Icon name="compare_arrows" /> So sánh ({picked.length})
          </Link>
        )}
      </main>
    </>
  );
}

/** "Căn đã làm thực tế": ảnh từ công trình đã bàn giao cùng mẫu căn. Không có thì không hiện. */
function Showcase({ unitTypeId }: { unitTypeId: string }) {
  const state = useLoad<Json[]>(() => api.get(`/unit-types/${unitTypeId}/showcase`), [unitTypeId]);
  const [open, setOpen] = useState<Json | null>(null);
  const items = state.data ?? [];
  if (!items.length) return null;
  return (
    <>
      <h2 className="section-title" style={{ paddingTop: 8 }}>Căn đã làm thực tế ({items.length})</h2>
      <div className="hscroll">
        {items.map((it) => (
          <button key={it.job_id} className="card" style={{ width: 220, margin: 0 }} onClick={() => setOpen(it)}>
            {it.photos.length ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img className="cover" src={it.photos[0]} alt="" style={{ height: 140 }} loading="lazy" />
            ) : (
              <span className="cover" style={{ height: 140 }}><Icon name="home" /></span>
            )}
            <span style={{ display: 'block', padding: 10 }}><ContractorLine c={it.contractor} /></span>
          </button>
        ))}
      </div>
      <Sheet open={!!open} onClose={() => setOpen(null)} title={open && <ContractorLine c={open.contractor} className="t-title" />}>
        {open?.review?.content && <p>&ldquo;{open.review.content}&rdquo;</p>}
        {open && <PhotoGrid urls={open.photos} size={110} />}
        {open && <Link className="btn outline" href={`/nha-thau/${open.contractor.id}`}>Xem hồ sơ nhà thầu</Link>}
      </Sheet>
    </>
  );
}
