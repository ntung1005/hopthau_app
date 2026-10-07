'use client';

// Dự án → chọn mẫu căn.

import { useParams } from 'next/navigation';
import { api, type Json } from '@/lib/api';
import { vnDecimal } from '@/lib/format';
import { useLoad } from '@/ui/app';
import { FromPrice, Loaded, RowCard, SectionTitle, TopBar } from '@/ui/kit';

export default function ProjectPage() {
  const { slug } = useParams<{ slug: string }>();
  const state = useLoad<Json>(() => api.get(`/projects/${slug}`), [slug]);
  return (
    <>
      <TopBar title={state.data?.name} />
      <main className="page">
        <Loaded state={state}>
          {(project) => (
            <>
              <SectionTitle>Chọn mẫu căn của bạn</SectionTitle>
              {project.unit_types.map((u: Json) => (
                <RowCard
                  key={u.id}
                  icon="space_dashboard"
                  title={u.name}
                  subtitle={`${vnDecimal(u.area_m2)} m² · ${u.bedrooms} phòng ngủ · ${u.bathrooms} WC`}
                  trailing={<FromPrice price={u.min_price} />}
                  href={`/du-an/${slug}/${u.id}`}
                />
              ))}
            </>
          )}
        </Loaded>
      </main>
    </>
  );
}
