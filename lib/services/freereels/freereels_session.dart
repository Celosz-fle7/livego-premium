import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'freereels_config.dart';

/// Session FreeReels — meniru flow login APK.
///
/// APK tidak hardcode authKey/authSecret. Saat pertama jalan:
///   POST /frv2-api/anonymous/login  { "device_id": "<32hex>" }
/// -> { code:200, data:{ auth_key, auth_secret, user_id, ... } }
/// Hasil disimpan di SharedPreferences, dipakai untuk signing.
///
/// (Terverifikasi live 2026-10-07: POST tanpa Authorization,
///  body {"device_id"} -> code 200 + auth_key/auth_secret.)
class FreereelsSession {
  static const _kAuthKey = 'freereels_auth_key';
  static const _kAuthSecret = 'freereels_auth_secret';
  static const _kUserId = 'freereels_user_id';
  static const _kDeviceId = 'freereels_device_id';

  static final _random = Random.secure();

  String? _authKey;
  String? _authSecret;

  /// device-id stabil per install (32 hex, mirip uuid4().hex di Python).
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString(_kDeviceId, id);
    }
    return id;
  }

  Future<void> _load() async {
    if (_authKey != null && _authSecret != null) return;
    final prefs = await SharedPreferences.getInstance();
    _authKey = prefs.getString(_kAuthKey);
    _authSecret = prefs.getString(_kAuthSecret);
  }

  bool get isLoggedIn => _authKey != null && _authSecret != null;
  String get authKey => _authKey ?? '';
  String get authSecret => _authSecret ?? '';

  /// Pastikan sudah login. Kalau belum, panggil /anonymous/login.
  Future<void> ensureLogin() async {
    await _load();
    if (isLoggedIn) return;

    final uri = Uri.parse(
      '${FreereelsConfig.baseUrl}${FreereelsConfig.apiPrefix}/anonymous/login',
    );
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(FreereelsConfig.timeout);
      request.headers.set('User-Agent', FreereelsConfig.userAgent);
      request.headers.set('Content-Type', 'application/json; charset=UTF-8');
      request.headers.set('Accept', 'application/json');
      request.headers.set('app-version', FreereelsConfig.appVersion);
      request.headers.set('app-name', FreereelsConfig.appName);
      request.headers.set('device', FreereelsConfig.device);
      request.headers.set('device-id', await deviceId());
      request.headers.set('language', FreereelsConfig.language);
      request.headers.set('country', FreereelsConfig.country);
      request.headers.set('x-device-model', FreereelsConfig.deviceModel);
      request.headers.set('screen-width', FreereelsConfig.screenWidth);
      request.headers.set('screen-height', FreereelsConfig.screenHeight);
      request.write(jsonEncode({'device_id': await deviceId()}));

      final response = await request.close().timeout(FreereelsConfig.timeout);
      final body = await response.transform(utf8.decoder).join();
      final res = jsonDecode(body) as Map<String, dynamic>;

      if (res['code'] != 200) {
        throw Exception('anonymous/login gagal: code=${res['code']} ${res['msg']}');
      }
      final data = res['data'] as Map<String, dynamic>;
      _authKey = '${data['auth_key']}';
      _authSecret = '${data['auth_secret']}';
      if (_authKey!.isEmpty || _authSecret!.isEmpty) {
        throw Exception('anonymous/login: auth_key/auth_secret kosong');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAuthKey, _authKey!);
      await prefs.setString(_kAuthSecret, _authSecret!);
      await prefs.setString(_kUserId, '${data['user_id']}');
    } finally {
      client.close(force: true);
    }
  }

  /// Hapus session (paksa login ulang).
  Future<void> clear() async {
    _authKey = null;
    _authSecret = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthKey);
    await prefs.remove(_kAuthSecret);
    await prefs.remove(_kUserId);
  }
}
