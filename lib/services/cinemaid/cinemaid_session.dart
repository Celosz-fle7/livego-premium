import 'package:flutter/services.dart';

class CinemaIdSession {
  static const MethodChannel _channel = MethodChannel('livego/cinema_session');

  static Future<Map<String, String>> read() async {
    try {
      final result = await _channel.invokeMethod('getCinemaIdSession');
      if (result is Map) {
        return Map<String, String>.from(result);
      }
    } catch (_) {}
    return {};
  }
}
