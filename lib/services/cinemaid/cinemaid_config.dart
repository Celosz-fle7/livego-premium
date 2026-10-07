/// Konfigurasi statis CinemaID (com.movieph.bj.playvibes).
///
/// Base URL server-driven: GET {base}/api/public/init -> data.sys_conf.api_url
/// (fallback hardcoded ke [fallbackBaseUrl], mirror dari biner APK).
class CinemaIdConfig {
  CinemaIdConfig._();

  /// Fallback base URL, verified ada di biner APK.
  static const fallbackBaseUrl = 'kuth.52s7g.com';

  /// Path init (tanpa prefix /api, client yang menambahkan).
  static const initPath = '/public/init';

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; M2010J19CG Build/TKQ1.221114.001) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  static const timeout = Duration(seconds: 15);

  /// Kategori bawaan (sinkron, tanpa network). Nama modul aktual bisa
  /// beda-beda; homeByCategory mencocokkan dengan module_name dari
  /// /api/topic/list, kalau tidak ketemu pakai modul pertama.
  static const categories = <String>[
    'For You',
    'Movie',
    'Drama',
    'Variety',
    'Anime',
  ];

  /// Taruh token auth sebagai header DAN query param.
  /// Dari static analysis penempatan pastinya tidak jelas;
  /// mengirim keduanya aman dan kompatibel dengan kedua gaya.
  static const sendTokenAsHeader = true;
  static const sendTokenAsQuery = true;
  static const tokenQueryKey = 'token';
}
