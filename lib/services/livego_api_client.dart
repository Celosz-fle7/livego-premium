import '../api/clients/api_http_client.dart';
import '../api/config/api_endpoints.dart';
import '../api/config/api_keys.dart';

class LiveGoApiClient {
  static const String baseUrl = ApiEndpoints.dramaBaseUrl;

  static const ApiHttpClient _client = ApiHttpClient(
    baseUrl: baseUrl,
    secret: ApiKeys.dramaApiSecret,
  );

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
    bool signed = true,
  }) {
    return _client.getJson(path, query, signed: signed);
  }
}
