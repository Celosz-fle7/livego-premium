import '../../models/content_item.dart';

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
  static const String appVersion = '2.3.70';
  static const String userAgent = 'okhttp/4.12.0';

  // === Device spoof — meniru APK terbaru (JANGAN DIRUBAH) ===
  static const String device = 'android';
  static const String language = 'id-ID';
  static const String country = 'ID';
  static const String deviceModel = 'Pixel 6';
  static const String screenWidth = '1080';
  static const String screenHeight = '2400';

  static const Duration timeout = Duration(seconds: 15);

  /// Tab key bawaan APK (dari script Python).
  /// New (505), Female (504), Male (506) DIHAPUS — tidak dipakai.
  /// Dubbing (514) = konten sulih suara, all genre.
  static const Map<String, String> tabKeys = {
    'Dubbing': '514',
    'Popular': '503',
    'Coming Soon': '622',
    'Anime': '547',
  };

  /// Genre tags dari APK untuk quick search (bukan kategori utama).
  /// Key = label Indonesia, value = keyword untuk search API.
  static const Map<String, String> genreTags = {
    'Balas Dendam': 'revenge',
    'Identitas Rahasia': 'secret identity',
    'Pengkhianatan': 'betrayal',
    'Serangan Balik': 'counterattack',
    'Cinta Satu Malam': 'one night love',
    'Terlahir Kembali': 'rebirth',
    'Fantasi': 'fantasy',
    'Misteri': 'mystery',
    'Romansa': 'romance',
    'Sci-Fi': 'sci-fi',
    'Perkotaan': 'urban',
    'Drama': 'drama',
    'Drama Keluarga': 'family drama',
    'Keluarga': 'family',
    'Wanita Kuat': 'strong female',
    'Romansa Manis': 'sweet romance',
  };

  /// Filter genre untuk hasil pencarian.
  ///
  /// Genre BUKAN untuk mencari — genre memfilter hasil yang sudah ada.
  /// Contoh: ketik "sulih suara" source FreeReels, lalu filter genre.
  /// `selectedLabels` kosong = "Semua" (tanpa filter).
  /// Item lolos kalau tag/judul/deskripsinya mengandung label ATAU
  /// keyword salah satu genre yang dipilih.
  static bool matchesGenres(ContentItem item, Set<String> selectedLabels) {
    if (selectedLabels.isEmpty) return true;
    final hay =
        '${item.tags.join(' ')} ${item.title} ${item.description}'.toLowerCase();
    for (final label in selectedLabels) {
      if (hay.contains(label.toLowerCase())) return true;
      final keyword = genreTags[label];
      if (keyword != null && hay.contains(keyword.toLowerCase())) return true;
    }
    return false;
  }

  /// Filter list hasil pencarian berdasarkan genre yang dipilih.
  /// `selectedLabels` kosong = "Semua" (kembalikan list apa adanya).
  static List<ContentItem> filterByGenres(
    List<ContentItem> items,
    Set<String> selectedLabels,
  ) {
    if (selectedLabels.isEmpty) return items;
    return items.where((item) => matchesGenres(item, selectedLabels)).toList();
  }
}
