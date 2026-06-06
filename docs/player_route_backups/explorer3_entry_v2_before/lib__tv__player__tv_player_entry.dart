import 'package:flutter/material.dart';

import '../../models/content_item.dart';
import '../screens/tv_basic_player_screen.dart';

class TvPlayerEntry {
  const TvPlayerEntry._();

  static Future<void> open(
    BuildContext context, {
    required ContentItem item,
    int? episode,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => TvBasicPlayerScreen(
          item: item,
          episode: episode,
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }
}
