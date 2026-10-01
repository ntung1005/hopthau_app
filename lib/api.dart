import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// BE trả lỗi dạng {"error": code}.
class ApiException implements Exception {
  const ApiException(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}

class Session {
  const Session(this.accessToken, this.refreshToken, this.expiresAt);

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        j['access_token'] as String,
        j['refresh_token'] as String,
        DateTime.fromMillisecondsSinceEpoch(((j['expires_at'] as num?)?.toInt() ?? 0) * 1000),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
      };
}

/// Gọi REST API của BE. Tự gắn token, tự làm mới token sắp hết hạn, xoá phiên
/// khi server không nhận nữa.
class Api {
  Api(this.baseUrl, this._prefs) : session = ValueNotifier(_load(_prefs));

  final String baseUrl;
  final SharedPreferences _prefs;
  final _http = http.Client();

  /// null khi chưa đăng nhập. Lắng nghe để đổi giao diện khi đăng nhập, đăng xuất.
  final ValueNotifier<Session?> session;

  static const _key = 'session';
  static const _timeout = Duration(seconds: 20);

  static Session? _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    return raw == null ? null : Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _setSession(Session? s) async {
    session.value = s;
    s == null ? await _prefs.remove(_key) : await _prefs.setString(_key, jsonEncode(s.toJson()));
  }

  // Tài khoản ---------------------------------------------------------------

  Future<void> register(String phone, String password, String fullName) async => _setSession(
      Session.fromJson(await _send('POST', '/auth/register', {'phone': phone, 'password': password, 'full_name': fullName})));

  Future<void> login(String phone, String password) async =>
      _setSession(Session.fromJson(await _send('POST', '/auth/login', {'phone': phone, 'password': password})));

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout', null, auth: true);
    } catch (_) {
      // Mất mạng hoặc phiên đã hết hạn: vẫn đăng xuất trên máy.
    }
    await _setSession(null);
  }

  // Gọi API -----------------------------------------------------------------

  /// API công khai (danh mục, lead).
  Future<dynamic> get(String path) => _send('GET', path, null);

  /// API cần đăng nhập.
  Future<dynamic> getAuth(String path) => _send('GET', path, null, auth: true);
  Future<dynamic> postAuth(String path, [Object? body]) => _send('POST', path, body ?? const {}, auth: true);
  Future<dynamic> putAuth(String path, Object body) => _send('PUT', path, body, auth: true);
  Future<dynamic> patchAuth(String path, Object body) => _send('PATCH', path, body, auth: true);
  Future<dynamic> deleteAuth(String path) => _send('DELETE', path, null, auth: true);

  Future<dynamic> _send(String method, String path, Object? body, {bool auth = false}) async {
    final token = auth ? await _validToken() : null;
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await _http.send(request).then(http.Response.fromStream).timeout(_timeout);
    } catch (_) {
      throw const ApiException(0, 'network');
    }
    final data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 401 && auth) await _setSession(null);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, (data is Map ? data['error'] as String? : null) ?? 'http_${res.statusCode}');
    }
    return data;
  }

  Future<String> _validToken() async {
    final s = session.value;
    if (s == null) throw const ApiException(401, 'unauthorized');
    if (DateTime.now().isBefore(s.expiresAt.subtract(const Duration(minutes: 1)))) return s.accessToken;
    try {
      final fresh = Session.fromJson(await _send('POST', '/auth/refresh', {'refresh_token': s.refreshToken}));
      await _setSession(fresh);
      return fresh.accessToken;
    } on ApiException catch (e) {
      if (e.status == 401) await _setSession(null);
      rethrow;
    }
  }
}

/// Khởi tạo trong main().
late final Api api;
