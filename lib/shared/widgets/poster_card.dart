import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/content_item.dart';

class PosterCard extends StatelessWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final bool tv;

  const PosterCard({super.key, required this.item, this.onTap, this.tv = false});

  @override
  Widget build(BuildContext context) {
    final width = tv ? 158.0 : 150.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(item.posterUrl, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(text: '${item.episodes} Ep'),
                    ),
                    if (item.updated)
                      const Positioned(top: 8, right: 8, child: _Badge(text: 'UPDATE')),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _Badge(text: item.rating.toStringAsFixed(1)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: tv ? 14 : 13,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
      ),
    );
  }
}
