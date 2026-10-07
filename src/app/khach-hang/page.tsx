'use client';

// Khách hàng (tab đầu ở chế độ nhà thầu): dải trạng thái xác minh, tóm tắt (cần báo giá / đã báo / đã chọn bạn), danh sách.

import Link from 'next/link';
import { api, type Json } from '@/lib/api';
import { vnd } from '@/lib/format';
import { useAuthLoad } from '@/ui/app';
import { EmptyState, Icon, IconBadge, Loaded, Pill, TopBar, statusOf } from '@/ui/kit';
import { leadLines, leadStatus, VerifyBanner } from '@/ui/shared';

export default function LeadsPage() {
  const state = useAuthLoad(async () => {
    const [profile, rows] = await Promise.all([api.getAuth('/contractor'), api.getAuth('/contractor/leads')]);
    return { profile: profile as Json | null, rows: rows as Json[] };
  }, []);
  return (
    <>
      <TopBar title="Khách hàng" back={false} />
      <main className="page tabbed">
        <Loaded state={state}>
          {({ profile, rows }) => {
            if (!profile) {
              return (
                <EmptyState
                  icon="handyman"
                  title="Chưa có hồ sơ nhà thầu"
                  body="Đăng ký hồ sơ để nhận khách và đăng gói."
                  action={<Link className="btn" href="/tai-khoan/dang-ky-nha-thau">Đăng ký làm nhà thầu</Link>}
                />
              );
            }
            const count = (s: string) => rows.filter((l) => l.status === s).length;
            // Cần báo giá lên trước.
            const sorted = [...rows].sort((a, b) => (a.status === 'sent' ? 0 : 1) - (b.status === 'sent' ? 0 : 1));
            return (
              <>
                <VerifyBanner profile={profile} />
                <div className="card stats gap-t">
                  <div><b className="big" style={{ color: '#b07a00' }}>{count('sent')}</b><span className="muted xs">cần báo giá</span></div>
                  <div><b className="big">{count('quoted')}</b><span className="muted xs">đã báo giá</span></div>
                  <div><b className="big success">{count('accepted')}</b><span className="muted xs">chọn bạn</span></div>
                </div>
                {rows.length === 0 && (
                  <EmptyState
                    icon="inbox"
                    title="Chưa có khách"
                    body='Khi chủ nhà bấm "Nhận tư vấn" ở gói của bạn, hoặc gửi yêu cầu ở khu vực bạn phục vụ, khách sẽ hiện ở đây.'
                  />
                )}
                {sorted.map((lead) => {
                  const r = lead.request;
                  const [label, tone] = statusOf(leadStatus, lead.status);
                  const lines = [
                    ...leadLines(r),
                    lead.mode === 'offline' && lead.status !== 'sent' && 'Bạn đề nghị làm việc trực tiếp',
                    lead.price != null && `Bạn báo: ${vnd(lead.price)}`,
                  ].filter(Boolean);
                  return (
                    <Link key={r.id} className="card row-card" href={`/khach-hang/${r.id}`} style={{ alignItems: 'flex-start' }}>
                      <IconBadge icon="person" />
                      <span className="grow">
                        <span className="t-title">{lead.owner.full_name || 'Chủ nhà'}</span>
                        <span className="muted pre" style={{ display: 'block', marginTop: 2 }}>{lines.join('\n')}</span>
                        <span className="row gap-t8"><Pill tone={tone}>{label}</Pill></span>
                      </span>
                      <Icon name="chevron_right" className="muted" />
                    </Link>
                  );
                })}
              </>
            );
          }}
        </Loaded>
      </main>
    </>
  );
}
