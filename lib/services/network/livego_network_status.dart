import 'dart:async';
import 'dart:io';

/// Lightweight network reachability check for TV resilience.
///
/// No external dependency is used here to keep builds stable. This is not a
/// full connectivity listener; it is a cheap preflight check before Home tries
/// slow network work.
class LiveGoNetworkStatus {
  const LiveGoNetworkStatus._();

  static DateTime _lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _lastOnline = true;

  static Future<bool> isProbablyOnline({
    Duration throttle = const Duration(seconds: 5),
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastCheckedAt) < throttle) return _lastOnline;
    _lastCheckedAt = now;

    try {
      final result = await InternetAddress.lookup('nobuzero.my.id').timeout(timeout);
      _lastOnline = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('google.com').timeout(timeout);
        _lastOnline = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        _lastOnline = false;
      }
    }

    return _lastOnline;
  }

  static void markOnline() {
    _lastOnline = true;
    _lastCheckedAt = DateTime.now();
  }

  static void markOffline() {
    _lastOnline = false;
    _lastCheckedAt = DateTime.now();
  }
}
