/// Konfigurasi API Melolo (com.worldance.drama).
/// Berdasarkan reverse engineering APK dan rekaman trafik autentik:
/// - Host: https://api.tmtreader.com
/// - Param aid: 645713 (ByteDance)
/// - Endpoint discovery: /i18n_novel/search/page/v1/ (pencarian & kategori)
/// - Endpoint detail: /novel/player/video_detail/v1/
/// - Endpoint streaming: /novel/player/video_model/v1/
class MeloloConfig {
  MeloloConfig._();

  static const String baseUrl = 'https://api.tmtreader.com';
  static const String searchEndpoint = '/i18n_novel/search/page/v1/';
  static const String videoDetailEndpoint = '/novel/player/video_detail/v1/';
  static const String videoModelEndpoint = '/novel/player/video_model/v1/';

  // Header dan Device Identitas ByteDance yang terverifikasi
  // Header dan Device Identitas ByteDance yang autentik dari trafik live APK
  static const String aid = '645713';
  static const String deviceId = '7514640337227908615';
  static const String iid = '7685755891161237255';
  static const String appName = 'Melolo';
  static const String versionCode = '53018';
  static const String versionName = '5.3.0';
  static const String manifestVersionCode = '53018';
  static const String updateVersionCode = '51819';
  static const String devicePlatform = 'android';
  static const String os = 'android';
  static const String ssmix = 'a';
  static const String deviceType = 'Infinix X6870';
  static const String deviceBrand = 'Infinix';
  static const String osApi = '36';
  static const String osVersion = '16';
  static const String openudid = '2ff7dc8acf56f353';
  static const String resolution = '1080*2260';
  static const String dpi = '351';
  static const String channel = 'gp';
  static const String ac = 'wifi';
  static const String cdid = '7b024226-a24d-4ec4-80b9-6cf15a35a6a7';

  // Lokalisasi Indonesia (Bahasa Indonesia & Region ID)
  static const String language = 'id';
  static const String appLanguage = 'id';
  static const String sysLanguage = 'id';
  static const String userLanguage = 'id';
  static const String uiLanguage = 'id';
  static const String currentRegion = 'ID';
  static const String appRegion = 'ID';
  static const String sysRegion = 'ID';
  static const String carrierRegion = 'id';
  static const String carrierRegionV2 = '510';
  static const String mccMnc = '51010';
  static const String timeZone = 'Asia/Jakarta';

  static const String userAgent =
      'com.worldance.drama/53018 (Linux; U; Android 16; id; Infinix X6870; Build/BP2A.250605.031.A3; Cronet/TTNetVersion:57545f6e 2025-08-04 QuicVersion:ccae1727 2025-07-24)';

  static const Duration timeout = Duration(seconds: 15);

  /// Kategori & Filter resmi Melolo sesuai APK asli (Beranda & Tag Preferensi)
  static const List<String> categories = [
    'Populer',
    'Anime',
    'Peringkat',
    'Rakyat Jelata',
    'Putri Yang Tertukar',
    'Anak Kesayangan',
    'Romansa Urban',
    'Fantasi Perkotaan',
    'Romansa Klasik',
    'Cinta yang manis',
    'Cinta modern',
    'Bayi Lucu',
    'Cinta yang pahit',
    'Pemeran Utama Wanita Kuat',
    'Mafia',
    'CEO',
    'Identitas Tersembunyi',
    'Kelahiran kembali (Rebirth)',
    'Harem',
    'Horor / Thriller',
    'Menantu',
    'Cinta Setelah Pernikahan',
  ];

  /// Mapping kata kunci langsung Bahasa Indonesia yang terverifikasi menghasilkan drama lokal Melolo
  static const Map<String, String> categoryQueryMap = {
    // Menu Filter Beranda Utama
    'Populer': 'Populer',
    'Anime': 'Anime',
    'Peringkat': 'Peringkat',
    'Rakyat Jelata': 'Rakyat Jelata',
    'Putri Yang Tertukar': 'Putri Yang Tertukar',
    'Anak Kesayangan': 'Anak Kesayangan',
    'Romansa Urban': 'Romansa Urban',
    'Fantasi Perkotaan': 'Fantasi Perkotaan',
    'Romansa Klasik': 'Romansa Klasik',

    // Tag Preferensi Resmi APK
    'Cinta yang manis': 'Cinta yang manis',
    'Cinta modern': 'Cinta modern',
    'Bayi Lucu': 'Bayi Lucu',
    'Cinta yang pahit': 'Cinta yang pahit',
    'Pemeran Utama Wanita Kuat': 'Pemeran Utama Wanita Kuat',
    'Mafia': 'Mafia',
    'CEO': 'CEO',
    'Identitas Tersembunyi': 'Identitas Tersembunyi',
    'Kelahiran kembali (Rebirth)': 'Kelahiran kembali',
    'Harem': 'Harem',
    'Horor / Thriller': 'Horor',
    'Menantu': 'Menantu',
    'Cinta Setelah Pernikahan': 'Cinta Setelah Pernikahan',
  };
}
