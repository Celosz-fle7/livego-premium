import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/livego_local_store.dart';

enum TvAccountMiniStatKind { history, favorite }

class TvAccountMiniStat extends StatelessWidget {
  final TvAccountMiniStatKind kind;
  final String label;

  const TvAccountMiniStat({
    super.key,
    required this.kind,
    required this.label,
  });

  String _value() {
    switch (kind) {
      case TvAccountMiniStatKind.history:
        return '${LiveGoLocalStore.history.length}';
      case TvAccountMiniStatKind.favorite:
        return '${LiveGoLocalStore.favorites.length}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        return Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: Column(
            children: [
              Text(_value(), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            ],
          ),
        );
      },
    );
  }
}
