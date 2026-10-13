import '../../models/content_item.dart';

/// Taksonomi filter MovieBox ShortTV — dari panel filter aplikasi resmi:
/// "Kata kunci" + "Genre" (di "Lebih banyak filter").
/// Label Indonesia -> keyword Inggris (konten API berjudul Inggris).
/// Filter memfilter hasil yang sudah ada, BUKAN mencari (sama seperti
/// filter genre FreeReels).
class MovieBoxFilters {
  /// Kata kunci (panel "Kata kunci" di aplikasi).
  static const Map<String, String> keywordTags = {
    'CEO': 'ceo',
    'Sweet Love': 'sweet love',
    'Hidden Identity': 'hidden identity',
    'Lemah menjadi Kuat': 'weak to strong',
    'Pembalasan dendam': 'revenge',
    'Wanita kuat': 'strong female',
    'Bayi Lucu': 'cute baby',
    'Abusive Love': 'abusive',
    'Love After Marriage': 'love after marriage',
    'Werewolf&Vampire': 'werewolf',
  };

  /// Genre (panel "Lebih banyak filter" > Genre di aplikasi).
  static const Map<String, String> genreTags = {
    'Modern': 'modern',
    'Perjalanan Waktu': 'time travel',
    'Zaman': 'historical',
    'Fantasi': 'fantasy',
    'Keluarga': 'family',
    'Ketegangan': 'thriller',
  };

  /// Semua label filter MovieBox (kata kunci + genre).
  static Iterable<String> get allLabels => [...keywordTags.keys, ...genreTags.keys];

  /// Keyword untuk satu label (kata kunci dulu, lalu genre). Null kalau
  /// label bukan milik MovieBox.
  static String? keywordFor(String label) => keywordTags[label] ?? genreTags[label];

  /// Item lolos kalau tag/judul/deskripsi/kategori mengandung label ATAU
  /// keyword salah satu filter yang dipilih.
  static bool matches(ContentItem item, Set<String> selectedLabels) {
    if (selectedLabels.isEmpty) return true;
    final hay =
        '${item.tags.join(' ')} ${item.title} ${item.description} ${item.category}'.toLowerCase();
    for (final label in selectedLabels) {
      if (hay.contains(label.toLowerCase())) return true;
      final keyword = keywordFor(label);
      if (keyword != null && hay.contains(keyword.toLowerCase())) return true;
    }
    return false;
  }
}
