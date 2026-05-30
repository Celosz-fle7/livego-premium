import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import 'livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';

class PosterCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback? onTap;
  final bool tv;

  const PosterCard({super.key, required this.item, this.onTap, this.tv = false});

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final width = widget.tv ? 138.0 : 150.0;
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final progress = LiveGoLocalStore.progressFor(widget.item)?.ratio ?? 0;
        final fav = LiveGoLocalStore.isFavorite(widget.item);
        return Focus(
          onKey: (node, event) {
            if (event is RawKeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
              widget.onTap?.call();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onFocusChange: (v) => setState(() => focused = v),
          child: AnimatedScale(
            scale: focused && widget.tv ? 1.045 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(18),
              focusColor: Colors.transparent,
              hoverColor: Colors.white10,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: focused ? AppTheme.cyan : Colors.transparent,
                            width: focused ? 3 : 0,
                          ),
                          boxShadow: focused
                              ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.38), blurRadius: 24)]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              widget.item.posterUrl.isEmpty
                                  ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 46))
                                  : LiveGoCachedImage(
                                      url: widget.item.posterUrl,
                                      fit: BoxFit.cover,
                                      role: LiveGoImageRole.poster,
                                      tv: widget.tv,
                                    ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color(0xAA020617)],
                                  ),
                                ),
                              ),
                              Positioned(top: 8, left: 8, child: _Badge(text: '${widget.item.episodes} Ep')),
                              if (widget.item.updated) const Positioned(top: 8, right: 8, child: _Badge(text: 'UPDATE')),
                              if (fav) const Positioned(right: 8, top: 38, child: _RoundIcon(icon: Icons.favorite_rounded)),
                              Positioned(right: 8, bottom: 12, child: _Badge(text: widget.item.rating.toStringAsFixed(1))),
                              if (progress > 0)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: Colors.white12,
                                    valueColor: const AlwaysStoppedAnimation(AppTheme.cyan),
                                  ),
                                ),
                            ],
                          ),
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
                        color: focused ? Colors.white : Colors.white,
                        fontSize: widget.tv ? 13 : 13,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  const _RoundIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
      child: Icon(icon, color: AppTheme.cyan, size: 15),
    );
  }
}
