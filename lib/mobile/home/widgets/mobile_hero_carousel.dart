import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../models/content_item.dart';
import '../../../shared/widgets/hero_banner.dart';

class MobileHeroCarousel extends StatefulWidget {
  final List<ContentItem> items;
  final bool loading;
  final ValueChanged<ContentItem> onTap;

  const MobileHeroCarousel({
    super.key,
    required this.items,
    required this.loading,
    required this.onTap,
  });

  @override
  State<MobileHeroCarousel> createState() => _MobileHeroCarouselState();
}

class _MobileHeroCarouselState extends State<MobileHeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant MobileHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      index = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.items.length < 2) return;
      final next = (index + 1) % widget.items.length;
      if (_controller.hasClients) {
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.items.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFF23364A)),
        ),
      );
    }

    final items = widget.items;
    if (items.isEmpty) {
      return Container(
        height: 320,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFF243A54)),
        ),
        child: const Text(
          'Memuat banner gagal. Tarik layar untuk refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w800),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (v) => setState(() => index = v),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => widget.onTap(items[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: HeroBanner(item: items[i]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 13,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length > 5 ? 5 : items.length, (i) {
                final active = i == (index % (items.length > 5 ? 5 : items.length));
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.cyan : Colors.white38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
