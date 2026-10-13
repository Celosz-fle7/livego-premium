/// Konfigurasi statis CinemaID (com.movieph.bj.playvibes).
///
/// Base URL server-driven: GET {base}/api/public/init -> data.sys_conf.api_url
/// (fallback hardcoded ke [fallbackBaseUrl], mirror dari biner APK).
class CinemaIdConfig {
  CinemaIdConfig._();

  /// Fallback base URL aktif (server live).
  static const baseUrl = 'https://freecinenewph.t62nds.com';
  static const fallbackBaseUrl = 'https://freecinenewph.t62nds.com';
  static const cdnBaseUrl = 'http://movieph.xrrqe.com';
  static const secretToken = 'gcAIKnfz';
  /// Kunci enkripsi CDN CloudFront Wangsu hasil teardown biner libpp_hls.so
  static const cdnSecretKey = '00b5f05c40b4f1d91dbc9b3fd8a059ef';
  /// Port internal mandiri LiveGo (7055) agar 100% mandiri tanpa konflik app lain
  static const localProxyPort = 7055;
  static const localProxyBaseUrl = 'http://127.0.0.1:7055';

  /// Auto-register credentials (server accepts any unique device_id)
  static const autoRegisterUsername = 'livego_user';
  static const autoRegisterPassword = 'livego_pass_2026';

  /// Active Session Token & Device ID (dari SharedPreferences CinemaID asli)
  static const defaultDeviceId = 'c47dc57a04dd5a3e';
  static const defaultToken =
      'gAAAAABqy7SFYbBIk_lFNUwVrxyi599MRGv8JY7F8nqIm77Q7zvRgytSKrANFp3ti8W9WXNW8VWv1SC6xsiW2tMjesCUHbbgHEzIcWS5YYzZhfKeTgFJi1Et0fIZXHnhz76X8M3rumwBWsDVzRQvUQwS8iKesbBDEFFLe_uTP2kJyQUN0SVQFFhgM2iC8DntLJ7UTWXUtxGiti5t99PfDV6x4-vJNrvsyCCo-UB4tKg2ST6elThyWJR8JI-UEjZUin_do5hWpBFC';

  /// Path init (tanpa prefix /api, client yang menambahkan).
  static const initPath = '/public/init';

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; M2010J19CG Build/TKQ1.221114.001) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  static const referer = 'https://www.playvibes.example/';

  static const timeout = Duration(seconds: 15);

  /// Kategori bawaan CinemaID sesuai aplikasi asli (10 tab platform OTT):
  /// Tiap tab = 1 daftar utuh (Top 10 provider di paling atas, disusul katalog
  /// lengkap provider tersebut). Tidak dipisah, tidak campur antar platform.
  /// 18+ menghimpun semua konten dewasa di tab sendiri.
  static const categories = <String>[
    'Netflix',
    'Amazon Prime',
    'Apple TV+',
    'Disney+ Hotstar',
    'Vidio',
    'Vivamax',
    'Viu',
    'iFlix',
    'Crunchyroll',
    '18+',
  ];

  /// Taruh token auth sebagai header DAN query param.
  /// Dari static analysis penempatan pastinya tidak jelas;
  /// mengirim keduanya aman dan kompatibel dengan kedua gaya.
  static const sendTokenAsHeader = true;
  static const sendTokenAsQuery = true;
  static const tokenQueryKey = 'token';
}
