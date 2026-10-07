/// Konfigurasi statis CinemaID (com.movieph.bj.playvibes).
///
/// Base URL server-driven: GET {base}/api/public/init -> data.sys_conf.api_url
/// (fallback hardcoded ke [fallbackBaseUrl], mirror dari biner APK).
class CinemaIdConfig {
  CinemaIdConfig._();

  /// Fallback base URL aktif (server live).
  static const fallbackBaseUrl = 'https://freecinenewph.t62nds.com';

  /// Path init (tanpa prefix /api, client yang menambahkan).
  static const initPath = '/public/init';

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; M2010J19CG Build/TKQ1.221114.001) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  static const timeout = Duration(seconds: 15);

  /// Kategori bawaan provider streaming populer dan channel CinemaID.
  static const categories = <String>[
    'For You',
    'Netflix',
    'Viu',
    'WeTV',
    'Vidio',
    'Prime Video',
    'Hotstar',
    'Movie',
    'Drama',
    'Anime',
  ];

  /// Taruh token auth sebagai header DAN query param.
  /// Dari static analysis penempatan pastinya tidak jelas;
  /// mengirim keduanya aman dan kompatibel dengan kedua gaya.
  static const sendTokenAsHeader = true;
  static const sendTokenAsQuery = true;
  static const tokenQueryKey = 'token';
}
