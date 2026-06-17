import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';
import '../../services/api/api_platform.dart';
import 'tv_player_service.dart';

class TvNativePlayerLauncher {
  static const MethodChannel _channel = MethodChannel('livego/native_player');
  static const TvPlayerService _playerService = TvPlayerService();

  const TvNativePlayerLauncher._();

  static Future<void> openBlackTest(ContentItem item) async {
    await _channel.invokeMethod<void>('openNativeBlackTest', <String, Object?>{
      'title': item.title,
      'platformSlug': item.platformSlug,
      'contentId': item.id,
    });
  }

  static Future<void> open(ContentItem item, {int? episode}) async {
    final ep = _episodeFor(item, episode);
    final playable = _playableItem(item, ep);
    final requestChapter = _isDobdaPlayer(playable)
        ? (playable.chapterId.trim().isNotEmpty ? playable.chapterId.trim() : '$ep')
        : '$ep';

    final resolved = await _playerService.resolveStream(
      playable,
      chapterId: requestChapter,
      episode: ep,
    );

    final stream = resolved.stream;
    final url = _bestUrl(stream);
    if (url.isEmpty) {
      throw StateError('URL video kosong dari stream resolver');
    }

    LiveGoLocalStore.addHistory(playable);

    await _channel.invokeMethod<void>('openNativePlayer', <String, Object?>{
      'url': url,
      'title': playable.title,
      'episode': ep,
      'quality': LiveGoSettings.quality,
      'headers': jsonEncode(stream.headers),
      'platformSlug': playable.platformSlug,
      'contentId': playable.id,
      'totalEpisodes': _episodeTotal(playable, stream),
    });
  }

  static int _episodeFor(ContentItem item, int? episode) {
    final fromArg = episode;
    final fromChapter = int.tryParse(item.chapterId.trim());
    final fromContinue = LiveGoLocalStore.continueEpisode(item);
    return (fromArg ?? fromChapter ?? fromContinue).clamp(1, 999).toInt();
  }

  static int _episodeTotal(ContentItem item, StreamInfo stream) {
    final total = [
      item.episodes,
      stream.totalEpisodes,
      _episodeFor(item, null),
    ].reduce((a, b) => a > b ? a : b);
    return total.clamp(1, 999).toInt();
  }

  static bool _isDobdaPlayer(ContentItem item) {
    try {
      return LiveGoApiPlatforms.bySlug(item.platformSlug).isDobda;
    } catch (_) {
      return item.platformSlug.startsWith('dobda_');
    }
  }

  static String _bestUrl(StreamInfo stream) {
    final preferred = stream.urlForQuality(LiveGoSettings.quality).trim();
    if (preferred.isNotEmpty) return preferred;
    return stream.url.trim();
  }

  static ContentItem _playableItem(ContentItem item, int episode) {
    return ContentItem(
      id: item.id,
      title: item.title,
      source: item.source,
      category: item.category,
      description: item.description,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      rating: item.rating,
      episodes: item.episodes <= 0 ? 1 : item.episodes,
      updated: item.updated,
      platformSlug: item.platformSlug,
      chapterId: item.chapterId.trim().isEmpty ? '$episode' : item.chapterId.trim(),
      lang: item.lang,
    );
  }
}
