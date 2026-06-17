import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/livego_settings.dart';
import '../../../models/content_item.dart';
import '../../../shared/widgets/poster_card.dart';

class MobileHomeGrid extends StatelessWidget {
  final List<ContentItem> items;
  final bool loading;
  final String errorMessage;
  final ValueChanged<ContentItem> onTap;

  const MobileHomeGrid({
    super.key,
    required this.items,
    required this.loading,
    this.errorMessage = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grid = LiveGoSettings.mobileHomeGrid.clamp(2, 6);
    final posterHeight = grid <= 3 ? 250.0 : (grid == 4 ? 212.0 : 184.0);

    if (loading && items.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: grid * 2,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: grid,
          mainAxisExtent: posterHeight,
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (_, __) => const _Skeleton(radius: 16),
      );
    }

    if (errorMessage.isNotEmpty && items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF243A54)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSoft, height: 1.4, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF101826),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF243A54)),
        ),
        child: const Text(
          'Belum ada konten. Coba ganti platform/kategori atau ping source di Pengaturan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSoft, height: 1.4),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: grid,
        mainAxisExtent: posterHeight,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (_, i) => PosterCard(item: items[i], onTap: () => onTap(items[i])),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double radius;
  const _Skeleton({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF23364A)),
      ),
    );
  }
}
