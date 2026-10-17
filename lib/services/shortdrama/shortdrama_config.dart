/// Konfigurasi API ShortDrama TV (com.shortdramatv.rlles).
///
/// Hasil reverse engineering APK 1.7.5 (versionCode 17500):
/// - Host konten : https://oyrg6c.1x6e0.top  (res/values/strings.xml main_host)
/// - CDN video   : https://bxdgpro.hfbjz.top
/// - Request     : plaintext JSON + header sign MD5
/// - Response    : Base64(AES-256-CBC) -> didekripsi di client
///
/// Catatan: sdkapi-ga.dramasheel.com BUKAN host konten (itu SDK iklan,
/// 404 untuk /api/*). Host konten diambil dari main_host + config init.
class ShortDramaConfig {
  ShortDramaConfig._();

  // === Host ===
  static const String baseUrl = 'https://oyrg6c.1x6e0.top';
  static const List<String> fallbackHosts = [
    'https://oyrg6c.1x6e0.top',
  ];
  static const String cdnBase = 'https://bxdgpro.hfbjz.top';

  // === Identitas app (meniru APK) ===
  static const String appId = 'shortdrama';
  static const String channelCode = 'shortdrama_sp10';
  static const String packageName = 'com.shortdramatv.rlles';
  static const String versionCode = '17500';
  static const String sysRelease = '13';
  static const String sysPlatform = '2';
  static const String languageId = '9';
  static const String languageCode = 'id';
  static const String timezoneId = 'Asia/Jakarta';
  static const String timezoneName = 'WIB';
  static const String resolution = '1080*2340';
  static const String mobManufacturer = 'Xiaomi';
  static const String mobModel = 'RedmiNote8';

  /// Device id: android_id perangkat. Kalau kosong/placeholder, pakai default.
  static const String defaultDeviceId = '10924b367b649bf3';

  // === Sign request ===
  /// Salt dari interceptor ortma.vfito.F4kw7A.
  /// sign = MD5(salt + deviceId + curTimeMs).toUpperCase()
  static const String signSalt = 'zD9[bM4~sF4~uY2)';

  // === Enkripsi response (AESOperator) ===
  static const String aesKey = 'KZFbDSHx77mxYNkEdb4G1TBWdNn2sarj';
  static const String aesIv = '3GfiYWekKMYDpjHF';

  // === Sign video CDN (libut.so) ===
  /// wsSecret = md5(key + path + wsTime); wsTime = hex(unix seconds)
  static const String videoSignKey = '00b5f05c40b4f1d91dbc9b3fd8a059ef';

  // === Endpoint ===
  static const String epInit = '/api/public/init';
  static const String epChannelList = '/api/channel/get_list';
  static const String epChannelInfo = '/api/channel/get_info';
  static const String epTypeList = '/api/type/get_list';
  static const String epVodShortNew = '/api/vod_short/list_new';
  static const String epVideoResult = '/api/video/result';
  static const String epSearchResult = '/api/search/result';
  static const String epSearchSuggest = '/api/search/suggest';
  static const String epSearchHot = '/api/search/hot_search';
  static const String epSearchScreen = '/api/search/screen';
  static const String epSearchNewbieTop = '/api/search/newbie_top';
  static const String epSearchRecommendNew = '/api/search/recommend_new';
  static const String epTopicList = '/api/topic/list';
  static const String epTopicVodList = '/api/topic/vod_list';

  // === Kategori (channel bawaan APK) ===
  /// Nama tab APK asli (Indonesia). channel_id diisi runtime dari
  /// /api/channel/get_list; map di bawah hanya urutan tampil.
  static const List<String> categories = [
    'Populer',
    'Rilis Baru',
    'Sulih Suara',
    'Peringkat',
    'Kategori',
    'Wanita',
    'Pria',
  ];

  /// Terjemahan nama channel server (Spanyol/Inggris) -> label Indonesia.
  static const Map<String, String> channelNameMap = {
    'popular': 'Populer',
    'nuevo': 'Rilis Baru',
    'doblado': 'Sulih Suara',
    'ranking': 'Peringkat',
    'categorías': 'Kategori',
    'categorias': 'Kategori',
    'femenino': 'Wanita',
    'masculino': 'Pria',
    'new': 'Rilis Baru',
    'dubbed': 'Sulih Suara',
    'female': 'Wanita',
    'male': 'Pria',
    'categories': 'Kategori',
  };

  static const Duration timeout = Duration(seconds: 20);

  /// Bahasa audio video di CDN: 'id' untuk Indonesia, 'es' untuk Spanyol.
  /// Provider memakai bahasa dari show_collection_play_url, bukan hardcode.
  static const String videoLang = 'id';
}
