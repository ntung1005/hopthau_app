/// 31960000 -> "31.960.000 đ"
String vnd(num amount) {
  final digits = amount.round().abs().toString();
  final buf = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '$buf đ';
}

/// 31960000 -> "32 triệu", 31940000 -> "31,9 triệu".
String vndShort(num amount) {
  if (amount < 1000000) return vnd(amount);
  final tenths = (amount / 100000).round();
  final whole = tenths ~/ 10, frac = tenths % 10;
  return frac == 0 ? '$whole triệu' : '$whole,$frac triệu';
}

/// Lỗi {"error": code} của BE -> câu tiếng Việt.
String errorMessage(String code) => switch (code) {
      'invalid_phone' => 'Số điện thoại không hợp lệ',
      'weak_password' => 'Mật khẩu cần 6-72 ký tự',
      'phone_taken' => 'Số điện thoại đã có tài khoản, hãy đăng nhập',
      'invalid_credentials' => 'Sai số điện thoại hoặc mật khẩu',
      'too_many_attempts' => 'Thử quá nhiều lần, vui lòng đợi vài phút',
      'network' => 'Không kết nối được máy chủ',
      'missing_address' || 'missing_unit_or_address' => 'Vui lòng nhập địa chỉ căn nhà',
      'missing_province' || 'invalid_province' => 'Vui lòng chọn tỉnh / thành phố',
      'invalid_areas' => 'Khu vực phục vụ chưa hợp lệ',
      'invalid_services' => 'Hạng mục chưa hợp lệ',
      'invalid_years_experience' => 'Số năm kinh nghiệm chưa hợp lệ',
      'missing_message' => 'Vui lòng ghi lời nhắn: lịch hẹn, cách làm việc',
      'offline_job' => 'Công trình làm việc trực tiếp không ghi phát sinh trong app',
      'contractor_exists' => 'Tài khoản đã có hồ sơ nhà thầu',
      'missing_name' => 'Vui lòng nhập tên',
      'missing_style' => 'Vui lòng nhập phong cách',
      'missing_unit_type_id' => 'Vui lòng chọn mẫu căn',
      'missing_items' => 'Gói cần ít nhất một hạng mục',
      'missing_duration_days' || 'invalid_duration_days' => 'Số ngày thi công chưa hợp lệ',
      'missing_warranty_months' || 'invalid_warranty_months' => 'Số tháng bảo hành chưa hợp lệ',
      'missing_price' || 'invalid_price' => 'Giá chưa hợp lệ',
      'request_closed' => 'Chủ nhà đã chọn nhà thầu cho yêu cầu này',
      'quote_not_found' => 'Nhà thầu chưa gửi báo giá',
      'package_not_found' => 'Không tìm thấy gói (có thể gói đã đăng nên không xoá được)',
      'not_contractor' => 'Bạn chưa đăng ký làm nhà thầu',
      'previous_milestone_open' => 'Cần chủ nhà nghiệm thu mốc trước',
      'milestone_not_open' || 'milestone_not_submitted' => 'Mốc này đã được xử lý, kéo xuống để tải lại',
      'missing_feedback' => 'Vui lòng ghi rõ cần sửa gì',
      'missing_title' => 'Vui lòng nhập nội dung',
      'invalid_amount' => 'Số tiền chưa hợp lệ',
      'invalid_days_delta' => 'Số ngày chưa hợp lệ',
      'job_not_completed' => 'Công trình chưa bàn giao',
      'already_reviewed' => 'Bạn đã đánh giá công trình này',
      'upload_failed' => 'Không tải được ảnh',
      'measurement_not_found' => 'Không tìm thấy bản đo',
      'missing_rooms' => 'Bản đo cần ít nhất một phòng',
      'invalid_opening_offset' || 'invalid_opening_width' => 'Cửa vượt quá chiều dài tường',
      'invalid_room_width' || 'invalid_room_length' => 'Kích thước phòng chưa hợp lệ',
      'invalid_room_height' => 'Chiều cao trần từ 1,8 đến 6 m',
      _ => 'Có lỗi xảy ra ($code)',
    };

/// "2026-12-15" -> "15/12/2026". Sai định dạng thì trả nguyên chuỗi.
String vnDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// "13,5" hoặc "13.5" (triệu) -> 13500000. Sai định dạng: null.
int? parseMillions(String input) {
  final v = double.tryParse(input.trim().replaceAll(',', '.'));
  return v == null || v < 0 ? null : (v * 1000000).round();
}

/// 56.2 -> "56,2"
String vnDecimal(Object value) => '$value'.replaceAll('.', ',');

const _vnFrom = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _vnTo = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Chữ thường, bỏ dấu tiếng Việt: "Sông Hồng" -> "song hong". Dùng cho tìm kiếm.
String foldVietnamese(String s) {
  final lower = s.toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    final i = _vnFrom.indexOf(ch);
    buf.write(i < 0 ? ch : _vnTo[i]);
  }
  return buf.toString();
}
