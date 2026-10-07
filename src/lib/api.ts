// Gọi REST API của BE (hopthau_be). Tự gắn token, tự làm mới token sắp hết hạn, xoá phiên khi server không nhận.
// Phiên lưu trong localStorage (như shared_preferences của app Flutter).

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Json = Record<string, any>;

export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://127.0.0.1:8788';

/** BE trả lỗi dạng {"error": code}. */
export class ApiError extends Error {
  constructor(public status: number, public code: string) {
    super(code);
  }
}

export interface Session {
  access_token: string;
  refresh_token: string;
  expires_at: number; // giây
}

const KEY = 'session';
const TIMEOUT = 20_000;
const listeners = new Set<() => void>();
let session: Session | null = null;
let loaded = false;

function readStore(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStore(key: string, value: string | null) {
  try {
    if (value == null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // Trình duyệt chặn lưu trữ: phiên chỉ sống trong tab này.
  }
}

export const store = { get: readStore, set: writeStore };

/** Phiên hiện tại; lần đầu gọi trên trình duyệt thì đọc phiên đã lưu. */
export function getSession(): Session | null {
  if (!loaded && typeof window !== 'undefined') {
    loaded = true;
    try {
      const raw = readStore(KEY);
      session = raw ? (JSON.parse(raw) as Session) : null;
    } catch {
      session = null;
    }
  }
  return session;
}

/** Lắng nghe đăng nhập / đăng xuất. Trả về hàm huỷ. */
export function onSession(fn: () => void) {
  listeners.add(fn);
  return () => void listeners.delete(fn);
}

function setSession(s: Session | null) {
  session = s;
  writeStore(KEY, s && JSON.stringify(s));
  listeners.forEach((fn) => fn());
}

const asSession = (j: Json): Session => ({
  access_token: j.access_token,
  refresh_token: j.refresh_token,
  expires_at: j.expires_at ?? 0,
});

async function send(method: string, path: string, body?: unknown, auth = false): Promise<Json | Json[] | null> {
  const token = auth ? await validToken() : null;
  const headers: Record<string, string> = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT),
    });
  } catch {
    throw new ApiError(0, 'network');
  }
  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (res.status === 401 && auth) setSession(null);
  if (res.status >= 400) throw new ApiError(res.status, (data && typeof data.error === 'string' && data.error) || `http_${res.status}`);
  return data;
}

// Nhiều lời gọi cùng lúc khi token hết hạn: chỉ làm mới một lần.
let refreshing: Promise<string> | null = null;

async function validToken(): Promise<string> {
  const s = getSession();
  if (!s) throw new ApiError(401, 'unauthorized');
  if (Date.now() < (s.expires_at - 60) * 1000) return s.access_token;
  refreshing ??= (async () => {
    try {
      const fresh = asSession((await send('POST', '/auth/refresh', { refresh_token: s.refresh_token })) as Json);
      setSession(fresh);
      return fresh.access_token;
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) setSession(null);
      throw e;
    } finally {
      refreshing = null;
    }
  })();
  return refreshing;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Any = any;

export const api = {
  register: async (phone: string, password: string, fullName: string) =>
    setSession(asSession((await send('POST', '/auth/register', { phone, password, full_name: fullName })) as Json)),
  login: async (phone: string, password: string) =>
    setSession(asSession((await send('POST', '/auth/login', { phone, password })) as Json)),
  async logout() {
    try {
      await send('POST', '/auth/logout', {}, true);
    } catch {
      // Mất mạng hoặc phiên đã hết hạn: vẫn đăng xuất trên máy.
    }
    setSession(null);
  },

  /** API công khai (danh mục). */
  get: (path: string): Promise<Any> => send('GET', path),
  /** API cần đăng nhập. */
  getAuth: (path: string): Promise<Any> => send('GET', path, undefined, true),
  postAuth: (path: string, body: unknown = {}): Promise<Any> => send('POST', path, body, true),
  putAuth: (path: string, body: unknown): Promise<Any> => send('PUT', path, body, true),
  patchAuth: (path: string, body: unknown): Promise<Any> => send('PATCH', path, body, true),
  deleteAuth: (path: string): Promise<Any> => send('DELETE', path, undefined, true),
};

let metaCache: Promise<Json> | null = null;

/** Danh sách tỉnh / thành và hạng mục (GET /meta), tải một lần; lỗi thì lần sau tải lại. */
export function meta(): Promise<Json> {
  metaCache ??= api.get('/meta').catch((e) => {
    metaCache = null;
    throw e;
  });
  return metaCache;
}

/** Thu nhỏ ảnh (cạnh dài tối đa [maxWidth]) và nén JPEG trước khi upload, như image_picker của app. */
async function shrink(file: File, maxWidth: number, quality: number): Promise<Blob> {
  try {
    const bmp = await createImageBitmap(file);
    const scale = Math.min(1, maxWidth / Math.max(bmp.width, bmp.height));
    if (scale === 1 && file.size < 1_500_000) return file;
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(bmp.width * scale);
    canvas.height = Math.round(bmp.height * scale);
    canvas.getContext('2d')!.drawImage(bmp, 0, 0, canvas.width, canvas.height);
    return await new Promise<Blob>((ok) => canvas.toBlob((b) => ok(b ?? file), 'image/jpeg', quality));
  } catch {
    return file;
  }
}

/** Upload một ảnh lên Storage qua URL ký sẵn của BE, trả về URL công khai. */
export async function uploadPhoto(file: File, maxWidth = 1920, quality = 0.82): Promise<string> {
  const blob = await shrink(file, maxWidth, quality);
  const type = blob.type || (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  const slot = await api.postAuth('/uploads', { content_type: type });
  const res = await fetch(slot.upload_url, { method: 'PUT', headers: { 'Content-Type': type }, body: blob });
  if (!res.ok) throw new ApiError(res.status, 'upload_failed');
  return slot.public_url as string;
}
