import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/livego_settings.dart';
import 'tv_account_mini_stat.dart';

class TvAccountHeader extends StatelessWidget {
  final double? height;
  final bool focused;
  final VoidCallback? onTap;

  const TvAccountHeader({
    super.key,
    this.height,
    this.focused = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 1.8 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 18)] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(focused ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cyan.withOpacity(focused ? 0.55 : 0.26)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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

    final wrapped = InkWell(
      canRequestFocus: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      focusColor: Colors.transparent,
      child: content,
    );

    if (height == null) return wrapped;
    return SizedBox(height: height, child: wrapped);
  }
}
