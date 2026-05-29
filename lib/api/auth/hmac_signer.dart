import 'dart:convert';

import 'package:crypto/crypto.dart';

class HmacSigner {
  HmacSigner._();

  static Map<String, String> signedHeaders({
    required String method,
    required Uri uri,
    required String secret,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final payload = '${method.toUpperCase()}:$pathWithQuery:$timestamp';
    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(payload))
        .toString();

    return <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'okhttp/4.12.0',
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    };
  }
}
