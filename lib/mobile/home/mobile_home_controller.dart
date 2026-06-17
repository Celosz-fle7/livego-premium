import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import 'mobile_home_state.dart';

class MobileHomeController {
  final ValueNotifier<MobileHomeState> state = ValueNotifier(MobileHomeState.initial());

  List<String> _platforms = [];

  String get selectedPlatformSlug {
    if (_platforms.isEmpty) return 'dobda_shortmax';
    final index = state.value.selectedPlatformIndex;
    return (index >= 0 && index < _platforms.length) ? _platforms[index] : _platforms.first;
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state.value = state.value.copyWith(loading: true);
    }

    try {
      _platforms = LiveGoCatalog.platforms.take(6).toList();
      final labels = LiveGoCatalog.labelsFor(_platforms);
      final slug = selectedPlatformSlug;

      final categories = await LiveGoCatalog.fetchCategoriesFor(slug);
      final selectedCatIndex = state.value.selectedCategoryIndex.clamp(0, categories.length - 1).toInt();
      final selectedCategory = categories.isEmpty ? 'Home' : categories[selectedCatIndex];

      // Load banners and items in parallel for efficiency.
      final results = await Future.wait([
        LiveGoCatalog.banners(platform: slug),
        LiveGoCatalog.homeByCategory(platform: slug, category: selectedCategory),
      ]);

      final banners = results[0] as List<ContentItem>;
      final items = results[1] as List<ContentItem>;

      state.value = state.value.copyWith(
        banners: banners,
        items: items,
        categories: categories,
        platformLabels: labels,
        loading: false,
      );
    } catch (e) {
      debugPrint('MOBILE HOME LOAD ERROR: $e');
      state.value = state.value.copyWith(loading: false);
    }
  }

  void selectPlatform(int index) {
    if (index == state.value.selectedPlatformIndex) return;
    state.value = state.value.copyWith(
      selectedPlatformIndex: index,
      selectedCategoryIndex: 0,
    );
    load();
  }

  void selectCategory(int index) {
    if (index == state.value.selectedCategoryIndex) return;
    state.value = state.value.copyWith(selectedCategoryIndex: index);
    load();
  }

  void dispose() {
    state.dispose();
  }
}
