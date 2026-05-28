import 'dart:convert';

import 'package:crypto/crypto.dart';

class LiveGoHmac {
  static const String secret = String.fromEnvironment(
    'API_SECRET',
    defaultValue:
        '22dfb2b849814054af0491ff2ee3ffe33989313d7d38e97aae659757a4cf8960',
  );

  static Map<String, String> headers({
    required String method,
    required Uri uri,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final payload = '${method.toUpperCase()}:$pathWithQuery:$timestamp';
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final signature = Hmac(sha256, key).convert(bytes).toString();

    return {
      'Accept': 'application/json',
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    };
  }
}
