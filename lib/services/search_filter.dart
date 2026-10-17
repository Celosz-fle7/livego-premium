import '../models/content_item.dart';
import 'freereels/freereels_config.dart';
import 'moviebox/moviebox_filters.dart';
import 'shortdrama/shortdrama_filters.dart';

/// Filter hasil pencarian — MASING-MASING PROVIDER PUNYA FILTER SENDIRI,
/// tidak dicampur. FreeReels pakai genre FreeReels, MovieBox pakai kata
/// kunci + genre MovieBox, ShortDrama pakai genre + Sulih Suara,
/// provider lain tanpa filter (row disembunyikan).
/// Filter memfilter hasil yang sudah ada, BUKAN mencari.
class SearchFilter {
  /// Label filter milik satu provider. Kosong = provider tidak punya filter.
  /// [platformSlug] null = Semua Source (tidak ada satu provider).
  static List<String> labelsFor(String? platformSlug) {
    switch (platformSlug) {
      case 'freereels':
        return FreereelsConfig.genreTags.keys.toList();
      case 'moviebox':
        return MovieBoxFilters.allLabels.toList();
      case 'shortdrama':
        return ShortDramaFilters.allLabels;
      default:
        return const [];
    }
  }

  static bool matches(
    String? platformSlug,
    ContentItem item,
    Set<String> selectedLabels,
  ) {
    if (selectedLabels.isEmpty) return true;
    switch (platformSlug) {
      case 'freereels':
        return FreereelsConfig.matchesGenres(item, selectedLabels);
      case 'moviebox':
        return MovieBoxFilters.matches(item, selectedLabels);
      case 'shortdrama':
        return ShortDramaFilters.matches(item, selectedLabels);
      default:
        return true;
    }
  }

  static List<ContentItem> filter(
    String? platformSlug,
    List<ContentItem> items,
    Set<String> selectedLabels,
  ) {
    if (selectedLabels.isEmpty) return items;
    return items
        .where((item) => matches(platformSlug, item, selectedLabels))
        .toList();
  }
}
