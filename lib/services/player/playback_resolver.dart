import '../../core/livego_settings.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../drama_source.dart';
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

    // Sumber drama eksternal (multi-APK): resolve via registry, meniru APK.
    final dramaSource = DramaSourceRegistry.forSlug(item.platformSlug);
    if (dramaSource != null) {
      return _resolveFromDramaSource(dramaSource, item, chapterId: chapterId);
    }

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
      chapterId: platform.isDobda ? requestedChapter : '$ep',
    );
    return _sourceFromStream(item, stream, platform: platform, ep: ep);
  }

  /// Resolve stream untuk sumber drama eksternal (multi-APK).
  static Future<PlaybackSource> _resolveFromDramaSource(
    DramaSource source,
    ContentItem item, {
    String? chapterId,
  }) async {
    final requestedChapter = chapterId ?? item.chapterId;
    final ep = _episodeNumber(requestedChapter);
    try {
      final episodes = await source.episodes(item.id);
      final episodeId = _pickEpisodeId(episodes, ep);
      final url = await source.streamUrl(
        seriesId: item.id,
        episodeId: episodeId,
      );
      if (url.trim().isEmpty) {
        return PlaybackSource.empty(
          platform: source.slug,
          dramaId: item.id,
          episodeNumber: ep,
          videoType: LiveGoVideoType.mp4,
        );
      }
      final nextIdx = episodes.indexWhere((e) => e.id == episodeId);

      // Extras: subtitle, kualitas, status unlock (jika provider mendukung).
      List<SubtitleTrack> subtitles = const [];
      List<StreamQuality> qualities = const [];
      try {
        final extras = await source.episodeExtras(item.id, episodeId);
        if (extras != null) {
          if (!extras.unlocked) {
            // Episode terkunci: kembalikan source kosong dengan info harga.
            return PlaybackSource.empty(
              platform: source.slug,
              dramaId: item.id,
              episodeNumber: ep,
              videoType: LiveGoVideoType.mp4,
            );
          }
          subtitles = extras.subtitles
              .map((s) => SubtitleTrack(
                    language: s.language,
                    format: 'vtt',
                    url: s.url,
                  ))
              .toList();
          qualities = extras.qualities
              .map((q) => StreamQuality(
                    label: q.label,
                    url: url,
                    isDefault: q.label == '720p',
                  ))
              .toList();
        }
      } catch (_) {
        // Extras opsional; lanjut tanpa subtitle/kualitas.
      }

      final stream = StreamInfo(
        url: url,
        episodeIndex: ep,
        totalEpisodes: episodes.length,
        nextEpisodeId: nextIdx >= 0 && nextIdx + 1 < episodes.length
            ? episodes[nextIdx + 1].id
            : '0',
        prevEpisodeId: nextIdx > 0 ? episodes[nextIdx - 1].id : '0',
        headers: const {},
        subtitles: subtitles,
        qualities: qualities,
      );
      final videoType = source.slug == 'melolo'
          ? LiveGoVideoType.mp4
          : LiveGoVideoType.hls;
      return PlaybackSource.fromStreamInfo(
        stream: stream,
        platform: source.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: videoType,
        selectedQuality: PlayerPreferences.quality,
        selectedSubtitle:
            PlayerPreferences.subtitleEnabled ? PlayerPreferences.subtitleLanguage : 'OFF',
        selectedAudioTrack: PlayerPreferences.audioTrack,
      );
    } catch (e) {
      return PlaybackSource.empty(
        platform: source.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: source.slug == 'melolo'
            ? LiveGoVideoType.mp4
            : LiveGoVideoType.hls,
      );
    }
  }

  static String _pickEpisodeId(List<LiveGoEpisode> episodes, int ep) {
    if (episodes.isEmpty) return '$ep';
    for (final e in episodes) {
      if (e.index == ep) return e.id;
    }
    final idx = (ep - 1).clamp(0, episodes.length - 1);
    return episodes[idx].id;
  }

  static Future<PlaybackSource> fastResolve(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  }) async {
    await PlayerPreferences.load();
    _syncPlayerSettings();

    // Sumber drama eksternal (multi-APK): resolve via registry, meniru APK.
    // (TV pakai jalur fast ini; tanpa branch ini FreeReels di TV gagal.)
    final dramaSource = DramaSourceRegistry.forSlug(item.platformSlug);
    if (dramaSource != null) {
      return _resolveFromDramaSource(dramaSource, item, chapterId: chapterId)
          .timeout(timeout, onTimeout: () => PlaybackSource.empty(
                platform: dramaSource.slug,
                dramaId: item.id,
                episodeNumber: _episodeNumber(chapterId ?? item.chapterId),
                videoType: LiveGoVideoType.hls,
              ));
    }

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
      chapterId: platform.isDobda ? requestedChapter : '$ep',
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
