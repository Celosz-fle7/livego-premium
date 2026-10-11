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
  static const localProxyBaseUrl = 'http://127.0.0.1:7000';

  /// Auto-register credentials (server accepts any unique device_id)
  static const autoRegisterUsername = 'livego_user';
  static const autoRegisterPassword = 'livego_pass_2026';

  /// Path init (tanpa prefix /api, client yang menambahkan).
  static const initPath = '/public/init';

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 13; M2010J19CG Build/TKQ1.221114.001) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/120.0.0.0 Mobile Safari/537.36';

  static const timeout = Duration(seconds: 15);

  /// Kategori bawaan CinemaID terkelompok rapi:
  /// 1. Kategori Kurasi & Ranking Inti (Trending, Top 10 Film/Series, Box-Office, dll)
  /// 2. Platform & Provider OTT (Netflix, Vidio, Vivamax, Amazon Prime, Disney+ Hotstar, dll)
  /// 3. Universe & Studio Franchise (Marvel, DC)
  static const categories = <String>[
    // --- Kategori Inti: Kurasi & Ranking ---
    'Trending',
    '10 Klik Teratas Film',
    '10 Klik Teratas Series',
    'Netflix Top 10',
    'Amazon Prime Top 10',
    'Apple Top 10',
    'Film Indonesia Populer',
    'Harus Dilihat Bulan Ini',
    'Box-Office',

    // --- Platform & Provider OTT ---
    'Netflix',
    'Vidio',
    'Vivamax',
    'Amazon Prime',
    'Disney+ Hotstar',
    'Viu',
    'iFlix',
    'Apple TV+',
    'Crunchyroll',

    // --- Franchise & Universe ---
    'Marvel',
    'DC',
  ];

  /// Taruh token auth sebagai header DAN query param.
  /// Dari static analysis penempatan pastinya tidak jelas;
  /// mengirim keduanya aman dan kompatibel dengan kedua gaya.
  static const sendTokenAsHeader = true;
  static const sendTokenAsQuery = true;
  static const tokenQueryKey = 'token';
}
