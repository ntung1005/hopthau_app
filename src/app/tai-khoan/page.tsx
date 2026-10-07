'use client';

// Tab Tài khoản: tên, số điện thoại, chế độ sử dụng, lối vào hồ sơ nhà thầu / bản đo, đăng xuất.

import { useRouter } from 'next/navigation';
import { api } from '@/lib/api';
import { localPhone } from '@/lib/format';
import { loginHref, useApp, type Mode } from '@/ui/app';
import { EmptyState, Pill, RowCard, Segmented, TopBar } from '@/ui/kit';
import { homeOf } from '@/ui/shell';

export default function AccountPage() {
  const { me, mode, isContractor, setMode, refresh, showError } = useApp();
  const router = useRouter();

  if (!me) {
    return (
      <>
        <TopBar title="Tài khoản" back={false} />
        <main className="page tabbed">
          <EmptyState
            icon="person"
            title="Bạn chưa đăng nhập"
            body="Đăng nhập bằng số điện thoại để gửi yêu cầu, nhận báo giá và theo dõi công trình."
            action={<button className="btn" onClick={() => router.push(loginHref('/tai-khoan'))}>Đăng nhập</button>}
          />
          <RowCard
            icon="handyman"
            title="Bạn là nhà thầu, xưởng nội thất?"
            subtitle="Đăng nhập rồi đăng ký hồ sơ để đăng gói, nhận khách"
            href={loginHref('/tai-khoan/dang-ky-nha-thau')}
          />
        </main>
      </>
    );
  }

  const name: string = me.full_name ?? '';
  const contractorMode = mode === 'contractor';

  const switchMode = (m: Mode) => {
    setMode(m);
    router.push(homeOf(m));
  };

  const editName = async () => {
    const v = prompt('Họ tên', name);
    if (v == null) return;
    try {
      await api.patchAuth('/me', { full_name: v });
      await refresh();
    } catch (e) {
      showError(e);
    }
  };

  const publicProfile = async () => {
    try {
      const c = await api.getAuth('/contractor');
      if (c) router.push(`/nha-thau/${c.id}`);
    } catch (e) {
      showError(e);
    }
  };

  return (
    <>
      <TopBar title="Tài khoản" back={false} />
      <main className="page tabbed">
        <div className="card pad row">
          <span className="badge" style={{ width: 56, height: 56, fontSize: 22, fontWeight: 700 }}>
            {name.trim() ? [...name.trim().split(' ').pop()!][0].toUpperCase() : '?'}
          </span>
          <span className="grow">
            <span className="t-title">{name || 'Chưa đặt tên'}</span>
            <span className="muted">{localPhone(me.phone)}</span>
          </span>
          <Pill tone={contractorMode ? 'accent' : 'primary'}>{contractorMode ? 'Nhà thầu' : 'Chủ nhà'}</Pill>
        </div>

        {isContractor && (
          <>
            <h2 className="section-title">Chế độ sử dụng</h2>
            <Segmented<Mode>
              value={mode}
              onChange={switchMode}
              options={[['owner', 'Chủ nhà', 'home'], ['contractor', 'Nhà thầu', 'handyman']]}
            />
            <p className="muted xs gap-t8" style={{ padding: '0 4px' }}>
              Chủ nhà: tìm gói, xin báo giá, theo dõi nhà mình. Nhà thầu: nhận khách, báo giá, quản lý gói và công trình.
            </p>
          </>
        )}

        <h2 className="section-title">{contractorMode ? 'Nhà thầu' : 'Nhà của tôi'}</h2>
        {contractorMode ? (
          <>
            <RowCard icon="storefront" title="Hồ sơ nhà thầu" subtitle="Tên xưởng, khu vực, phong cách, giới thiệu" href="/tai-khoan/ho-so-nha-thau" />
            <RowCard icon="visibility" title="Xem hồ sơ công khai" subtitle="Như chủ nhà nhìn thấy (khi đã xác minh)" onClick={publicProfile} />
          </>
        ) : (
          <>
            <RowCard icon="straighten" title="Bản đo nhà của tôi" subtitle="Mặt bằng, khung 3D, diện tích để gửi nhà thầu" href="/do-nha" />
            {!isContractor && (
              <RowCard
                icon="handyman"
                title="Trở thành nhà thầu"
                subtitle="Bạn là xưởng, nhà thầu nội thất? Đăng gói theo mẫu căn, nhận khách"
                href="/tai-khoan/dang-ky-nha-thau"
              />
            )}
          </>
        )}

        <h2 className="section-title">Tài khoản</h2>
        <RowCard icon="edit" title="Đổi họ tên" subtitle={name || 'Tên hiển thị với nhà thầu / chủ nhà'} onClick={editName} />
        <RowCard
          icon="logout"
          title="Đăng xuất"
          subtitle="Đăng xuất khỏi máy này"
          onClick={async () => {
            await api.logout();
            router.push('/');
          }}
        />
        {/* ponytail: tạm ẩn "Xoá tài khoản" như app (API DELETE /me vẫn có); bật lại khi cần. */}
      </main>
    </>
  );
}
