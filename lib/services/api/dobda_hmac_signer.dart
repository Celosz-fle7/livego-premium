import 'dart:convert';

import 'package:crypto/crypto.dart';

class DobdaHmacSigner {
  const DobdaHmacSigner._();

  static Map<String, String> headers({
    required String method,
    required Uri uri,
    required String secret,
    required String userId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    // Nobuzero Contract: METHOD:FULL_PATH_WITH_QUERY:TIMESTAMP
    final fullPath = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final payload = '${method.toUpperCase()}:$fullPath:$timestamp';

    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(payload))
        .toString();

    return <String, String>{
      'X-User-Id': userId,
      'X-Timestamp': timestamp,
      'X-Signature': signature,
      'Accept': 'application/json',
      'User-Agent': 'okhttp/4.12.0',
    };
  }
}
