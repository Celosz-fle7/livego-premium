class ApiConfig {
  static const String baseUrl = 'https://api-drama.dobda.id';
  static const String apiSecret = '22dfb2b849814054af0491ff2ee3ffe33989313d7d38e97aae659757a4cf8960';
  static const String defaultLang = 'id';
  static const Duration timeout = Duration(seconds: 18);
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'okhttp/4.12.0',
  };
}
