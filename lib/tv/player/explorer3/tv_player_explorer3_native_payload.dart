import '../../../core/livego_settings.dart';
import '../../../models/content_item.dart';
import '../../../models/stream_info.dart';

/// Converts Flutter player state into the native TV player MethodChannel payload.
class TvPlayerExplorer3NativePayload {
  const TvPlayerExplorer3NativePayload._();

  static Map<String, Object?> build({
    required ContentItem item,
    required StreamInfo stream,
    required String url,
    required int episode,
    required String chapterId,
    required int totalEpisodes,
  }) {
    return <String, Object?>{
      'url': url,
      'title': item.title,
      'description': item.description,
      'source': item.source,
      'category': item.category,
      'episode': episode,
      'chapterId': chapterId,
      'totalEpisodes': totalEpisodes,
      'headers': stream.headers,
      'qualityLabels': stream.qualities.map((e) => e.label).toList(),
      'qualityUrls': stream.qualities.map((e) => e.url).toList(),
      'subtitleLabels': stream.subtitles.map((e) => e.language.trim().isEmpty ? 'Subtitle' : e.language).toList(),
      'subtitleUrls': stream.subtitles.map((e) => e.url).toList(),
      'subtitleFormats': stream.subtitles.map((e) => e.format).toList(),
      'autoNextEnabled': LiveGoSettings.autoNextEnabled,
    };
  }
}
