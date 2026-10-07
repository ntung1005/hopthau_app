import type { Metadata, Viewport } from 'next';
import { Be_Vietnam_Pro } from 'next/font/google';
import { Suspense } from 'react';
import { AppProvider } from '@/ui/app';
import { Shell } from '@/ui/shell';
import './globals.css';

// Font thiết kế cho tiếng Việt: dấu không bị chồng, không lệch dòng (cùng font với hopthau_web).
const font = Be_Vietnam_Pro({ subsets: ['vietnamese', 'latin'], weight: ['400', '500', '600', '700'], display: 'swap' });

export const metadata: Metadata = {
  title: 'Hợp Thầu',
  description: 'Nội thất trọn gói theo mẫu căn, giá công khai. Thầu hợp căn, hợp giá, hợp ý.',
};

export const viewport: Viewport = { themeColor: '#304FFE', width: 'device-width', initialScale: 1 };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="vi" className={font.className}>
      <head>
        {/* Bộ icon Material (cùng bộ với app Flutter), chỉ dùng trục FILL. */}
        {/* display=block: font icon hiện chữ "arrow_back" nếu swap. */}
        {/* eslint-disable-next-line @next/next/no-page-custom-font, @next/next/google-font-display */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@24,400,0..1,0&display=block"
        />
      </head>
      <body>
        {/* App chạy hoàn toàn trên trình duyệt (phiên lưu ở localStorage); Suspense cho useSearchParams. */}
        <Suspense>
          <AppProvider>
            <Shell>{children}</Shell>
          </AppProvider>
        </Suspense>
      </body>
    </html>
  );
}
