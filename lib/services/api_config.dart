class ApiConfig {
  static const String baseUrl = 'https://priv-api.anichin.bio';

  // API-DRACIN key. Active code uses AnichinApiClient with X-API-Key.
  static const String apiKey = 'dk_live_c261cb5920f82cf971e29edf0c8183d8';

  // Legacy clients are kept out of active routes, but keep this value aligned
  // so accidental old calls do not point at the retired Dobda secret.
  static const String apiSecret = apiKey;

  static const String defaultLang = 'id';
  static const Duration timeout = Duration(seconds: 18);

  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'okhttp/4.12.0',
    'X-API-Key': apiKey,
  };
}
