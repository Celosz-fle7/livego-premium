import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

class MobileHomeSelectors extends StatelessWidget {
  final List<String> platforms;
  final int selectedPlatform;
  final ValueChanged<int> onPlatformSelected;

  final List<String> categories;
  final int selectedCategory;
  final ValueChanged<int> onCategorySelected;

  const MobileHomeSelectors({
    super.key,
    required this.platforms,
    required this.selectedPlatform,
    required this.onPlatformSelected,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OneLineSelector(
          title: 'Platform',
          items: platforms,
          selected: selectedPlatform,
          onSelected: onPlatformSelected,
        ),
        const SizedBox(height: 9),
        _OneLineSelector(
          title: 'Kategori',
          items: categories,
          selected: selectedCategory,
          onSelected: onCategorySelected,
        ),
      ],
    );
  }
}

class _OneLineSelector extends StatelessWidget {
  final String title;
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;

  const _OneLineSelector({
    required this.title,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Show up to 6 platforms/categories on Mobile Home
    final shown = items.take(6).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101826).withOpacity(0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22354D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSoft,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(shown.length, (i) {
              final active = i == selected;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 5),
                  child: GestureDetector(
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                        color: active ? null : const Color(0xFF172131),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: active ? Colors.transparent : const Color(0xFF2C405A)),
                      ),
                      child: Text(
                        shown[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active ? Colors.white : AppTheme.textSoft,
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
