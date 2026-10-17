import 'dart:async';

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
    _syncPlayerSettings(item.platformSlug);

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

      // Cek status unlock / extras sebelum request stream
      DramaEpisodeExtras? extras;
      try {
        extras = await source.episodeExtras(item.id, episodeId);
        if (extras != null && !extras.unlocked) {
          final price = extras.episodePrice > 0 ? ' (${extras.episodePrice} koin)' : '';
          throw Exception('Episode $ep terkunci VIP/berbayar$price');
        }
      } catch (e) {
        if ('$e'.contains('terkunci')) rethrow;
      }

      final url = await source.streamUrl(
        seriesId: item.id,
        episodeId: episodeId,
        // Kualitas per provider (fallback global: TV 360p / HP 480p /
        // pilihan terakhir). FreeReels & CinemaID mengabaikan param ini;
        // Melolo & ShortTV memilih definisi video sesuai kualitas.
        quality: PlayerPreferences.qualityFor(source.slug),
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

      // Extras: subtitle, kualitas.
      // NOTE: URL tiap entri kualitas = URL dasar (sudah sesuai preferensi
      // kualitas user). JANGAN fabrikasi `?q=` — proxy Melolo/ShortTV
      // mengabaikan query param, jadi `?q=` adalah no-op yang membuat
      // ganti kualitas kelihatan jalan padahal tidak. Ganti kualitas yang
      // beneran lewat streamUrlForQuality() (re-resolve per kualitas).
      List<SubtitleTrack> subtitles = const [];
      List<StreamQuality> qualities = const [];
      List<String> audioLanguages = const [];
      if (extras != null) {
        subtitles = extras.subtitles
            .map((s) => SubtitleTrack(
                  language: s.language,
                  displayName: s.displayName.isNotEmpty ? s.displayName : s.language,
                  format: 'vtt',
                  url: s.url,
                ))
            .toList();
        audioLanguages = extras.audioLanguages;
        qualities = extras.qualities
            .map((q) => StreamQuality(
                  label: q.label,
                  url: url,
                  isDefault: (source.slug == 'melolo' || source.slug == 'shorttv' || source.slug == 'shortmax')
                      ? (q.label.toLowerCase() == PlayerPreferences.qualityFor(source.slug).toLowerCase())
                      : q.label == '720p',
                ))
            .toList();
      }


      if (source.slug == 'melolo' && qualities.isEmpty) {
        qualities = const [
          DramaQuality(label: '720p', resolution: '720x1280 (HD)'),
          DramaQuality(label: '540p', resolution: '540x960 (Standar)'),
          DramaQuality(label: '480p', resolution: '480x854 (Hemat)'),
          DramaQuality(label: '360p', resolution: '360x640 (Cepat)'),
          DramaQuality(label: '240p', resolution: '240x426 (Ringan)'),
        ].map((q) => StreamQuality(
              label: q.label,
              url: url,
              isDefault: q.label.toLowerCase() == PlayerPreferences.qualityFor(source.slug).toLowerCase(),
            )).toList();
      }

      final stream = StreamInfo(
        url: url,
        episodeIndex: ep,
        totalEpisodes: episodes.length,
        episodeId: episodeId,
        nextEpisodeId: nextIdx >= 0 && nextIdx + 1 < episodes.length
            ? episodes[nextIdx + 1].id
            : '0',
        prevEpisodeId: nextIdx > 0 ? episodes[nextIdx - 1].id : '0',
        headers: const {},
        subtitles: subtitles,
        qualities: qualities,
        audioLanguages: audioLanguages,
      );
      final videoType = source.slug == 'melolo'
          ? (url.toLowerCase().contains('.m3u8') ? LiveGoVideoType.hls : LiveGoVideoType.cenc)
          : (source.slug == 'shortdrama' ||
                  source.slug == 'netshort' ||
                  source.slug == 'moviebox' ||
                  source.slug == 'livegodrama' ||
                  url.toLowerCase().contains('.mp4'))
              ? LiveGoVideoType.mp4
              : (url.toLowerCase().contains('.m3u8') ? LiveGoVideoType.hls : LiveGoVideoType.mp4);
      return PlaybackSource.fromStreamInfo(
        stream: stream,
        platform: source.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: videoType,
        selectedQuality: PlayerPreferences.qualityFor(source.slug),
        selectedSubtitle:
            PlayerPreferences.subtitleEnabledFor(source.slug) ? PlayerPreferences.subtitleLanguageFor(source.slug) : 'OFF',
        selectedAudioTrack: PlayerPreferences.audioTrack,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('LIVEGO PlaybackResolver error on ${source.slug}: $e\n$st');
      final fallbackType = (source.slug == 'shortdrama' ||
              source.slug == 'netshort' ||
              source.slug == 'moviebox' ||
              source.slug == 'livegodrama')
          ? LiveGoVideoType.mp4
          : LiveGoVideoType.hls;
      return PlaybackSource.empty(
        platform: source.slug,
        dramaId: item.id,
        episodeNumber: ep,
        videoType: fallbackType,
      );
    }
  }

  /// Resolve ulang URL stream untuk [quality] tertentu (ganti kualitas di player).
  /// Dipakai Melolo/ShortTV/ShortMax yang memilih definisi video per kualitas.
  /// Return null kalau gagal -> pemanggil pakai URL lama (urlForQuality).
  static Future<String?> streamUrlForQuality(
    ContentItem item, {
    required String episodeId,
    required String quality,
  }) async {
    final source = DramaSourceRegistry.forSlug(item.platformSlug);
    if (source == null) return null;
    try {
      final url = await source.streamUrl(
        seriesId: item.id,
        episodeId: episodeId,
        quality: quality,
      );
      return url.trim().isEmpty ? null : url;
    } catch (_) {
      return null;
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
    _syncPlayerSettings(item.platformSlug);

    // Sumber drama eksternal (multi-APK): resolve via registry, meniru APK.
    // (TV pakai jalur fast ini; tanpa branch ini FreeReels di TV gagal.)
    final dramaSource = DramaSourceRegistry.forSlug(item.platformSlug);
    if (dramaSource != null) {
      final effectiveTimeout = (dramaSource.slug == 'melolo' ||
              dramaSource.slug == 'shorttv' ||
              dramaSource.slug == 'shortmax' ||
              dramaSource.slug == 'shortdrama' ||
              dramaSource.slug == 'netshort' ||
              dramaSource.slug == 'moviebox' ||
              dramaSource.slug == 'livegodrama')
          ? const Duration(seconds: 15)
          : timeout;
      final videoType = (dramaSource.slug == 'melolo' ||
              dramaSource.slug == 'netshort' ||
              dramaSource.slug == 'shortdrama' ||
              dramaSource.slug == 'moviebox' ||
              dramaSource.slug == 'livegodrama')
          ? LiveGoVideoType.mp4
          : LiveGoVideoType.hls;
      return _resolveFromDramaSource(dramaSource, item, chapterId: chapterId)
          .timeout(effectiveTimeout, onTimeout: () => PlaybackSource.empty(
                platform: dramaSource.slug,
                dramaId: item.id,
                episodeNumber: _episodeNumber(chapterId ?? item.chapterId),
                videoType: videoType,
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
      selectedQuality: PlayerPreferences.qualityFor(platform.slug),
      selectedSubtitle: PlayerPreferences.subtitleEnabledFor(platform.slug)
          ? PlayerPreferences.subtitleLanguageFor(platform.slug)
          : 'OFF',
      selectedAudioTrack: PlayerPreferences.audioTrack,
    );
  }

  static void _syncPlayerSettings(String slug) {
    LiveGoSettings.quality = PlayerPreferences.qualityFor(slug);
    LiveGoSettings.subtitlesEnabled = PlayerPreferences.subtitleEnabledFor(slug);
  }

  static int _episodeNumber(String chapter) {
    final direct = int.tryParse(chapter);
    if (direct != null && direct > 0) return direct;
    final match = RegExp(r'\d+').firstMatch(chapter);
    final parsed = match == null ? null : int.tryParse(match.group(0)!);
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }

  /// Prefetch / Preload episode berikutnya di background saat episode saat ini sedang diputar.
  /// Memastikan transisi ke episode selanjutnya berjalan instan (0 detik) tanpa loading.
  static void preloadNext(ContentItem item, int currentEpisode) {
    unawaited(_preloadNextEpisode(item, currentEpisode));
  }

  static Future<void> _preloadNextEpisode(ContentItem item, int currentEpisode) async {
    final dramaSource = DramaSourceRegistry.forSlug(item.platformSlug);
    if (dramaSource == null) return;
    try {
      final episodes = await dramaSource.episodes(item.id);
      final nextEp = currentEpisode + 1;
      final nextEpisodeId = _pickEpisodeId(episodes, nextEp);
      if (nextEpisodeId.isNotEmpty) {
        await dramaSource.streamUrl(
          seriesId: item.id,
          episodeId: nextEpisodeId,
          // Prefetch dengan kualitas per provider yang sama, supaya
          // cache yang terisi adalah yang benar-benar dipakai saat
          // user pindah episode (bukan 'auto').
          quality: PlayerPreferences.qualityFor(item.platformSlug),
        );
      }
    } catch (_) {}
  }
}
