// Định dạng tiền, ngày, số và câu báo lỗi. Cùng quy tắc với app Flutter (hopthau_app/lib/format.dart).

/** 31960000 -> "31.960.000 đ" */
export function vnd(amount: number): string {
  const digits = String(Math.abs(Math.round(amount)));
  let out = amount < 0 ? '-' : '';
  for (let i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) out += '.';
    out += digits[i];
  }
  return `${out} đ`;
}

/** 31960000 -> "32 triệu", 31940000 -> "31,9 triệu". */
export function vndShort(amount: number): string {
  if (amount < 1000000) return vnd(amount);
  const tenths = Math.round(amount / 100000);
  const whole = Math.floor(tenths / 10), frac = tenths % 10;
  return frac === 0 ? `${whole} triệu` : `${whole},${frac} triệu`;
}

const errors: Record<string, string> = {
  invalid_phone: 'Số điện thoại không hợp lệ',
  weak_password: 'Mật khẩu cần 6-72 ký tự',
  phone_taken: 'Số điện thoại đã có tài khoản, hãy đăng nhập',
  invalid_credentials: 'Sai số điện thoại hoặc mật khẩu',
  too_many_attempts: 'Thử quá nhiều lần, vui lòng đợi vài phút',
  not_floor_plan: 'Ảnh này không phải mặt bằng. Hãy chọn ảnh bản vẽ nhìn từ trên xuống, có các phòng',
  drawing_unreadable: 'Chưa đọc được bản vẽ. Thử ảnh rõ hơn, chụp thẳng, đủ sáng',
  drawing_failed: 'Tính năng đọc bản vẽ đang tạm dừng, thử lại sau hoặc bắt đầu từ mẫu',
  drawing_unavailable: 'Tính năng đọc bản vẽ đang tạm dừng, thử lại sau hoặc bắt đầu từ mẫu',
  invalid_area_m2: 'Diện tích sàn cần từ 5 đến 1000 m²',
  network: 'Không kết nối được máy chủ',
  missing_address: 'Vui lòng nhập địa chỉ căn nhà',
  missing_unit_or_address: 'Vui lòng nhập địa chỉ căn nhà',
  missing_province: 'Vui lòng chọn tỉnh / thành phố',
  invalid_province: 'Vui lòng chọn tỉnh / thành phố',
  invalid_areas: 'Khu vực phục vụ chưa hợp lệ',
  invalid_services: 'Hạng mục chưa hợp lệ',
  invalid_years_experience: 'Số năm kinh nghiệm chưa hợp lệ',
  missing_message: 'Vui lòng ghi lời nhắn: lịch hẹn, cách làm việc',
  offline_job: 'Công trình làm việc trực tiếp không ghi phát sinh trong app',
  contractor_exists: 'Tài khoản đã có hồ sơ nhà thầu',
  missing_name: 'Vui lòng nhập tên',
  missing_style: 'Vui lòng nhập phong cách',
  missing_unit_type_id: 'Vui lòng chọn mẫu căn',
  missing_items: 'Gói cần ít nhất một hạng mục',
  missing_duration_days: 'Số ngày thi công chưa hợp lệ',
  invalid_duration_days: 'Số ngày thi công chưa hợp lệ',
  missing_warranty_months: 'Số tháng bảo hành chưa hợp lệ',
  invalid_warranty_months: 'Số tháng bảo hành chưa hợp lệ',
  missing_price: 'Giá chưa hợp lệ',
  invalid_price: 'Giá chưa hợp lệ',
  invalid_qty: 'Số lượng chưa hợp lệ',
  request_closed: 'Chủ nhà đã chọn nhà thầu cho yêu cầu này',
  quote_not_found: 'Nhà thầu chưa gửi báo giá',
  package_not_found: 'Không tìm thấy gói (có thể gói đã đăng nên không xoá được)',
  not_contractor: 'Bạn chưa đăng ký làm nhà thầu',
  previous_milestone_open: 'Cần chủ nhà nghiệm thu mốc trước',
  milestone_not_open: 'Mốc này đã được xử lý, tải lại trang để cập nhật',
  milestone_not_submitted: 'Mốc này đã được xử lý, tải lại trang để cập nhật',
  missing_feedback: 'Vui lòng ghi rõ cần sửa gì',
  missing_title: 'Vui lòng nhập nội dung',
  invalid_amount: 'Số tiền chưa hợp lệ',
  invalid_days_delta: 'Số ngày chưa hợp lệ',
  job_not_completed: 'Công trình chưa bàn giao',
  already_reviewed: 'Bạn đã đánh giá công trình này',
  upload_failed: 'Không tải được ảnh',
  measurement_not_found: 'Không tìm thấy bản đo',
  missing_rooms: 'Bản đo cần ít nhất một phòng',
  invalid_opening_offset: 'Cửa vượt quá chiều dài tường',
  invalid_opening_width: 'Cửa vượt quá chiều dài tường',
  invalid_room_width: 'Kích thước phòng chưa hợp lệ',
  invalid_room_length: 'Kích thước phòng chưa hợp lệ',
  invalid_room_height: 'Chiều cao trần từ 1,8 đến 6 m',
};

/** Lỗi {"error": code} của BE -> câu tiếng Việt. */
export const errorMessage = (code: string) => errors[code] ?? `Có lỗi xảy ra (${code})`;

/** "2026-12-15" -> "15/12/2026". Sai định dạng thì trả nguyên chuỗi. */
export function vnDate(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  const two = (n: number) => String(n).padStart(2, '0');
  return `${two(d.getDate())}/${two(d.getMonth() + 1)}/${d.getFullYear()}`;
}

/** "13,5" hoặc "13.5" (triệu) -> 13500000. Sai định dạng: null. */
export function parseMillions(input: string): number | null {
  const v = parseNum(input);
  return v == null || v < 0 ? null : Math.round(v * 1000000);
}

/** "3,45" hoặc "3.45" -> 3.45; rỗng / sai: null. */
export function parseNum(input: string): number | null {
  const s = input.trim().replace(',', '.');
  if (!/^-?\d*\.?\d+$/.test(s)) return null;
  return Number(s);
}

/** 56.2 -> "56,2" */
export const vnDecimal = (value: unknown) => String(value).replace('.', ',');

const vnFrom = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const vnTo = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/** Chữ thường, bỏ dấu tiếng Việt: "Sông Hồng" -> "song hong". Dùng cho tìm kiếm. */
export function foldVietnamese(s: string): string {
  return [...s.toLowerCase()].map((ch) => {
    const i = vnFrom.indexOf(ch);
    return i < 0 ? ch : vnTo[i];
  }).join('');
}

/** Số đo mét làm tròn 2 chữ số: 3.456 -> "3,46". */
export const m2 = (v: number) => vnDecimal(Math.round(v * 100) / 100);

/** "84912345678" -> "0912345678". */
export const localPhone = (phone: string) => (phone.startsWith('84') ? `0${phone.slice(2)}` : phone);
