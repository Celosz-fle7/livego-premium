import 'hmac_signer.dart';
import 'api_config.dart';

class LiveGoHmac {
  static const String secret = ApiConfig.apiSecret;

  static Map<String, String> headers({
    required String method,
    required Uri uri,
  }) {
    return const HmacSigner(secret).sign(method, uri);
  }
}
