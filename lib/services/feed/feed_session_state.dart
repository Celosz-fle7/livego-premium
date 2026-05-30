class FeedSessionState {
  FeedSessionState._();

  static final Map<String, DateTime> _lastNetworkRefresh = <String, DateTime>{};
  static final Map<String, int> _visitCounter = <String, int>{};

  static String key(String platform, String endpoint, {String lang = ''}) {
    final cleanPlatform = _clean(platform);
    final cleanEndpoint = _clean(endpoint);
    final cleanLang = _clean(lang);
    return '$cleanPlatform:$cleanEndpoint:$cleanLang';
  }

  static int markVisited(String key) {
    final next = (_visitCounter[key] ?? 0) + 1;
    _visitCounter[key] = next;
    return next;
  }

  static bool shouldRefresh(String key, Duration interval) {
    final last = _lastNetworkRefresh[key];
    if (last == null) return true;
    return DateTime.now().difference(last) >= interval;
  }

  static void markNetworkRefresh(String key) {
    _lastNetworkRefresh[key] = DateTime.now();
  }

  static String _clean(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '_');
  }
}
