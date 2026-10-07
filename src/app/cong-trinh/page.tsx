'use client';

// Tab Công trình. Tài khoản vừa là chủ nhà vừa là nhà thầu chỉ thấy công trình của chế độ đang dùng.

import Link from 'next/link';
import { api, type Json } from '@/lib/api';
import { vnd } from '@/lib/format';
import { loginHref, useApp, useLoad } from '@/ui/app';
import { EmptyState, IconBadge, Loaded, Pill, TopBar, statusOf } from '@/ui/kit';
import { jobPlace, jobStatus } from '@/ui/shared';

export default function JobsPage() {
  const { me, mode } = useApp();
  return (
    <>
      <TopBar title="Công trình" back={false} />
      <main className="page tabbed">
        {me ? (
          <JobsList key={`${me.id}-${mode}`} role={mode} />
        ) : (
          <EmptyState
            icon="construction"
            title="Theo dõi thi công ngay trên điện thoại"
            body="Sau khi chọn nhà thầu, bạn nghiệm thu từng mốc bằng ảnh và duyệt mọi phát sinh tại đây."
            action={<Link className="btn" href={loginHref('/cong-trinh')}>Đăng nhập</Link>}
          />
        )}
      </main>
    </>
  );
}

function JobsList({ role }: { role: string }) {
  const state = useLoad<Json[]>(async () => ((await api.getAuth('/jobs')) as Json[]).filter((j) => j.role === role), [role]);
  return (
    <Loaded state={state}>
      {(rows) =>
        rows.length === 0 ? (
          <EmptyState
            icon="construction"
            title="Chưa có công trình"
            body={role === 'owner'
              ? 'Chọn một báo giá ở tab Yêu cầu để bắt đầu công trình. Bạn sẽ nghiệm thu từng mốc bằng ảnh tại đây.'
              : 'Công trình hiện ở đây khi chủ nhà chọn báo giá của bạn.'}
          />
        ) : (
          <div style={{ paddingTop: 8 }}>
            {rows.map((j) => {
              const [label, tone] = statusOf(jobStatus, j.status);
              const other = j.role === 'owner' ? j.contractor.name : j.owner.full_name;
              const { done, total } = j.progress;
              return (
                <Link key={j.id} className="card pad stack-12" href={`/cong-trinh/${j.id}`}>
                  <span className="row">
                    <IconBadge icon="construction" size={40} />
                    <span className="grow">
                      <span className="t-title">{jobPlace(j)}</span>
                      <span className="muted">{other} · {j.offline ? 'Làm việc trực tiếp' : vnd(j.total)}</span>
                    </span>
                    <Pill tone={tone}>{label}</Pill>
                  </span>
                  <span className="row">
                    <span className="progress grow"><span style={{ width: `${total ? (done / total) * 100 : 0}%` }} /></span>
                    <span className="muted small">{done}/{total} mốc</span>
                  </span>
                </Link>
              );
            })}
          </div>
        )
      }
    </Loaded>
  );
}
