import '../models/content_item.dart';
import 'freereels/freereels_config.dart';
import 'moviebox/moviebox_filters.dart';

/// Filter hasil pencarian — satu row chip untuk semua provider.
/// Label = gabungan genre FreeReels + kata kunci & genre MovieBox
/// (dedupe, FreeReels dulu lalu MovieBox).
/// Item lolos kalau cocok dengan matcher salah satu provider — jadi
/// label "Balas Dendam" memfilter item FreeReels MAUPUN MovieBox.
class SearchFilter {
  static List<String> get allLabels {
    final seen = <String>{};
    final out = <String>[];
    for (final label in [...FreereelsConfig.genreTags.keys, ...MovieBoxFilters.allLabels]) {
      if (seen.add(label.toLowerCase())) out.add(label);
    }
    return out;
  }

  static bool matches(ContentItem item, Set<String> selectedLabels) {
    if (selectedLabels.isEmpty) return true;
    return MovieBoxFilters.matches(item, selectedLabels) ||
        FreereelsConfig.matchesGenres(item, selectedLabels);
  }

  static List<ContentItem> filter(
    List<ContentItem> items,
    Set<String> selectedLabels,
  ) {
    if (selectedLabels.isEmpty) return items;
    return items.where((item) => matches(item, selectedLabels)).toList();
  }
}
