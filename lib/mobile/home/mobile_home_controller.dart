import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/nobuzero/nobuzero_http_client.dart';
import 'mobile_home_state.dart';

class MobileHomeController {
  final ValueNotifier<MobileHomeState> state = ValueNotifier(MobileHomeState.initial());

  List<String> _platforms = [];

  String get selectedPlatformSlug {
    if (_platforms.isEmpty) return 'nobuzero_shortmax';
    final index = state.value.selectedPlatformIndex;
    return (index >= 0 && index < _platforms.length) ? _platforms[index] : _platforms.first;
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      state.value = state.value.copyWith(loading: true, errorMessage: '');
    }

    try {
      _platforms = LiveGoCatalog.platforms.take(6).toList();
      final labels = LiveGoCatalog.labelsFor(_platforms);
      final slug = selectedPlatformSlug;

      final categories = await LiveGoCatalog.fetchCategoriesFor(slug);
      final selectedCatIndex = state.value.selectedCategoryIndex.clamp(0, categories.length - 1).toInt();
      final selectedCategory = categories.isEmpty ? 'Home' : categories[selectedCatIndex];

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
        errorMessage: '',
      );
    } catch (e) {
      debugPrint('MOBILE HOME LOAD ERROR: $e');

      String msg = 'Gagal memuat konten. Tarik layar untuk coba lagi.';
      if (e is LiveGoAuthConfigException) {
        msg = 'API belum dikonfigurasi. Build APK dengan USER_ID dan SECRET.';
      } else if (e is LiveGoAuthException) {
        msg = e.statusCode == 401
            ? 'Auth gagal / signature salah. Cek SECRET Anda.'
            : 'Akses platform ditolak oleh server (403).';
      }

      state.value = state.value.copyWith(
        loading: false,
        errorMessage: msg,
      );
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
