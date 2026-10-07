'use client';

// Gói của tôi (chế độ nhà thầu). Tạo gói bằng nút giữa thanh điều hướng.

import Link from 'next/link';
import { api, type Json } from '@/lib/api';
import { vnd } from '@/lib/format';
import { useAuthLoad } from '@/ui/app';
import { EmptyState, Icon, Loaded, RowCard, TopBar, statusOf } from '@/ui/kit';
import { packageStatus } from '@/ui/shared';

export default function MyPackagesPage() {
  const state = useAuthLoad<Json[]>(() => api.getAuth('/contractor/packages'), []);
  return (
    <>
      <TopBar title="Gói của tôi" back={false} />
      <main className="page tabbed">
        <Loaded state={state}>
          {(rows) =>
            rows.length === 0 ? (
              <EmptyState
                icon="chair"
                title="Chưa có gói nào"
                body="Tạo gói cho một mẫu căn: liệt kê hạng mục, vật liệu, đơn giá. Giá gói tự cộng từ hạng mục."
                action={<Link className="btn" href="/goi-cua-toi/moi"><Icon name="add" /> Tạo gói đầu tiên</Link>}
              />
            ) : (
              <>
                <p className="muted small" style={{ padding: '0 4px 8px' }}>
                  Bấm nút + ở giữa để tạo gói mới. Sửa gói đang hiển thị thì gói chờ duyệt lại.
                </p>
                {rows.map((p) => {
                  const [label, tone] = statusOf(packageStatus, p.status);
                  return (
                    <RowCard
                      key={p.id}
                      icon="chair"
                      title={p.name}
                      subtitle={`${p.unit_type.project.name} · ${p.unit_type.name}\n${vnd(p.price)} · ${label}`}
                      trailing={<span className={`dot tone-${tone}`} />}
                      href={`/goi-cua-toi/${p.id}`}
                    />
                  );
                })}
              </>
            )
          }
        </Loaded>
      </main>
    </>
  );
}
