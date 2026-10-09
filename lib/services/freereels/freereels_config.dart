/// Konfigurasi client FreeReels — meniru persis perilaku APK mod.
///
/// SALT: satu-satunya nilai statis. Isi lewat:
///   flutter build apk --dart-define=FREEREELS_SALT=xxx
/// atau edit defaultValue di bawah (lalu private-kan repo).
/// Nilai: lihat script Python get_all_pages.py (SALT).
///
/// authKey/authSecret: JANGAN di-hardcode — didapat runtime dari
/// POST /anonymous/login (persis flow APK), disimpan di SharedPreferences.
class FreereelsConfig {
  static const String salt = String.fromEnvironment(
    'FREEREELS_SALT',
    defaultValue: '8IAcbWyCsVhYv82S2eofRqK1DF3nNDAv',
  );

  // === Identitas app — JANGAN DIRUBAH (meniru APK) ===
  static const String baseUrl = 'https://apiv2.free-reels.com';
  static const String apiPrefix = '/frv2-api';
  static const String appName = 'com.freereels.app';
  static const String appVersion = '2.2.00';
  static const String userAgent = 'okhttp/4.12.0';

  // === Device spoof — meniru script Python (JANGAN DIRUBAH) ===
  static const String device = 'android';
  static const String language = 'en';
  static const String country = 'US';
  static const String deviceModel = 'Pixel 6';
  static const String screenWidth = '1080';
  static const String screenHeight = '2400';

  static const Duration timeout = Duration(seconds: 15);

  /// Tab key bawaan APK (dari script Python).
  static const Map<String, String> tabKeys = {
    'Popular': '503',
    'New': '505',
    'Coming Soon': '622',
    'Dubbing': '514',
    'Female': '504',
    'Male': '506',
    'Anime': '547',
  };

  /// Genre tags dari layar preferensi APK (untuk discovery via search).
  /// Key = label Indonesia (tampil di UI), value = keyword Inggris (untuk API).
  static const Map<String, String> genreTags = {
    'Balas Dendam': 'revenge',
    'Identitas Rahasia': 'secret identity',
    'Identitas Salah': 'mistaken identity',
    'Pengkhianatan': 'betrayal',
    'Serangan Balik': 'counterattack',
    'Cinta Satu Malam': 'one night',
    'Terlahir Kembali': 'rebirth',
    'Fantasi': 'fantasy',
    'Misteri': 'mystery',
    'Romansa': 'romance',
    'Sci-Fi': 'sci-fi',
    'Perkotaan': 'urban',
    'Sejarah Alternatif': 'alternate history',
    'Drama': 'drama',
    'Drama Keluarga': 'family drama',
    'Keluarga': 'family',
    'Wanita Kuat': 'strong female',
    'Romansa Manis': 'sweet romance',
  };
}
