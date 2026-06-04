import 'package:flutter/material.dart';

import '../../models/content_item.dart';
import '../screens/tv_content_detail_screen.dart';

class TvDetailRoute {
  const TvDetailRoute._();

  static Future<void> open(
    BuildContext context, {
    required ContentItem item,
    VoidCallback? onPlayerRouteOpen,
    VoidCallback? onPlayerRouteClosed,
  }) {
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
