import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';

class TvSectionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final double height;
  final Widget child;
  final VoidCallback? onHeaderTap;
  final FocusNode? headerFocusNode;
  final bool? headerFocusedOverride;
  final FocusOnKeyEventCallback? onHeaderKey;
  final VoidCallback? onHeaderFocus;

  const TvSectionBox({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.height,
    required this.child,
    this.onHeaderTap,
    this.headerFocusNode,
    this.headerFocusedOverride,
    this.onHeaderKey,
    this.onHeaderFocus,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF4071326), Color(0xF0010409)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSoft.withOpacity(0.92), width: 1.0),
          boxShadow: [
            const BoxShadow(color: Colors.black54, blurRadius: 11),
            BoxShadow(color: AppTheme.cyan.withOpacity(0.035), blurRadius: 18),
          ],
        ),
        child: Row(
          children: [
            _SectionHeaderButton(
              icon: icon,
              label: label,
              hint: hint,
              onTap: onHeaderTap,
              focusNode: headerFocusNode,
              focusedOverride: headerFocusedOverride,
              onKey: onHeaderKey,
              onFocus: onHeaderFocus,
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}


class _SectionHeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool? focusedOverride;
  final FocusOnKeyEventCallback? onKey;
  final VoidCallback? onFocus;

  const _SectionHeaderButton({
    required this.icon,
    required this.label,
    required this.hint,
    this.onTap,
    this.focusNode,
    this.focusedOverride,
    this.onKey,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    if (focusNode == null) return _buildButton(focused: false);
    return Focus(
      focusNode: focusNode,
      skipTraversal: true,
      onKeyEvent: onKey,
      onFocusChange: (focused) {
        if (focused) onFocus?.call();
      },
      child: ListenableBuilder(
        listenable: focusNode!,
        builder: (context, _) => _buildButton(focused: focusedOverride ?? focusNode!.hasFocus),
      ),
    );
  }

  Widget _buildButton({required bool focused}) {
    final interactive = onTap != null || focusNode != null;
    return InkWell(
      canRequestFocus: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 96,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: interactive
              ? AppTheme.cyan.withOpacity(focused ? 0.12 : 0.055)
              : Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused
                ? AppTheme.whiteGlow
                : (interactive ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(0.055)),
            width: focused ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(focused ? 0.18 : 0.11),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cyan.withOpacity(focused ? 0.34 : 0.18)),
              ),
              child: Icon(icon, color: AppTheme.cyan.withOpacity(0.92), size: 15),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: focused ? Colors.white : TvFocusStyle.focusBlue.withOpacity(0.78),
                      fontSize: 8.8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    focused ? 'OK buka' : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9.8,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
