import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
      return 'Cache berhasil dibersihkan sebagian: ${clearedItems.length} sukses, ${failedItems.length} gagal.';
    }
    return 'Semua cache berhasil dibersihkan (${clearedItems.length} item).';
  }
}

class TvCacheMaintenanceService {
  const TvCacheMaintenanceService._();

  static Future<TvCacheMaintenanceResult> clearAll() async {
    final cleared = <String>[];
    final failed = <String, Object>{};

    Future<void> run(String label, Future<void> Function() action) async {
      try {
        await action();
        cleared.add(label);
      } catch (error) {
        failed[label] = error;
      }
    }

    await run('Flutter image cache', () async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });

    await run('LiveGo TV RAM cache', () async {
      TvRamCache.instance.clearAll();
    });

    await run('LiveGo TV runtime cache', () async {
      TvRuntimeCache.clearAll();
    });

    await run('TV player cache manager', () async {
      TvPlayerCacheManager.clearAll();
    });

    await run('LiveGo content cache', () async {
      await LiveGoContentCache.clearAll();
    });

    await run('LiveGo image cache manager', () async {
      await LiveGoImageCacheManager.instance.emptyCache();
    });

    await run('Default network cache manager', () async {
      await DefaultCacheManager().emptyCache();
    });

    return TvCacheMaintenanceResult(
      clearedItems: List<String>.unmodifiable(cleared),
      failedItems: Map<String, Object>.unmodifiable(failed),
    );
  }
}
