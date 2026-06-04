import 'package:flutter/material.dart';

import '../../models/content_item.dart';
import '../screens/tv_content_detail_screen.dart';
import '../../services/analytics/livego_analytics.dart';

/// Satu pintu route untuk semua poster TV.
///
/// Home, Search, History, Favorite, Continue Watching, dan My List tidak lagi
/// membuka Player langsung. Semuanya masuk Detail Screen lewat kontrak ini.
class TvDetailRoute {
  const TvDetailRoute._();

  static Future<void> open(
    BuildContext context, {
    required ContentItem item,
    VoidCallback? onPlayerRouteOpen,
    VoidCallback? onPlayerRouteClosed,
  }) {
    LiveGoAnalytics.contentOpen(item.platformSlug, item.id, item.title);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TvContentDetailScreen(
          item: item,
          onPlayerRouteOpen: onPlayerRouteOpen,
          onPlayerRouteClosed: onPlayerRouteClosed,
        ),
      ),
    );
  }
}
