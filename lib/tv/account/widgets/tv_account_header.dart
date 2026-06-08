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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: focused
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppTheme.surface3.withOpacity(0.98),
                  AppTheme.surface2.withOpacity(0.88),
                ],
              )
            : null,
        color: focused ? null : AppTheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.74), width: focused ? 2.1 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.09), blurRadius: 16)] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withOpacity(focused ? 0.22 : 0.13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.whiteGlow.withOpacity(focused ? 0.42 : 0.20)),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Akun LiveGo', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 4),
                Text('Default: ${LiveGoSettings.defaultPlatform} • Bahasa: ${LiveGoSettings.language.toUpperCase()} • TV Remote Mode', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSoft.withOpacity(focused ? 0.92 : 0.76), fontSize: 11.4, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
              ],
            ),
          ),
          const TvAccountMiniStat(kind: TvAccountMiniStatKind.history, label: 'Riwayat'),
          const SizedBox(width: 8),
          const TvAccountMiniStat(kind: TvAccountMiniStatKind.favorite, label: 'Favorit'),
        ],
      ),
    );

    final wrapped = InkWell(
      canRequestFocus: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      focusColor: Colors.transparent,
      child: content,
    );

    if (height == null) return wrapped;
    return SizedBox(height: height, child: wrapped);
  }
}
