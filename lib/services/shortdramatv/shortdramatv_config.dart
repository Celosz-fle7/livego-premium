/// Konfigurasi ShortDramaTV (com.shortdramatv.rlles) untuk LiveGo.
///
/// Diekstrak dari runtime analysis:
/// - Video CDN: bxdgpro.hfbjz.top
/// - Local proxy: 127.0.0.1:7000/resource.mp4?src={base64}
/// - API hosts (runtime config): baok6.x8x0f.top, an6.shortdramatv.top
/// - Cloud: 73ofnk.0kxb7.top
class ShortDramaTvConfig {
  /// Base host video CDN
  static const String videoCdn = 'https://bxdgpro.hfbjz.top';

  /// Base host cover/poster
  static const String coverCdn = 'https://bxdgpro.hfbjz.top';

  /// API host yang terdeteksi dari runtime config
  static const String apiHost = 'https://baok6.x8x0f.top';
  static const String backupHost = 'https://an6.shortdramatv.top';
  static const String cloudUrl = 'https://73ofnk.0kxb7.top';

  /// Port proxy lokal (sama seperti app asli)
  static const int localProxyPort = 7000;

  /// User ID dari device
  static const String defaultUserId = '16684095';

  /// GAID
  static const String defaultGaid = '3c13788d-90a1-42b0-b1f4-5460a0cb3c4e';

  /// Token dari runtime (long-lived, dari server)
  static const String defaultToken =
      'gAAAAABqz-CPk6QdKW6-WOU_Xx7IwutwYpqUwzESLJLmghKSdgByeK6-XKWxhDbjwiZfWDnYFaBFBZXV4lDJOVpfv15_A82vHIkCM9ZYgjslnbjby90Io35ubJzo73lK9BFSfaXuGT3QRfuiY_16IjWVXYs0gx7O9cl6wp0bMfPdS6WCACKYjDPkLJY3WIN0OspW0Gjy0G8PdgQUyKQIvOSadXQkABXgTQ==';

  /// Kategori bawaan
  static const List<String> categories = [
    'Populer',
    'Trending',
    'Rilisan Baru',
    'Dubbing',
    'Reinkarnasi',
    'Mafia',
    'Balas Dendam',
    'Romansa Manis',
  ];

  /// URL pattern:
  /// Video: {videoCdn}/series/{hash}/translated/id/{ep}.mp4
  /// Cover: {videoCdn}/series/id_{vod_id}/cover.jpg
  /// Proxy: http://127.0.0.1:{port}/resource.mp4?src={base64(videoUrl)}
  static String videoUrl(String seriesHash, int episode) =>
      '$videoCdn/series/$seriesHash/translated/id/$episode.mp4';

  static String coverUrl(int vodId) =>
      '$videoCdn/series/id_$vodId/cover.jpg';

  static String proxyUrl(String directUrl, {int port = localProxyPort}) {
    final encoded = Uri.encodeComponent(directUrl);
    return 'http://127.0.0.1:$port/resource.mp4?src=$encoded&sl=1';
  }
}
