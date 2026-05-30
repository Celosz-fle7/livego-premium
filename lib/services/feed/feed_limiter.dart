import 'dart:math';

import '../../models/content_item.dart';
import 'feed_config.dart';

class FeedLimiter {
  FeedLimiter._();

  static List<ContentItem> prepare(
    List<ContentItem> items, {
    required int visitSeed,
    int limit = FeedConfig.itemsPerCategory,
    bool shuffle = FeedConfig.shuffleOnReturn,
  }) {
    if (items.isEmpty) return const <ContentItem>[];

    final capped = items.take(limit).toList(growable: false);
    if (!shuffle || capped.length < 4 || visitSeed <= 1) {
      return capped;
    }

    final shuffled = List<ContentItem>.from(capped);
    shuffled.shuffle(Random(_stableSeed(visitSeed, capped)));
    return shuffled;
  }

  static int _stableSeed(int visitSeed, List<ContentItem> items) {
    var hash = visitSeed * 1000003;
    for (final item in items.take(8)) {
      hash = 0x1fffffff & (hash + item.id.hashCode + item.platformSlug.hashCode);
    }
    return hash;
  }
}
