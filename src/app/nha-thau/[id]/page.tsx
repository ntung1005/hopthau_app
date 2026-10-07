'use client';

// Hồ sơ nhà thầu công khai: điểm, số công trình đã bàn giao, gói đang bán, đánh giá (chỉ từ công trình đã xong).

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { api, type Json } from '@/lib/api';
import { vnDecimal, vndShort } from '@/lib/format';
import { useLoad } from '@/ui/app';
import { ContractorLine, IconBadge, InfoPanel, Loaded, Pill, SectionTitle, TopBar, servicesLine } from '@/ui/kit';
import { ReviewCard } from '@/ui/shared';

export default function ContractorProfilePage() {
  const { id } = useParams<{ id: string }>();
  const state = useLoad<Json>(() => api.get(`/contractors/${id}`), [id]);
  return (
    <>
      <TopBar title="Nhà thầu" />
      <main className="page">
        <Loaded state={state}>
          {(c) => {
            const facts = [c.years_experience != null && `${c.years_experience} năm kinh nghiệm`, servicesLine(c, 'Nhận làm')]
              .filter(Boolean).join(' · ');
            return (
              <>
                <InfoPanel>
                  <ContractorLine c={c} className="t-large" />
                  {c.address && <span className="muted">{c.address}</span>}
                  <div className="row wrap gap-t8">
                    <Pill tone="primary">Đã xác minh</Pill>
                    {c.styles.map((s: string) => <Pill key={`s${s}`}>{s}</Pill>)}
                    {c.areas.map((a: string) => <Pill key={`a${a}`}>{a}</Pill>)}
                  </div>
                  {facts && <span className="muted gap-t8">{facts}</span>}
                </InfoPanel>
                <div className="card stats" style={{ marginTop: 12, padding: '16px 0' }}>
                  <div><b>{c.rating == null ? '-' : vnDecimal(c.rating)}</b><span className="muted xs">điểm</span></div>
                  <div><b>{c.review_count}</b><span className="muted xs">đánh giá</span></div>
                  <div><b>{c.completed_jobs}</b><span className="muted xs">căn đã bàn giao</span></div>
                </div>
                {c.bio && (
                  <>
                    <SectionTitle>Giới thiệu</SectionTitle>
                    <p className="pre" style={{ padding: '0 4px' }}>{c.bio}</p>
                  </>
                )}
                <SectionTitle>Gói đang bán ({c.packages.length})</SectionTitle>
                {c.packages.map((p: Json) => (
                  <Link key={p.id} className="card row-card" href={`/goi/${p.id}`}>
                    <IconBadge icon="chair" size={40} />
                    <span className="grow">
                      <span className="t-title" style={{ fontWeight: 500 }}>{p.name}</span>
                      <span className="muted">{p.unit_type.project.name} · {p.unit_type.name}</span>
                    </span>
                    <b className="primary">{vndShort(p.price)}</b>
                  </Link>
                ))}
                <SectionTitle>Đánh giá ({c.reviews.length})</SectionTitle>
                {c.reviews.length === 0 && (
                  <p className="muted">Chưa có đánh giá. Đánh giá chỉ đến từ công trình đã bàn giao qua Hợp Thầu.</p>
                )}
                {c.reviews.map((r: Json) => <ReviewCard key={r.job_id} review={r} />)}
              </>
            );
          }}
        </Loaded>
      </main>
    </>
  );
}
