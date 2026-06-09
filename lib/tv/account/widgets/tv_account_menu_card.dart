import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../tv_account_menu_data.dart';

class TvAccountMenuCard extends StatelessWidget {
  final TvAccountMenuItem item;
  final bool focused;
  final double height;
  final VoidCallback onTap;

  const TvAccountMenuCard({
    super.key,
    required this.item,
    required this.focused,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: AppTheme.cyan.withOpacity(0.10),
        highlightColor: AppTheme.cyan.withOpacity(0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: focused
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.surface3.withOpacity(0.98),
                      AppTheme.surface2.withOpacity(0.92),
                      AppTheme.bgGlow.withOpacity(0.88),
                    ],
                  )
                : null,
            color: focused ? null : AppTheme.surface.withOpacity(0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: focused
                  ? AppTheme.whiteGlow
                  : AppTheme.borderSoft.withOpacity(0.72),
              width: focused ? 2.2 : 1,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: AppTheme.cyan.withOpacity(0.12),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: AppTheme.purple.withOpacity(0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: focused
                      ? AppTheme.cyan.withOpacity(0.18)
                      : AppTheme.surface2.withOpacity(0.80),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: focused
                        ? AppTheme.whiteGlow.withOpacity(0.46)
                        : Colors.white10,
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: focused ? AppTheme.whiteGlow : Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: focused ? Colors.white : AppTheme.text,
                              fontSize: 18.4,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: focused
                                ? AppTheme.cyan.withOpacity(0.13)
                                : Colors.white.withOpacity(0.045),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: focused
                                  ? AppTheme.whiteGlow.withOpacity(0.34)
                                  : Colors.white10,
                            ),
                          ),
                          child: Text(
                            item.badge,
                            style: TextStyle(
                              color:
                                  focused ? AppTheme.cyan : AppTheme.textSoft,
                              fontSize: 9.4,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textSoft.withOpacity(
                          focused ? 0.92 : 0.74,
                        ),
                        fontSize: 12.6,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
