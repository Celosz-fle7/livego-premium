import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../theme/tv_focus_style.dart';
import '../tv_account_menu_data.dart';

class TvAccountActionCard extends StatelessWidget {
  final FocusNode node;
  final TvAccountMenuItem item;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const TvAccountActionCard({
    super.key,
    required this.node,
    required this.item,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              constraints: const BoxConstraints(minHeight: 78),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.92), borderRadius: BorderRadius.circular(22), border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1), boxShadow: focused ? [TvFocusStyle.glow(0.07, 5)] : null),
              child: Row(
                children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(gradient: focused ? AppTheme.activeGradient : null, color: focused ? null : AppTheme.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: focused ? Colors.white.withOpacity(0.18) : AppTheme.borderSoft)), child: Icon(item.icon, color: focused ? Colors.white : AppTheme.cyan, size: 25)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const SizedBox(height: 4),
                      Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: focused ? AppTheme.cyan.withOpacity(0.16) : AppTheme.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.38) : AppTheme.borderSoft)), child: Text(item.badge, style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
