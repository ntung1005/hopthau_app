'use client';

// Trạng thái dùng chung: phiên đăng nhập, tài khoản (vai trò), chế độ đang dùng (chủ nhà / nhà thầu), thông báo nhanh.
// Chế độ quyết định bộ tab: chủ nhà không thấy tính năng nhà thầu và ngược lại.

import { usePathname, useRouter } from 'next/navigation';
import { createContext, useCallback, useContext, useEffect, useState, useSyncExternalStore, type ReactNode } from 'react';
import { api, ApiError, getSession, onSession, store, type Json, type Session } from '@/lib/api';
import { errorMessage } from '@/lib/format';

export type Mode = 'owner' | 'contractor';

interface AppState {
  session: Session | null;
  /** GET /me: {id, phone, full_name, roles}. null khi chưa đăng nhập. */
  me: Json | null;
  mode: Mode;
  isContractor: boolean;
  refresh: () => Promise<void>;
  setMode: (m: Mode) => void;
  toast: (msg: string) => void;
  showError: (e: unknown) => void;
}

const Ctx = createContext<AppState | null>(null);

export function useApp() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useApp ngoài AppProvider');
  return v;
}

const MODE_KEY = 'app_mode';

/** Không có vai trò nhà thầu: luôn chủ nhà. Có: theo lựa chọn đã lưu, mặc định nhà thầu. */
const chooseMode = (isContractor: boolean, saved: string | null): Mode =>
  isContractor && saved !== 'owner' ? 'contractor' : 'owner';

export const errorText = (e: unknown) => errorMessage(e instanceof ApiError ? e.code : 'internal');

export function AppProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const session = useSyncExternalStore(onSession, getSession, () => null);
  const [me, setMe] = useState<Json | null>(null);
  const [mode, setModeState] = useState<Mode>('owner');
  const [toasts, setToasts] = useState<{ id: number; msg: string }[]>([]);

  const refresh = useCallback(async () => {
    if (!getSession()) {
      setMe(null);
      setModeState('owner');
      return;
    }
    try {
      const m = await api.getAuth('/me');
      setMe(m);
      setModeState(chooseMode((m?.roles ?? []).includes('contractor'), store.get(MODE_KEY)));
    } catch (e) {
      console.warn('Không tải được tài khoản', e);
    }
  }, []);

  useEffect(() => {
    let prev = getSession();
    const off = onSession(() => {
      // Chỉ tải lại tài khoản khi đăng nhập / đăng xuất, không phải mỗi lần làm mới token.
      const s = getSession();
      if (!s !== !prev) void refresh();
      prev = s;
    });
    // Tải tài khoản một lần lúc mở app (như main() của app Flutter), xong mới hiện giao diện.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void refresh().finally(() => setReady(true));
    return off;
  }, [refresh]);

  const toast = useCallback((msg: string) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, msg }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3500);
  }, []);

  const value: AppState = {
    session, me, mode,
    isContractor: (me?.roles ?? []).includes('contractor'),
    refresh,
    setMode: (m) => {
      setModeState(m);
      store.set(MODE_KEY, m);
    },
    toast,
    showError: (e) => toast(errorText(e)),
  };

  return (
    <Ctx.Provider value={value}>
      {ready ? children : <div className="center-screen"><div className="spinner" /></div>}
      <div className="toasts" role="status" aria-live="polite">
        {toasts.map((t) => <div key={t.id} className="toast">{t.msg}</div>)}
      </div>
    </Ctx.Provider>
  );
}

/** Trang cần đăng nhập: chưa đăng nhập thì chuyển sang màn đăng nhập rồi quay lại. true khi đã đăng nhập. */
export function useRequireAuth() {
  const { session } = useApp();
  const router = useRouter();
  const path = usePathname();
  useEffect(() => {
    if (!session) router.replace(loginHref(path + location.search));
  }, [session, router, path]);
  return !!session;
}

export const loginHref = (next: string) => `/dang-nhap?next=${encodeURIComponent(next)}`;

/** Đi tới [href]; trang cần đăng nhập thì qua màn đăng nhập trước. */
export function useGoAuthed() {
  const { session } = useApp();
  const router = useRouter();
  return (href: string) => router.push(session ? href : loginHref(href));
}

/** useLoad cho trang cần đăng nhập: chưa đăng nhập thì chuyển sang màn đăng nhập, không gọi API. */
export function useAuthLoad<T>(load: () => Promise<T>, deps: unknown[]) {
  const authed = useRequireAuth();
  const { me } = useApp();
  // Đổi tài khoản (me.id) thì tải lại.
  return useLoad<T>(() => (authed ? load() : new Promise<T>(() => {})), [authed, me?.id, ...deps]);
}

/** Tải dữ liệu theo [deps]; reload() để tải lại. */
export function useLoad<T>(load: () => Promise<T>, deps: unknown[]) {
  const [n, setN] = useState(0);
  // Kết quả gắn với khoá của lần tải; khoá đổi mà chưa có kết quả mới là đang tải (dữ liệu cũ vẫn hiện).
  const key = JSON.stringify([...deps, n]);
  const [state, setState] = useState<{ key?: string; data?: T; error?: unknown }>({});
  useEffect(() => {
    let alive = true;
    load().then(
      (data) => alive && setState({ key, data }),
      (error) => alive && setState((s) => ({ key, data: s.data, error })),
    );
    return () => void (alive = false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  const loading = state.key !== key;
  return { data: state.data, error: loading ? undefined : state.error, loading, reload: () => setN((x) => x + 1) };
}
