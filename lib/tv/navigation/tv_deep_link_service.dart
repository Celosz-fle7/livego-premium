import '../../models/content_item.dart';

class TvDeepLinkContentTarget {
  final String platform;
  final String id;
  final int episode;
  const TvDeepLinkContentTarget({required this.platform, required this.id, this.episode = 1});

  ContentItem toPlaceholderItem() {
    return ContentItem(
      id: id,
      title: id,
      source: platform,
      category: 'Drama',
      description: '',
      posterUrl: '',
      backdropUrl: '',
      rating: 8.0,
      episodes: episode <= 0 ? 1 : episode,
      platformSlug: platform,
      chapterId: '$episode',
    );
  }
}

class TvDeepLinkService {
  const TvDeepLinkService._();

  static TvDeepLinkContentTarget? parse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final segments = uri.pathSegments;
    if (scheme == 'livego' && uri.host == 'content' && segments.length >= 2) {
      return TvDeepLinkContentTarget(
        platform: segments[0],
        id: segments[1],
        episode: int.tryParse(uri.queryParameters['episode'] ?? '1') ?? 1,
      );
    }
    if ((scheme == 'https' || scheme == 'http') && uri.host.contains('livego') && segments.length >= 3 && segments[0] == 'content') {
      return TvDeepLinkContentTarget(
        platform: segments[1],
        id: segments[2],
        episode: int.tryParse(uri.queryParameters['episode'] ?? '1') ?? 1,
      );
    }
    return null;
  }
}
