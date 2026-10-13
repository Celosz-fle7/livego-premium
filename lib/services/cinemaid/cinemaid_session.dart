
import 'package:shared_preferences/shared_preferences.dart';

class CinemaIdSession {
  static const _keyToken = 'cinemaid_token';
  static const _keyUserId = 'cinemaid_user_id';
  static const _keyDeviceId = 'cinemaid_device_id';
  static const _keyIsSvip = 'cinemaid_is_svip';

  static Future<Map<String, String>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString(_keyToken) ?? '',
      'userId': prefs.getString(_keyUserId) ?? '',
      'deviceId': prefs.getString(_keyDeviceId) ?? '',
      'isSvip': prefs.getString(_keyIsSvip) ?? '0',
    };
  }

  static Future<void> save({
    required String token,
    String userId = '',
    String deviceId = '',
    String isSvip = '0',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyDeviceId, deviceId);
    await prefs.setString(_keyIsSvip, isSvip);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyIsSvip);
  }

  static Future<bool> hasValidToken() async {
    final session = await read();
    return session['token']?.isNotEmpty == true;
  }
}
