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

  /// Penanda konten dewasa: kode produksi JAV, kata kunci eksplisit, dan
  /// tag 18+ dari server. Server MovieBox sesekali menyelipkan judul seperti
  /// ini ke feed umum, jadi item harus disaring sebelum ditampilkan.
  static final RegExp _adultCodePattern = RegExp(
    r'\b(?:[A-Z]{2,6})-?\d{2,5}\b',
  );

  static const List<String> _adultKeywords = [
    'hardcore',
    'porn',
    'xxx',
    'hentai',
    'jav',
    'uncensored',
    'adult',
    '18+',
    '18 plus',
    'erotic',
    'nude',
    'sex tape',
    'onlyfans',
    'bokep',
    'telanjang',
    'dewasa',
    'mesum',
    'cabul',
  ];

  /// Kode produksi yang dikenal (JAV) — dicocokkan apa adanya.
  static const List<String> _knownAdultCodes = [
    'meyd', 'vrtm', 'mimk', 'ssis', 'stars', 'abp', 'ipx', 'pred', 'jul',
    'miaa', 'dasd', 'adn', 'shkd', 'rctd', 'waaa', 'mide', 'mifd', 'sone',
    'snis', 'ssni', 'ofje', 'fsdss', 'start', 'hnd', 'jul', 'pppd', 'nkkd',
    'nsps', 'mukd', 'gvh', 'hbad', 'saba', 'achj', 'cawd', 'dvdms', 'mogi',
  ];

  /// True kalau item terindikasi konten dewasa dan harus disembunyikan.
  static bool isAdult(ContentItem item) {
    final hay =
        '${item.tags.join(' ')} ${item.title} ${item.description} ${item.category}'.toLowerCase();

    for (final k in _adultKeywords) {
      if (hay.contains(k)) return true;
    }

    // Kode produksi JAV yang dikenal (mis. "meyd-528", "vrtm 345").
    final lower = hay.replaceAll(RegExp(r'[\s_]+'), '-');
    for (final code in _knownAdultCodes) {
      if (RegExp('\\b$code-?\\d{2,5}\\b').hasMatch(lower)) return true;
    }

    // Pola umum kode produksi: 2-6 huruf kapital + 2-5 angka di judul asli.
    final titleUpper = item.title.toUpperCase();
    if (_adultCodePattern.hasMatch(titleUpper)) {
      final m = _adultCodePattern.firstMatch(titleUpper);
      final code = m?.group(0)?.toLowerCase().replaceAll('-', '') ?? '';
      for (final known in _knownAdultCodes) {
        if (code.startsWith(known)) return true;
      }
    }

    return false;
  }

  /// Buang semua item yang terindikasi konten dewasa.
  static List<ContentItem> stripAdult(List<ContentItem> items) {
    final out = <ContentItem>[];
    var dropped = 0;
    for (final item in items) {
      if (isAdult(item)) {
        dropped++;
        continue;
      }
      out.add(item);
    }
    if (dropped > 0) {
      // ignore: avoid_print
      print('MOVIEBOX FILTER: dropped $dropped adult item(s)');
    }
    return out;
  }
}
