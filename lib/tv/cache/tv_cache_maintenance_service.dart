import 'package:flutter/painting.dart';

import '../../services/cache/livego_cache_observer.dart';
import '../../services/cache/livego_content_cache.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../player/cache/tv_player_cache_manager.dart';
import 'tv_ram_cache.dart';
import 'tv_runtime_cache.dart';

class TvCacheMaintenanceResult {
  final List<String> clearedItems;
  final Map<String, Object> failedItems;

  const TvCacheMaintenanceResult({
    required this.clearedItems,
    required this.failedItems,
  });

  bool get hasFailure => failedItems.isNotEmpty;

  String get message {
    if (hasFailure) {
      return 'Cache sementara berhasil dibersihkan sebagian: ${clearedItems.length} sukses, ${failedItems.length} gagal. Data pengguna tetap aman.';
    }
    return 'Cache sementara berhasil dibersihkan (${clearedItems.length} domain). Riwayat, favorit, progress, settings, dan unduhan manual tidak dihapus.';
  }
}

class TvCacheMaintenanceService {
  const TvCacheMaintenanceService._();

  static Future<TvCacheMaintenanceResult> clearAll() async {
    final cleared = <String>[];
    final failed = <String, Object>{};

    LiveGoCacheObserver.log(
      'cache_cleanup_start',
      domain: 'maintenance',
      reason: 'temporary_cache_only_user_data_preserved',
    );

    Future<void> run(
      String label,
      String domain,
      Future<void> Function() action,
    ) async {
      try {
        await action();
        cleared.add(label);
        LiveGoCacheObserver.log('cache_cleanup_done', domain: domain, reason: label);
      } catch (error) {
        failed[label] = error;
        LiveGoCacheObserver.log('cache_cleanup_failed', domain: domain, reason: '$label: $error');
      }
    }

    await run('Home cache expired/manifest', 'home', () async {
      await LiveGoContentCache.clearHomeCache();
    });

    await run('Player cache expired/runtime', 'player', () async {
      TvPlayerCacheManager.clearAll();
      await LiveGoContentCache.clearPlayerCache();
    });

    await run('Image RAM cache', 'image', () async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });

    await run('LiveGo bounded image disk cache', 'image', () async {
      await LiveGoImageCacheManager.instance.emptyCache();
    });

    await run('TV RAM cache sementara', 'ram', () async {
      TvRamCache.instance.clearAll();
    });

    await run('TV runtime cache sementara', 'runtime', () async {
      TvRuntimeCache.clearAll();
    });

    await run('Search cache sementara', 'search', () async {
      await LiveGoContentCache.clearSearchCache();
    });

    LiveGoCacheObserver.log(
      'cache_cleanup_done',
      domain: 'maintenance',
      itemCount: cleared.length,
      reason: failed.isEmpty ? 'success_user_data_preserved' : 'partial_user_data_preserved',
    );

    return TvCacheMaintenanceResult(
      clearedItems: List<String>.unmodifiable(cleared),
      failedItems: Map<String, Object>.unmodifiable(failed),
    );
  }
}
