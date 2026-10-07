'use client';

// So sánh 2-3 gói cùng mẫu căn. Ô xanh là lựa chọn tốt nhất ở mỗi hàng.

import { useSearchParams } from 'next/navigation';
import { api, type Json } from '@/lib/api';
import { vndShort } from '@/lib/format';
import { useLoad } from '@/ui/app';
import { Loaded, TopBar } from '@/ui/kit';

/** Gói có giá trị tốt nhất theo [key]. Hoà nhau thì không tô ô nào. */
function best(packages: Json[], key: (p: Json) => number, lower = false): Json | null {
  const sorted = [...packages].sort((a, b) => (lower ? key(a) - key(b) : key(b) - key(a)));
  return sorted.length < 2 || key(sorted[0]) === key(sorted[1]) ? null : sorted[0];
}

export default function ComparePage() {
  const params = useSearchParams();
  const unit = params.get('unit');
  const ids = (params.get('ids') ?? '').split(',').filter(Boolean);
  const state = useLoad<Json[]>(
    async () => {
      const list: Json[] = await api.get(`/unit-types/${unit}/packages`);
      return ids.map((id) => list.find((p) => p.id === id)).filter((p): p is Json => !!p);
    },
    [unit, ids.join(',')],
  );

  const rating = (p: Json) => p.contractor.rating ?? 0;
  // Mỗi hàng: nhãn, giá trị hiển thị, và (tuỳ chọn) gói tốt nhất để tô màu.
  const rows = (ps: Json[]): [string, (p: Json) => string, Json | null][] => [
    ['Giá', (p) => vndShort(p.price), best(ps, (p) => p.price, true)],
    ['Phong cách', (p) => p.style, null],
    ['Thi công', (p) => `${p.duration_days} ngày`, best(ps, (p) => p.duration_days, true)],
    ['Bảo hành', (p) => `${p.warranty_months} tháng`, best(ps, (p) => p.warranty_months)],
    ['Nhà thầu', (p) => p.contractor.name, null],
    ['Đánh giá', (p) => `${p.contractor.rating ?? '-'}`, best(ps, rating)],
  ];

  return (
    <>
      <TopBar title="So sánh gói" />
      <main className="page">
        <p className="muted" style={{ margin: '8px 0 12px' }}>Ô xanh là lựa chọn tốt nhất ở mỗi hàng.</p>
        <Loaded state={state}>
          {(ps) => (
            <div className="table-wrap">
              <table className="tbl grid">
                <thead>
                  <tr>
                    <th />
                    {ps.map((p) => <th key={p.id}>{p.name}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {rows(ps).map(([label, value, top]) => (
                    <tr key={label}>
                      <th scope="row">{label}</th>
                      {ps.map((p) => <td key={p.id} className={top === p ? 'best' : undefined}>{value(p)}</td>)}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Loaded>
      </main>
    </>
  );
}
