import '../../core/livego_settings.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';
import '../livego_api_gateway.dart';
import '../api/api_platform.dart';
import 'player_preferences.dart';
import 'playback_source.dart';

class PlaybackResolver {
  const PlaybackResolver._();

  static Future<PlaybackSource> resolve(
    ContentItem item, {
    String? chapterId,
  }) async {
    await PlayerPreferences.load();
    _syncPlayerSettings();

    final platform = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final requestedChapter = chapterId ?? item.chapterId;
    final ep = _episodeNumber(requestedChapter);
    if (platform.isEncrypted) {
      return PlaybackSource.empty(
        platform: platform.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: platform.videoType,
        encrypted: true,
      );
    }

    final stream = await LiveGoApiGateway.videoInfo(
      item,
      chapterId: platform.isNobuzero ? requestedChapter : '$ep',
    );
    return _sourceFromStream(item, stream, platform: platform, ep: ep);
  }

  static Future<PlaybackSource> fastResolve(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) async {
    await PlayerPreferences.load();
    _syncPlayerSettings();

    final platform = LiveGoApiPlatforms.bySlug(item.platformSlug);
    final requestedChapter = chapterId ?? item.chapterId;
    final ep = _episodeNumber(requestedChapter);
    if (platform.isEncrypted) {
      return PlaybackSource.empty(
        platform: platform.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: platform.videoType,
        encrypted: true,
      );
    }

    final stream = await LiveGoApiGateway.fastEpisodeStream(
      item,
      chapterId: platform.isNobuzero ? requestedChapter : '$ep',
      timeout: timeout,
    );
    return _sourceFromStream(item, stream, platform: platform, ep: ep);
  }

  static Future<StreamInfo> resolveStreamInfo(
    ContentItem item, {
    String? chapterId,
  }) async {
    final source = await resolve(item, chapterId: chapterId);
    return source.toStreamInfo();
  }

  static Future<StreamInfo> fastStreamInfo(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final source = await fastResolve(item, chapterId: chapterId, timeout: timeout);
    return source.toStreamInfo();
  }

  static PlaybackSource _sourceFromStream(
    ContentItem item,
    StreamInfo stream, {
    required LiveGoApiPlatform platform,
    required int ep,
  }) {
    if (stream.url.trim().isEmpty) {
      return PlaybackSource.empty(
        platform: platform.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: platform.videoType,
      );
    }

    return PlaybackSource.fromStreamInfo(
      stream: stream,
      platform: platform.slug,
      dramaId: item.id,
      episodeNumber: ep,
      videoType: platform.videoType,
      selectedQuality: PlayerPreferences.quality,
      selectedSubtitle: PlayerPreferences.subtitleEnabled ? PlayerPreferences.subtitleLanguage : 'OFF',
      selectedAudioTrack: PlayerPreferences.audioTrack,
    );
  }

  static void _syncPlayerSettings() {
    LiveGoSettings.quality = PlayerPreferences.quality;
    LiveGoSettings.subtitlesEnabled = PlayerPreferences.subtitleEnabled;
  }

  static int _episodeNumber(String chapter) {
    final direct = int.tryParse(chapter);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'\d+').firstMatch(chapter);
    final parsed = match == null ? null : int.tryParse(match.group(0)!);
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }
}
