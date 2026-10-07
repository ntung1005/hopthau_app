'use client';

// Trang chủ: lời chào, tìm dự án, lối tắt, banner tự đo nhà, dự án, gói nổi bật, căn đã làm thực tế, cam kết.

import Link from 'next/link';
import { useState } from 'react';
import { api, type Json } from '@/lib/api';
import { foldVietnamese, vnd, vnDate } from '@/lib/format';
import { planTemplates } from '@/lib/measure';
import { loginHref, useApp, useLoad } from '@/ui/app';
import { ContractorLine, FromPrice, Icon, IconBadge, Loaded, Pill } from '@/ui/kit';
import { PlanCanvas } from '@/ui/plan-canvas';
import { MeasureGuide } from '@/ui/shared';

const preview = Object.values(planTemplates)[0]();

const whyUs: [string, string, string][] = [
  ['verified_user', 'Nhà thầu đã xác minh', 'Kiểm tra giấy phép trước khi hiển thị'],
  ['receipt_long', 'Giá theo hạng mục', 'Vật liệu, số lượng, đơn giá rõ ràng'],
  ['photo_camera', 'Nghiệm thu bằng ảnh', '4 mốc, tiền đi theo tiến độ'],
  ['gpp_good', 'Không phát sinh ngầm', 'Thay đổi phải được bạn đồng ý'],
];

