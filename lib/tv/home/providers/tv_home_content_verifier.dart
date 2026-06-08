import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/livego_catalog.dart';
import '../../../models/content_item.dart';
import '../../../services/content/content_health_service.dart';

class TvHomeContentVerifier {
  TvHomeContentVerifier._();

  static const int maxItemsPerBatch = 10;
  static const Duration startDelay = Duration(milliseconds: 1200);
  static const Duration detailTimeout = Duration(seconds: 5);
  static const Duration episodeTimeout = Duration(seconds: 6);
  static const Duration perItemGap = Duration(milliseconds: 110);
  static const Duration verifiedCooldown = Duration(hours: 6);

  static final Map<String, DateTime> _verifiedAt = <String, DateTime>{};
  static final Set<String> _running = <String>{};
  static Timer? _timer;
  static bool _busy = false;
  static List<ContentItem> _pending = const <ContentItem>[];

  static void schedule(
    Iterable<ContentItem> rows, {
    String source = 'home',
  }) {
    final items = <ContentItem>[];
    final seen = <String>{};

    for (final item in rows) {
      if (!ContentHealthService.isValidFeedItem(item)) continue;

      final key = ContentHealthService.contentKey(item);
      if (!seen.add(key)) continue;
      if (_running.contains(key)) continue;
      if (_recentlyVerified(key)) continue;

      items.add(item);
      if (items.length >= maxItemsPerBatch) break;
    }

    if (items.isEmpty) return;

    _pending = items;
    _timer?.cancel();
    _timer = Timer(startDelay, () {
      unawaited(_run(source));
    });
  }

  static bool _recentlyVerified(String key) {
    final at = _verifiedAt[key];
    if (at == null) return false;
    return DateTime.now().difference(at) < verifiedCooldown;
  }

  static Future<void> _run(String source) async {
    if (_busy) return;
    final items = _pending;
    if (items.isEmpty) return;

    _busy = true;
    _pending = const <ContentItem>[];

    try {
      for (final item in items) {
        final key = ContentHealthService.contentKey(item);
        if (_running.contains(key) || _recentlyVerified(key)) continue;

        _running.add(key);
        try {
          await _verifyOne(item, source: source);
        } finally {
          _running.remove(key);
        }

        await Future<void>.delayed(perItemGap);
      }
    } finally {
      _busy = false;
    }
  }

  static Future<void> _verifyOne(
    ContentItem item, {
    required String source,
  }) async {
    final key = ContentHealthService.contentKey(item);

    bool? detailOk;
    bool? episodesOk;

    try {
      final detail = await LiveGoCatalog.detail(item).timeout(detailTimeout);
      detailOk = ContentHealthService.isValidFeedItem(detail);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('TV HOME VERIFY detail skip key=$key source=$source error=$error');
      }
      detailOk = null;
    }

    try {
      final episodes = await LiveGoCatalog.episodes(item).timeout(episodeTimeout);
      episodesOk = episodes.any((episode) => episode.index > 0 || episode.id.trim().isNotEmpty);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('TV HOME VERIFY episodes skip key=$key source=$source error=$error');
      }
      episodesOk = null;
    }

    if (detailOk == true || episodesOk == true) {
      _verifiedAt[key] = DateTime.now();
      await ContentHealthService.markPlayable(item);
      if (kDebugMode) debugPrint('TV HOME VERIFY OK key=$key source=$source detail=$detailOk episodes=$episodesOk');
      return;
    }

    // Only block when both checks returned a real negative result.
    // Unknown/timeout/network errors stay visible and will be retried later.
    if (detailOk == false && episodesOk == false) {
      await ContentHealthService.markBroken(
        item,
        reason: 'detail kosong / episode list kosong',
        days: 7,
        failCount: 1,
      );
      if (kDebugMode) debugPrint('TV HOME VERIFY BLOCK key=$key source=$source');
    }
  }
}
