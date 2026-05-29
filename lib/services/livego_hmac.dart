import '../api/auth/hmac_signer.dart';
import '../api/config/api_keys.dart';

class LiveGoHmac {
  static const String secret = ApiKeys.dramaApiSecret;

  static Map<String, String> headers({
    required String method,
    required Uri uri,
  }) {
    return HmacSigner.signedHeaders(
      method: method,
      uri: uri,
      secret: secret,
    );
  }
}
