import 'dart:convert';

import 'package:crypto/crypto.dart';

class HmacSigner {
  final String secret;
  const HmacSigner(this.secret);

  Map<String, String> sign(String method, Uri uri) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final payload = '${method.toUpperCase()}:$pathWithQuery:$timestamp';
    final signature = Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(payload)).toString();

    return {
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    };
  }
}
