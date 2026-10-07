'use client';

// Đăng nhập / đăng ký bằng số điện thoại + mật khẩu. Xong thì quay lại trang [next].

import { useRouter, useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useApp } from '@/ui/app';
import { Field, Illustration, TopBar } from '@/ui/kit';

export default function LoginPage() {
  const router = useRouter();
  const next = useSearchParams().get('next') || '/';
  const { showError } = useApp();
  const [register, setRegister] = useState(false);
  const [busy, setBusy] = useState(false);
  const [f, setF] = useState({ name: '', phone: '', password: '' });

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      if (register) await api.register(f.phone, f.password, f.name);
      else await api.login(f.phone, f.password);
      // Chỉ quay về đường dẫn trong app.
      router.replace(next.startsWith('/') && !next.startsWith('//') ? next : '/');
    } catch (err) {
      showError(err);
      setBusy(false);
    }
  };

  return (
    <>
      <TopBar />
      <main className="page" style={{ maxWidth: 480 }}>
        <form className="form" onSubmit={submit}>
          <div style={{ display: 'grid', placeItems: 'center' }}><Illustration icon="chair" /></div>
          <h1 className="t-display center" style={{ marginTop: 10 }}>{register ? 'Tạo tài khoản Hợp Thầu' : 'Chào mừng trở lại'}</h1>
          <p className="muted center">
            {register
              ? 'Lưu gói bạn thích, gửi yêu cầu và theo dõi báo giá của nhà thầu.'
              : 'Đăng nhập để gửi yêu cầu và xem báo giá của bạn.'}
          </p>
          <div style={{ height: 8 }} />
          {register && (
            <Field label="Họ tên">
              <input autoComplete="name" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} />
            </Field>
          )}
          <Field label="Số điện thoại">
            <input type="tel" autoComplete="tel" required value={f.phone} onChange={(e) => setF({ ...f, phone: e.target.value })} />
          </Field>
          <Field label="Mật khẩu">
            <input
              type="password"
              autoComplete={register ? 'new-password' : 'current-password'}
              required
              value={f.password}
              onChange={(e) => setF({ ...f, password: e.target.value })}
            />
          </Field>
          <div style={{ height: 12 }} />
          <button className="btn" disabled={busy}>{register ? 'Tạo tài khoản' : 'Đăng nhập'}</button>
          <button type="button" className="btn outline" disabled={busy} onClick={() => setRegister(!register)}>
            {register ? 'Tôi đã có tài khoản' : 'Tạo tài khoản mới'}
          </button>
        </form>
      </main>
    </>
  );
}
