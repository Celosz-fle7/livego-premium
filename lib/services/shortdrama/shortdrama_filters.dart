import '../../models/content_item.dart';

/// Filter ShortDrama TV.
///
/// Server anonim mengabaikan semua param filter di /api/search/screen
/// (audience, background, theme, sort, type_pid, years, local — sudah
/// diuji, hasilnya selalu 20 item yang sama). Karena itu filter dilakukan
/// di client, sama seperti FreeReels.
///
/// Dua hal yang difilter:
///   1. Genre (dari field `theme` item, mis. "Venganza,Traición,Romance").
///   2. Sulih suara / dubbing (item yang namanya bertanda Doblado/Dublado,
///      atau tag-nya menyebut sulih suara / indonesia).
class ShortDramaFilters {
  ShortDramaFilters._();

  /// Genre asli server (Spanyol) -> label Indonesia.
  /// Diambil dari field `theme` item (24 genre unik terverifikasi).
  static const Map<String, String> genreLabels = {
    'Romance': 'Romansa',
    'Romance dulce': 'Romansa Manis',
    'Amor tormentoso': 'Cinta Penuh Luka',
    'Amor por contrato': 'Cinta Kontrak',
    'Matrimonio arreglado': 'Pernikahan Aransemen',
    'Matrimonio relámpago': 'Nikah Kilat',
    'Venganza': 'Balas Dendam',
    'Revancha': 'Balas Dendam',
    'Traición': 'Pengkhianatan',
    'Identidad oculta': 'Identitas Rahasia',
    'Renacimiento': 'Terlahir Kembali',
    'Superación': 'Bangkit dari Bawah',
    'Conflicto familiar': 'Konflik Keluarga',
    'CEO dominante': 'CEO Dominan',
    'Mafia': 'Mafia',
    'Máfia': 'Mafia',
    'Crimen': 'Kriminal',
    'Suspenso': 'Suspense',
    'Fantasía': 'Fantasi',
    'fantasia': 'Fantasi',
    'Fantasía creativa': 'Fantasi Kreatif',
    'Hombre lobo': 'Werewolf',
    'Vampiros': 'Vampir',
    'Dragones': 'Naga',
  };

  /// Kata kunci penanda sulih suara (nama item / tag).
  static const List<String> dubKeywords = [
    'doblado',
    'dublado',
    'dubbing',
    'sulih suara',
    'sulih',
    'suara',
    'indonesia',
  ];

  /// Label filter untuk UI (genre + Sulih Suara).
  static List<String> get allLabels => [
        'Sulih Suara',
        ...genreLabels.values.toSet(),
      ];

  /// Item ini sulih suara?
  static bool isDubbed(ContentItem item) {
    final hay = '${item.title} ${item.tags.join(' ')} ${item.description}'.toLowerCase();
    return dubKeywords.any(hay.contains);
  }

  /// Item punya genre [label] (label Indonesia)?
  static bool hasGenre(ContentItem item, String label) {
    final hay = '${item.tags.join(' ')} ${item.title}'.toLowerCase();
    // Cek label Indonesia langsung.
    if (hay.contains(label.toLowerCase())) return true;
    // Cek lewat pemetaan genre server -> label Indonesia.
    for (final entry in genreLabels.entries) {
      if (entry.value.toLowerCase() == label.toLowerCase() &&
          hay.contains(entry.key.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static bool matches(ContentItem item, Set<String> selectedLabels) {
    if (selectedLabels.isEmpty) return true;
    for (final label in selectedLabels) {
      if (label == 'Sulih Suara') {
        if (isDubbed(item)) return true;
      } else if (hasGenre(item, label)) {
        return true;
      }
    }
    return false;
  }

  static List<ContentItem> filter(
    List<ContentItem> items,
    Set<String> selectedLabels,
  ) {
    if (selectedLabels.isEmpty) return items;
    return items.where((e) => matches(e, selectedLabels)).toList();
  }

  /// Filter konten untuk kategori "Sulih Suara".
  /// Dipakai provider saat kategori itu dipilih (server tidak menyediakan
  /// channel dubbing yang bisa diakses anonim).
  static List<ContentItem> dubbedOnly(List<ContentItem> items) {
    return items.where(isDubbed).toList();
  }
}
