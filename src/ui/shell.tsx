'use client';

// Khung chính: bộ tab và nút giữa theo chế độ. Thanh tab chỉ hiện ở trang gốc của từng tab.
// Chủ nhà: Khám phá · Yêu cầu · [Đo nhà] · Công trình · Tài khoản.
// Nhà thầu: Khách hàng · Công trình · [Tạo gói] · Gói của tôi · Tài khoản.

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, type ReactNode } from 'react';
import { useApp } from './app';
import { Icon } from './kit';

const ownerTabs: [string, string, string][] = [
  ['/', 'home', 'Khám phá'],
  ['/yeu-cau', 'receipt_long', 'Yêu cầu'],
  ['/cong-trinh', 'construction', 'Công trình'],
  ['/tai-khoan', 'person', 'Tài khoản'],
];

const contractorTabs: [string, string, string][] = [
  ['/khach-hang', 'inbox', 'Khách hàng'],
  ['/cong-trinh', 'construction', 'Công trình'],
  ['/goi-cua-toi', 'chair', 'Gói của tôi'],
  ['/tai-khoan', 'person', 'Tài khoản'],
];

/** Trang đầu tiên của mỗi chế độ. */
export const homeOf = (mode: string) => (mode === 'contractor' ? '/khach-hang' : '/');

export function Shell({ children }: { children: ReactNode }) {
  const { mode } = useApp();
  const path = usePathname();
  const router = useRouter();
  const contractor = mode === 'contractor';
  const tabs = contractor ? contractorTabs : ownerTabs;
  const onTab = tabs.some(([href]) => href === path);

  // Tài khoản nhà thầu mở app vào chế độ nhà thầu: trang Khám phá của chủ nhà chuyển sang Khách hàng.
  useEffect(() => {
    if (contractor && path === '/') router.replace('/khach-hang');
  }, [contractor, path, router]);

  const tab = (i: number) => {
    const [href, icon, label] = tabs[i];
    const on = path === href;
    return (
      <Link href={href} className={`nav-tab${on ? ' on' : ''}`} aria-current={on ? 'page' : undefined}>
        <Icon name={icon} fill={on} />
        {label}
      </Link>
    );
  };

  return (
    <>
      {children}
      {onTab && (
        <nav className="nav" aria-label="Điều hướng chính">
          <div className="nav-inner">
            {tab(0)}
            {tab(1)}
            <span className="nav-gap" />
            {tab(2)}
            {tab(3)}
            <Link
              href={contractor ? '/goi-cua-toi/moi' : '/do-nha'}
              className={`fab${contractor ? ' accent' : ''}`}
              title={contractor ? 'Tạo gói mới' : 'Tự đo nhà'}
              aria-label={contractor ? 'Tạo gói mới' : 'Tự đo nhà'}
            >
              <Icon name={contractor ? 'add' : 'straighten'} size={28} />
            </Link>
          </div>
        </nav>
      )}
    </>
  );
}
