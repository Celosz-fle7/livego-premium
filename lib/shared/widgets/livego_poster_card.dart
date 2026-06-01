import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

import '../../models/livego_content.dart';
import 'livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';

class LiveGoPosterCard extends StatelessWidget {
  final LiveGoContent item;
  final VoidCallback? onTap;

  const LiveGoPosterCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.panelGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyan.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: item.cover.isEmpty
                  ? const ColoredBox(
                      color: AppTheme.surface2,
                      child: Center(
                        child: Icon(
                          Icons.movie,
                          color: Colors.white38,
                        ),
                      ),
                    )
                  : LiveGoCachedImage(
                      url: item.cover,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      role: LiveGoImageRole.poster,
                      errorWidget: const ColoredBox(
                        color: AppTheme.surface2,
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
