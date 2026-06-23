import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'api_env.dart';

/// Reusable signer for every Nobuzero `/api/v2/*` request.
///
/// Signature payload must be:
/// `METHOD:FULL_PATH_WITH_QUERY:TIMESTAMP`.
class LiveGoApiSigner {
  const LiveGoApiSigner._();

  static Map<String, String> signedHeaders({
    required String method,
    required Uri uri,
    String? timestamp,
  }) {
    final userId = ApiEnv.userId.trim();
    final secret = ApiEnv.secret.trim();
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch.toString();
    final pathWithQuery = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final payload = '${method.toUpperCase()}:$pathWithQuery:$ts';
    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(payload))
        .toString();

    return <String, String>{
      'X-User-Id': userId,
      'X-Timestamp': ts,
      'X-Signature': signature,
      'Accept': 'application/json',
      'User-Agent': 'okhttp/4.12.0',
    };
  }

  static void apply(HttpHeaders headers, {required String method, required Uri uri}) {
    for (final entry in signedHeaders(method: method, uri: uri).entries) {
      headers.set(entry.key, entry.value);
    }
  }
}
