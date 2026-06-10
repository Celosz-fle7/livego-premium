import 'package:flutter/foundation.dart';

class LiveGoCacheObserver {
  LiveGoCacheObserver._();

  static void log(
    String event, {
    required String domain,
    String? key,
    int? itemCount,
    int? estimatedBytes,
    Duration? ttl,
    bool? expired,
    String? reason,
  }) {
    if (!kDebugMode) return;
    final parts = <String>[
      'LIVEGO_CACHE event=$event',
      'domain=$domain',
      if (key != null && key.trim().isNotEmpty) 'key=${_safeKey(key)}',
      if (itemCount != null) 'itemCount=$itemCount',
      if (estimatedBytes != null) 'estimatedBytes=$estimatedBytes',
      if (ttl != null) 'ttlSeconds=${ttl.inSeconds}',
      if (expired != null) 'expired=$expired',
      if (reason != null && reason.trim().isNotEmpty) 'reason=$reason',
    ];
    debugPrint(parts.join(' '));
  }

  static String _safeKey(String value) {
    final clean = value.trim();
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
      final tail = path.length <= 18 ? path : path.substring(path.length - 18);
      return '${uri.host}/…$tail';
    }
    if (clean.length <= 72) return clean;
    return '${clean.substring(0, 36)}…${clean.substring(clean.length - 18)}';
  }
}
