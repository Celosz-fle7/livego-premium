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

  /// Kategori resmi Melolo yang diverifikasi menghasilkan ratusan konten
  static const List<String> categories = [
    'Romance',
    'Billionaire',
    'Rebirth',
    'Male Lead',
    'Counterattack',
    'Fantasy',
    'Love After Marriage',
    'Paranormal',
    'Mystery',
    'Teen Fic',
    'Modern Love',
    'CEO',
  ];

  /// Mapping nama kategori ke query pencarian Melolo
  static const Map<String, String> categoryQueryMap = {
    'Romance': 'Romantic',
    'Billionaire': 'Billionaire',
    'Rebirth': 'Rebirth',
    'Male Lead': 'Male Lead',
    'Counterattack': 'Counterattack',
    'Fantasy': 'Fantasy',
    'Love After Marriage': 'Love After Marriage',
    'Paranormal': 'Paranormal',
    'Mystery': 'Mystery',
    'Teen Fic': 'Teen Fic',
    'Modern Love': 'Modern Love',
    'CEO': 'CEO',
  };
}
