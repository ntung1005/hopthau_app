import 'package:flutter/foundation.dart';

/// Cấu hình qua --dart-define hoặc --dart-define-from-file=env/local.json.
class Env {
  Env._();

  /// Địa chỉ BE (hopthau_be). App chỉ gọi BE, không gọi Supabase trực tiếp.
  static const _apiUrl = String.fromEnvironment('API_URL');

  /// Để trống thì dùng BE trên máy phát triển: máy ảo Android gọi máy thật qua
  /// 10.0.2.2, iOS Simulator và trình duyệt dùng 127.0.0.1.
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return isAndroid ? 'http://10.0.2.2:8788' : 'http://127.0.0.1:8788';
  }
}
