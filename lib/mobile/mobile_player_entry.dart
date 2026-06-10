import 'package:flutter/material.dart';

import '../models/content_item.dart';
import 'screens/mobile_player_screen.dart';

class MobilePlayerEntry {
  const MobilePlayerEntry._();

  static Future<void> open(
    BuildContext context, {
    required ContentItem item,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MobilePlayerScreen(item: item),
      ),
    );
  }
}
