import '../../models/content_item.dart';
import '../../models/stream_info.dart';

/// Stable boundary between API/provider code and Player UI.
///
/// Player screens must depend on StreamInfo/PlaybackContract results, not on:
/// - baseUrl
/// - API key
/// - raw JSON shape
/// - endpoint names
/// - provider-specific chapter/video id rules
///
/// When API changes, update adapter/resolver/mapper before this boundary.
/// Do not modify TV Player UI just because API response changed.
abstract class PlaybackContract {
  Future<StreamInfo> streamInfo(
    ContentItem item, {
    String? chapterId,
  });

  Future<StreamInfo> fastStreamInfo(
    ContentItem item, {
    String? chapterId,
    Duration timeout = const Duration(seconds: 7),
  });
}

/// Data contract accepted by TV Player.
///
/// Keep this normalized. Provider-specific raw response fields must be mapped
/// before reaching Player:
/// - videoUrl/src/url -> StreamInfo.url
/// - headers/streamHeaders -> StreamInfo.headers
/// - quality/resolution/label -> StreamQuality.label
/// - subtitle/lang/language -> SubtitleTrack.language
/// - next/prev provider ids -> nextEpisodeId/prevEpisodeId
class PlaybackContractRules {
  const PlaybackContractRules._();

  static bool isPlayable(StreamInfo stream) => stream.url.trim().isNotEmpty;

  static Map<String, String> safeHeaders(StreamInfo stream) {
    final headers = <String, String>{...stream.headers};
    headers.putIfAbsent('User-Agent', () => 'okhttp/4.12.0');
    headers.putIfAbsent('Accept', () => '*/*');
    return Map<String, String>.unmodifiable(headers);
  }

  static List<StreamQuality> normalizedQualities(StreamInfo stream) {
    if (stream.qualities.isEmpty && stream.url.trim().isNotEmpty) {
      return <StreamQuality>[
        StreamQuality(label: 'Auto', url: stream.url, isDefault: true),
      ];
    }
    final seen = <String>{};
    final rows = <StreamQuality>[];
    for (final quality in stream.qualities) {
      final url = quality.url.trim();
      if (url.isEmpty || !seen.add('${quality.label}|$url')) continue;
      rows.add(StreamQuality(
        label: quality.label.trim().isEmpty ? 'Auto' : quality.label.trim(),
        url: url,
        isDefault: quality.isDefault,
      ));
    }
    return List<StreamQuality>.unmodifiable(rows);
  }
}
