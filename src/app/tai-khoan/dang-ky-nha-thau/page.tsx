'use client';

// Đăng ký làm nhà thầu. Đăng ký xong (hoặc tài khoản đã là nhà thầu) thì chuyển sang chế độ nhà thầu.

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { useApp, useRequireAuth } from '@/ui/app';
import { Illustration, TopBar } from '@/ui/kit';
import { ProfileForm } from '@/ui/shared';

export default function ContractorSignupPage() {
  const authed = useRequireAuth();
  const { isContractor, refresh, setMode } = useApp();
  const router = useRouter();

  // Vừa đăng nhập bằng tài khoản đã là nhà thầu: chuyển chế độ luôn, không đăng ký lại.
  useEffect(() => {
    if (isContractor) {
      setMode('contractor');
      router.replace('/khach-hang');
    }
  }, [isContractor, setMode, router]);

  if (!authed || isContractor) return null;
  return (
    <>
      <TopBar title="Đăng ký làm nhà thầu" />
      <main className="page" style={{ maxWidth: 560 }}>
        <div style={{ display: 'grid', placeItems: 'center' }}><Illustration icon="handyman" /></div>
        <h1 className="t-headline center" style={{ marginTop: 16 }}>Nhận khách đã tự đo nhà</h1>
        <p className="muted center pre" style={{ margin: '8px 0 24px' }}>
          Chủ nhà gửi bản đo, khu vực và hạng mục cần làm; bạn nhận yêu cầu đúng tỉnh và đúng việc mình làm, báo giá sơ bộ
          ngay trong app. Đội vận hành gọi xác minh giấy phép kinh doanh trước khi gửi khách. Miễn phí giai đoạn đầu.{'\n'}
          Đã gửi hồ sơ qua web? Đăng ký bằng đúng số điện thoại đó, hồ sơ tự gắn vào tài khoản.
        </p>
        <ProfileForm initial={null} submitLabel="Gửi đăng ký" onSaved={() => void refresh()} />
      </main>
    </>
  );
}
