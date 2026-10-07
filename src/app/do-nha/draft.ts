// Bản đo nháp chưa lưu (từ mẫu hoặc từ bản vẽ), chuyển từ danh sách sang trình sửa /do-nha/moi.
// Giữ trong sessionStorage để tải lại trang không mất.

import { planFromJson, planTemplates, planToJson, type Plan } from '@/lib/measure';

const KEY = 'draft_plan';

export function putDraft(plan: Plan, name: string) {
  try {
    sessionStorage.setItem(KEY, JSON.stringify({ name, plan: planToJson(plan) }));
  } catch {
    // Không lưu được: trình sửa mở mẫu mặc định.
  }
}

export function takeDraft(): { plan: Plan; name: string } {
  try {
    const raw = sessionStorage.getItem(KEY);
    if (raw) {
      const d = JSON.parse(raw);
      return { plan: planFromJson(d.plan), name: d.name };
    }
  } catch {
    // Bỏ qua, dùng mẫu mặc định.
  }
  return { plan: Object.values(planTemplates)[0](), name: 'Nhà của tôi' };
}

export const clearDraft = () => {
  try {
    sessionStorage.removeItem(KEY);
  } catch {
    // Không sao.
  }
};
