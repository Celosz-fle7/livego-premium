import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';

class TvSectionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final double height;
  final Widget child;

  const TvSectionBox({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.height,
    required this.child,
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
            Container(
              width: 96,
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.055)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cyan.withOpacity(0.18)),
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
                            color: TvFocusStyle.focusBlue.withOpacity(0.78),
                            fontSize: 8.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hint,
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
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
