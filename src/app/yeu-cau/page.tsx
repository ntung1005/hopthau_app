'use client';

// Tab Yêu cầu (chủ nhà): danh sách yêu cầu báo giá đã gửi.

import Link from 'next/link';
import { api, type Json } from '@/lib/api';
import { vndShort } from '@/lib/format';
import { loginHref, useApp, useLoad } from '@/ui/app';
import { EmptyState, Icon, IconBadge, Loaded, Pill, TopBar, requestPlace, servicesLine, statusOf } from '@/ui/kit';
import { jobStatus, requestStatus } from '@/ui/shared';

export default function MyRequestsPage() {
  const { me } = useApp();
  return (
    <>
      <TopBar title="Yêu cầu của tôi" back={false} />
      <main className="page tabbed">
        {me ? (
          <RequestList key={me.id} />
        ) : (
          <EmptyState
            icon="lock"
            title="Đăng nhập để xem yêu cầu"
            body="Báo giá của nhà thầu sẽ hiện ở đây."
            action={<Link className="btn" href={loginHref('/yeu-cau')}>Đăng nhập</Link>}
          />
        )}
      </main>
    </>
  );
}

function RequestList() {
  const state = useLoad<Json[]>(() => api.getAuth('/quote-requests'), []);
  return (
    <Loaded state={state}>
      {(rows) =>
        rows.length === 0 ? (
          <EmptyState
            icon="receipt_long"
            title="Chưa có yêu cầu nào"
            body="Chọn một gói ở mục Khám phá, hoặc bấm Xin báo giá để gửi yêu cầu theo địa chỉ."
            action={<Link className="btn outline" href="/yeu-cau/moi">Xin báo giá</Link>}
          />
        ) : (
          <div style={{ paddingTop: 8 }}>
            {rows.map((r) => {
              const [label, tone] = statusOf(requestStatus, r.status);
              const quoted = r.quotes.filter((q: Json) => q.price != null).length;
              const lines = [requestPlace(r), servicesLine(r), r.budget != null && `Ngân sách ${vndShort(r.budget)}`].filter(Boolean);
              return (
                <Link key={r.id} className="card row-card" href={`/yeu-cau/${r.id}`} style={{ alignItems: 'flex-start' }}>
                  <IconBadge icon="home_work" />
                  <span className="grow">
                    <span className="t-title">{r.package?.name ?? 'Yêu cầu báo giá'}</span>
                    <span className="muted pre" style={{ display: 'block', marginTop: 2 }}>{lines.join('\n')}</span>
                    <span className="row wrap gap-t8">
                      <Pill tone={tone}>{label}</Pill>
                      {r.job ? (
                        <Pill tone={statusOf(jobStatus, r.job.status)[1]}>{statusOf(jobStatus, r.job.status)[0]}</Pill>
                      ) : (
                        <Pill>{quoted === 0 ? 'Chưa có báo giá' : `${quoted} báo giá`}</Pill>
                      )}
                    </span>
                  </span>
                  <Icon name="chevron_right" className="muted" />
                </Link>
              );
            })}
          </div>
        )
      }
    </Loaded>
  );
}
