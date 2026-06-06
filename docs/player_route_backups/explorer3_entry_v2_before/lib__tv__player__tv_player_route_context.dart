import '../../models/content_item.dart';

/// Data needed by Shell/Home/Search/etc to restore exact position after player.
class TvPlayerRouteContext {
  final String source;
  final String platformSlug;
  final String contentId;
  final String title;
  final String restoreZone;
  final int restoreIndex;
  final int episode;

  const TvPlayerRouteContext({
    required this.source,
    required this.platformSlug,
    required this.contentId,
    required this.title,
    this.restoreZone = '',
    this.restoreIndex = 0,
    this.episode = 1,
  });

  factory TvPlayerRouteContext.fromItem(
    ContentItem item, {
    String source = 'unknown',
    String restoreZone = '',
    int restoreIndex = 0,
    int episode = 1,
  }) {
    return TvPlayerRouteContext(
      source: source,
      platformSlug: item.platformSlug,
      contentId: item.id,
      title: item.title,
      restoreZone: restoreZone,
      restoreIndex: restoreIndex,
      episode: episode,
    );
  }

  TvPlayerRouteContext copyWith({
    String? source,
    String? platformSlug,
    String? contentId,
    String? title,
    String? restoreZone,
    int? restoreIndex,
    int? episode,
  }) {
    return TvPlayerRouteContext(
      source: source ?? this.source,
      platformSlug: platformSlug ?? this.platformSlug,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      restoreZone: restoreZone ?? this.restoreZone,
      restoreIndex: restoreIndex ?? this.restoreIndex,
      episode: episode ?? this.episode,
    );
  }

  String get debugLabel => '$source:$platformSlug:$contentId:$restoreZone#$restoreIndex ep=$episode';
}
