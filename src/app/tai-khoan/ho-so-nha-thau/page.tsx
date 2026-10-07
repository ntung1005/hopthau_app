'use client';

// Sửa hồ sơ nhà thầu (từ tab Tài khoản ở chế độ nhà thầu).

import { useRouter } from 'next/navigation';
import { api, type Json } from '@/lib/api';
import { useAuthLoad } from '@/ui/app';
import { Loaded, TopBar } from '@/ui/kit';
import { ProfileForm, VerifyBanner } from '@/ui/shared';

export default function ContractorProfileEditPage() {
  const router = useRouter();
  const state = useAuthLoad<Json | null>(() => api.getAuth('/contractor'), []);
  return (
    <>
      <TopBar title="Hồ sơ nhà thầu" fallback="/tai-khoan" />
      <main className="page" style={{ maxWidth: 560 }}>
        <Loaded state={state}>
          {(profile) => (
            <div className="stack-16">
              {profile && <VerifyBanner profile={profile} />}
              <ProfileForm initial={profile} submitLabel="Lưu" onSaved={() => router.back()} />
            </div>
          )}
        </Loaded>
      </main>
    </>
  );
}
