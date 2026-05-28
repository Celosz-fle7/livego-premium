import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/content_item.dart';

class PosterCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final bool tv;

  const PosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.tv = false,
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final width = widget.tv ? 166.0 : 150.0;
    final card = AnimatedScale(
      scale: widget.tv && _focused ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        padding: EdgeInsets.all(widget.tv && _focused ? 3 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.tv && _focused ? AppTheme.cyan : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: widget.tv && _focused
              ? [
                  BoxShadow(
                    color: AppTheme.cyan.withOpacity(0.32),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: AppTheme.purple.withOpacity(0.22),
                    blurRadius: 36,
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.item.posterUrl.isEmpty
                        ? Container(
                            color: const Color(0xFF111827),
                            child: const Icon(Icons.movie_creation_rounded, color: Colors.white38),
                          )
                        : Image.network(
                            widget.item.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF111827),
                              child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                            ),
                          ),
                    Positioned(top: 8, left: 8, child: _Badge(text: '${widget.item.episodes} Ep')),
                    if (widget.item.updated) const Positioned(top: 8, right: 8, child: _Badge(text: 'UPDATE')),
                    Positioned(right: 8, bottom: 8, child: _Badge(text: widget.item.rating.toStringAsFixed(1))),
                    if (widget.tv && _focused)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.08),
                                AppTheme.cyan.withOpacity(0.08),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.tv ? 14 : 13,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.tv) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(width: width, child: card),
      );
    }

    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onTap,
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(width: width, child: card),
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
