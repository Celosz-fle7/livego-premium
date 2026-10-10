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
  static const String aid = '645713';
  static const String deviceId = '7514640337227908615';
  static const String iid = '7685755891161237255';
  static const String appName = 'melolo';
  static const String versionCode = '53018';
  static const String versionName = '5.3.0';
  static const String devicePlatform = 'android';
  static const String language = 'id';
  static const String appLanguage = 'id';
  static const String deviceBrand = 'Infinix';
  static const String osApi = '34';
  static const String channel = 'google_play';
  static const String appRegion = 'US';
  static const String carrierRegion = 'US';
  static const String carrierRegionV2 = 'US';
  static const String currentRegion = 'US';

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

  /// Mapping nama kategori ke query pencarian Melolo yang terbukti mengembalikan katalog melimpah
  static const Map<String, String> categoryQueryMap = {
    // Menu Filter Beranda Utama
    'Populer': 'Hot',
    'Anime': 'Anime',
    'Peringkat': 'Best',
    'Rakyat Jelata': 'Commoner',
    'Putri Yang Tertukar': 'Real and Fake Daughter',
    'Anak Kesayangan': 'Beloved Child',
    'Romansa Urban': 'Urban Romance',
    'Fantasi Perkotaan': 'Urban Fantasy',
    'Romansa Klasik': 'Classic Romance',

    // Tag Preferensi Resmi APK
    'Cinta yang manis': 'Romantic',
    'Cinta modern': 'Metropolitan',
    'Bayi Lucu': 'Cute baby',
    'Cinta yang pahit': 'Bitter love',
    'Pemeran Utama Wanita Kuat': 'Strong Female Lead',
    'Mafia': 'Mafia',
    'CEO': 'Billionaire',
    'Identitas Tersembunyi': 'Hidden Identity',
    'Kelahiran kembali (Rebirth)': 'Rebirth',
    'Harem': 'Harem',
    'Horor / Thriller': 'Thriller',
    'Menantu': 'Son in law',
    'Cinta Setelah Pernikahan': 'Love After Marriage',
  };
}
