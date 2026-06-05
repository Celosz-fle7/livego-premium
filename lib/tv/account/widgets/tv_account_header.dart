import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/livego_settings.dart';
import 'tv_account_mini_stat.dart';

class TvAccountHeader extends StatelessWidget {
  const TvAccountHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.26)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Akun LiveGo', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 5),
                Text('Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()} • TV Remote Mode', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
              ],
            ),
          ),
          const TvAccountMiniStat(kind: TvAccountMiniStatKind.history, label: 'Riwayat'),
          const SizedBox(width: 10),
          const TvAccountMiniStat(kind: TvAccountMiniStatKind.favorite, label: 'Favorit'),
        ],
      ),
    );
  }
}