export default function HomePage() {
  const { session } = useApp();
  const [query, setQuery] = useState('');
  const [guide, setGuide] = useState(false);
  const state = useLoad(async () => {
    const [projects, featured, showcase] = await Promise.all([api.get('/projects'), api.get('/packages/featured'), api.get('/showcase')]);
    return { projects: projects as Json[], featured: featured as Json[], showcase: showcase as Json[] };
  }, []);

  const q = query.trim();
  /** So khớp không dấu: "song hong" tìm được "Sông Hồng". */
  const matches = (p: Json) => {
    if (!q) return true;
    const hay = foldVietnamese(`${p.name} ${p.address ?? ''} ${p.province}`);
    return foldVietnamese(q).split(' ').every((w) => hay.includes(w));
  };

  return (
    <main className="page tabbed flush">
      <header className="hero">
        <div className="hero-brand">
          <span className="hero-logo"><Icon name="chair" fill size={20} /></span>
          <span className="grow">Hợp Thầu</span>
          {session ? <Icon name="notifications" /> : <Link className="btn text sm" href={loginHref('/')}>Đăng nhập</Link>}
        </div>
        <p style={{ marginTop: 22, opacity: 0.75 }}>Kết nối chủ nhà với thầu nội thất</p>
        <h1 className="t-headline" style={{ marginTop: 4 }}>Thầu hợp căn, hợp giá, hợp ý</h1>
        <label className="hero-search">
          <Icon name="search" className="muted" />
          <input type="search" placeholder="Tìm dự án, quận, thành phố" value={query} onChange={(e) => setQuery(e.target.value)} />
        </label>
      </header>

      <div style={{ padding: '0 16px' }}>
        <nav className="quick" aria-label="Lối tắt">
          <Link href="/do-nha"><span className="tile"><Icon name="straighten" /></span>Tự đo nhà</Link>
          <Link href={session ? '/yeu-cau/moi' : loginHref('/yeu-cau/moi')}><span className="tile"><Icon name="request_quote" /></span>Xin báo giá</Link>
          <button onClick={() => setGuide(true)}><span className="tile"><Icon name="menu_book" /></span>Cách đo</button>
        </nav>

        {!q && (
          <Link className="banner" href="/do-nha">
            <span className="banner-text">
              <Pill tone="accent">Mới</Pill>
              <span className="t-title">Tự đo nhà, nhận báo giá sát hơn</span>
              <span className="muted small">Nhập số đo từng phòng, app dựng khung 3D và tính diện tích gửi nhà thầu.</span>
              <span className="row primary t-strong" style={{ gap: 4, marginTop: 4 }}>Bắt đầu đo <Icon name="arrow_forward" size={18} /></span>
            </span>
            <PlanCanvas plan={preview} threeD interactive={false} className="banner-art" height={150} />
          </Link>
        )}

        <Loaded state={state}>
          {({ projects, featured, showcase }) => {
            const shown = projects.filter(matches);
            return (
              <>
                <h2 className="section-title">{q ? `Kết quả tìm "${q}"` : 'Dự án đang có gói'}</h2>
                {shown.length === 0 && (
                  <p className="muted">Chưa có dự án này. Bấm nút giữa để tự đo nhà, hoặc Xin báo giá theo địa chỉ.</p>
                )}
                {shown.map((p) => (
                  <Link key={p.id} className="card row-card" href={`/du-an/${p.slug}`}>
                    <span className="badge" style={{ width: 56, height: 56, borderRadius: 14, background: 'linear-gradient(90deg,#e8ecff,#d7deff)' }}>
                      <Icon name="apartment" fill size={28} />
                    </span>
                    <span className="grow">
                      <span className="row" style={{ gap: 6 }}>
                        {p.is_social_housing && <Pill tone="primary">NOXH</Pill>}
                        <span className="muted xs">{p.unit_type_count} mẫu căn</span>
                      </span>
                      <span className="t-title">{p.name}</span>
                      <span className="muted small">
                        {p.address ?? p.province}
                        {p.handover_date ? ` · bàn giao ${vnDate(p.handover_date)}` : ''}
                      </span>
                    </span>
                    <FromPrice price={p.min_price} />
                  </Link>
                ))}

                {!q && featured.length > 0 && (
                  <>
                    <h2 className="section-title">Gói nổi bật</h2>
                    <div className="hscroll">
                      {featured.map((p) => (
                        <Link key={p.id} className="card" href={`/goi/${p.id}`} style={{ width: 220, margin: '0 0 4px' }}>
                          {p.images.length ? (
                            // eslint-disable-next-line @next/next/no-img-element
                            <img className="cover" src={p.images[0]} alt="" style={{ height: 120 }} />
                          ) : (
                            <span className="cover" style={{ height: 120 }}><Icon name="chair" size={40} /></span>
                          )}
                          <span style={{ display: 'block', padding: 12 }}>
                            <span className="t-title ellipsis">{p.name}</span>
                            <span className="muted xs ellipsis">{p.unit_type.project.name} · {p.unit_type.name}</span>
                            <span className="t-price" style={{ display: 'block', marginTop: 6, fontSize: 16 }}>{vnd(p.price)}</span>
                            <ContractorLine c={p.contractor} />
                          </span>
                        </Link>
                      ))}
                    </div>
                  </>
                )}

                {!q && showcase.length > 0 && (
                  <>
                    <h2 className="section-title">Căn đã làm thực tế</h2>
                    <div className="hscroll">
                      {showcase.map((s) => (
                        <Link key={s.job_id} className="showcase" href={`/nha-thau/${s.contractor.id}`}>
                          {/* eslint-disable-next-line @next/next/no-img-element */}
                          {s.photos.length > 0 && <img src={s.photos[0]} alt="" loading="lazy" />}
                          <Pill tone="success">Đã bàn giao</Pill>
                          <span className="showcase-text">
                            {s.unit_type && <b className="ellipsis">{s.unit_type.project.name} · {s.unit_type.name}</b>}
                            <ContractorLine c={s.contractor} className="xs" />
                          </span>
                        </Link>
                      ))}
                    </div>
                  </>
                )}
              </>
            );
          }}
        </Loaded>

        {!q && (
          <>
            <h2 className="section-title">Vì sao chọn Hợp Thầu</h2>
            <div className="why">
              {whyUs.map(([icon, title, body]) => (
                <div key={title}>
                  <IconBadge icon={icon} size={36} />
                  <span className="t-strong">{title}</span>
                  <span className="muted xs">{body}</span>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
      <MeasureGuide open={guide} onClose={() => setGuide(false)} />
    </main>
  );
}
