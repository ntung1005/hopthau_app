'use client';

// Xem bản đo (nhà thầu, hoặc chủ nhà xem lại): 2D / 3D, đồ khách muốn làm, bảng khối lượng từng phòng.

import { useParams } from 'next/navigation';
import { useState } from 'react';
import { api, type Json } from '@/lib/api';
import { m2 } from '@/lib/format';
import { itemCount, planFromJson } from '@/lib/measure';
import { useAuthLoad } from '@/ui/app';
import { Icon, InfoPanel, Loaded, PhotoViewer, SectionTitle, TopBar } from '@/ui/kit';
import { PlanCanvas, PlanSummary, ViewToggle } from '@/ui/plan-canvas';

export default function MeasurementViewerPage() {
  const { id } = useParams<{ id: string }>();
  const state = useAuthLoad<Json>(() => api.getAuth(`/measurements/${id}`), [id]);
  const [threeD, setThreeD] = useState(true);
  const [selected, setSelected] = useState<string | null>(null);
  const [drawing, setDrawing] = useState(false);
  return (
    <>
      <TopBar title="Bản đo của khách" />
      <main className="page">
        <Loaded state={state}>
          {(m) => {
            const plan = planFromJson(m.data);
            const summary = m.summary;
            return (
              <div className="stack-12">
                <InfoPanel>
                  <span className="t-title">{m.name}</span>
                  <span className="muted small">
                    {plan.drawing_url
                      ? 'Dựng tự động từ bản vẽ thiết kế của chủ nhà. Dùng để báo giá sơ bộ, đo lại tại nhà trước khi sản xuất.'
                      : 'Chủ nhà tự đo bằng thước. Dùng để báo giá sơ bộ, đo lại tại nhà trước khi sản xuất.'}
                  </span>
                  {plan.drawing_url && (
                    <button className="btn text" style={{ paddingLeft: 0 }} onClick={() => setDrawing(true)}>
                      <Icon name="image" /> Xem bản vẽ gốc
                    </button>
                  )}
                </InfoPanel>
                <ViewToggle threeD={threeD} onChange={setThreeD} />
                <PlanCanvas plan={plan} threeD={threeD} selectedId={selected} onSelect={setSelected} height={320} />
                <PlanSummary plan={plan} />
                {itemCount(plan) > 0 && (
                  <>
                    <SectionTitle>Đồ khách muốn làm</SectionTitle>
                    <div className="card pad stack-8">
                      {plan.rooms.filter((r) => r.items.length).map((r) => (
                        <div key={r.id}>
                          <div className="t-strong">{r.name}</div>
                          {r.items.map((i, k) => (
                            <div key={k} className="muted">• {i.name} × {i.qty}{i.note ? ` (${i.note})` : ''}</div>
                          ))}
                        </div>
                      ))}
                    </div>
                  </>
                )}
                <SectionTitle>Khối lượng từng phòng</SectionTitle>
                <div className="table-wrap">
                  <table className="tbl sm">
                    <thead>
                      <tr><th>Phòng</th><th>Kích thước</th><th>Sàn</th><th>Tường</th></tr>
                    </thead>
                    <tbody>
                      {(summary.rooms as Json[]).map((row, i) => {
                        const r = plan.rooms[i];
                        return (
                          <tr key={r.id} className={r.id === selected ? 'sel' : undefined} onClick={() => setSelected(r.id)}>
                            <td>{row.name}</td>
                            <td>{m2(r.w)} × {m2(r.l)} × {m2(r.h)}</td>
                            <td>{m2(row.floor_m2)} m²</td>
                            <td>{m2(row.wall_m2)} m²</td>
                          </tr>
                        );
                      })}
                      <tr>
                        <td className="t-strong">Tổng</td>
                        <td />
                        <td className="t-strong">{m2(summary.floor_m2)} m²</td>
                        <td className="t-strong">{m2(summary.wall_m2)} m²</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <p className="muted xs">Kích thước: rộng × dài × cao (m). Tường đã trừ diện tích cửa đi, cửa sổ.</p>
                <PhotoViewer url={drawing ? plan.drawing_url ?? null : null} onClose={() => setDrawing(false)} />
              </div>
            );
          }}
        </Loaded>
      </main>
    </>
  );
}
