import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../cache/tv_cache_maintenance_service.dart';

/// Central TV Cache & Storage Manager.
///
/// Ensures TV memory remains thin, never accumulates unbounded cache files,
/// and handles background prune without blocking UI frames.
class TvCacheManager {
  TvCacheManager._();
  static final TvCacheManager instance = TvCacheManager._();

  final ValueNotifier<bool> isCleaning = ValueNotifier<bool>(false);
  final ValueNotifier<String> lastStatus = ValueNotifier<String>('');

  /// Clear all temporary runtime caches while preserving user data
  /// (favorites, history, progress, local settings).
  Future<TvCacheMaintenanceResult> cleanTemporaryCache() async {
    if (isCleaning.value) {
      return const TvCacheMaintenanceResult(
        clearedItems: [],
        failedItems: {'busy': 'Pembersihan sedang berjalan'},
      );
    }

    isCleaning.value = true;
    lastStatus.value = 'Membersihkan cache...';

    try {
      final result = await TvCacheMaintenanceService.clearAll();
      lastStatus.value = result.message;
      return result;
    } catch (e) {
      lastStatus.value = 'Gagal membersihkan cache: $e';
      return TvCacheMaintenanceResult(
        clearedItems: [],
        failedItems: {'error': e},
      );
    } finally {
      isCleaning.value = false;
    }
  }
}
