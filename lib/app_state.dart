// Trạng thái dùng chung: tài khoản đang đăng nhập (vai trò) và chế độ đang dùng (chủ nhà / nhà thầu).
// Chế độ quyết định bộ tab: chủ nhà không thấy tính năng nhà thầu và ngược lại.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

enum AppMode { owner, contractor }

class AppState {
  AppState(this._prefs) {
    api.session.addListener(refresh);
  }

  final SharedPreferences _prefs;
  static const _modeKey = 'app_mode';

  /// GET /me: {id, phone, full_name, roles}. null khi chưa đăng nhập.
  final me = ValueNotifier<Map<String, dynamic>?>(null);
  final mode = ValueNotifier<AppMode>(AppMode.owner);

  /// Tăng khi danh sách gói của nhà thầu đổi (tạo từ nút giữa), để tab Gói của tôi tải lại.
  final packagesVersion = ValueNotifier<int>(0);

  bool get isContractor => (me.value?['roles'] as List?)?.contains('contractor') ?? false;

  /// Tải lại tài khoản, chọn chế độ: chế độ đã lưu nếu còn hợp lệ, không thì nhà thầu nếu có vai trò nhà thầu.
  Future<void> refresh() async {
    if (api.session.value == null) {
      me.value = null;
      mode.value = AppMode.owner;
      return;
    }
    try {
      me.value = await api.getAuth('/me') as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Không tải được tài khoản: $e');
      return;
    }
    mode.value = chooseMode(isContractor: isContractor, saved: _prefs.getString(_modeKey));
  }

  /// Không có vai trò nhà thầu: luôn chủ nhà. Có: theo lựa chọn đã lưu, mặc định nhà thầu.
  static AppMode chooseMode({required bool isContractor, String? saved}) =>
      isContractor && saved != AppMode.owner.name ? AppMode.contractor : AppMode.owner;

  Future<void> setMode(AppMode m) async {
    mode.value = m;
    await _prefs.setString(_modeKey, m.name);
  }
}

/// Khởi tạo trong main(), sau api.
late final AppState app;
