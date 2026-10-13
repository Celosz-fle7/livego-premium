import '../../../models/content_item.dart';

class TvHomeContentState {
  final ContentItem? hero;
  final List<ContentItem> items;
  final bool loading;
  final bool refreshing;
  final bool hasError;
  final bool fromCache;
  final bool offline;

  /// Pagination bertahap: halaman terakhir yang sudah dimuat (1-based),
  /// apakah server masih punya halaman berikutnya, dan apakah halaman
  /// berikutnya sedang di-fetch (dipakai loadMore / footer loading).
  final int page;
  final bool hasMore;
  final bool loadingMore;

  const TvHomeContentState({
    this.hero,
    this.items = const <ContentItem>[],
    this.loading = true,
    this.refreshing = false,
    this.hasError = false,
    this.fromCache = false,
    this.offline = false,
    this.page = 1,
    this.hasMore = true,
    this.loadingMore = false,
  });

  TvHomeContentState copyWith({
    ContentItem? hero,
    List<ContentItem>? items,
    bool? loading,
    bool? refreshing,
    bool? hasError,
    bool? fromCache,
    bool? offline,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return TvHomeContentState(
      hero: hero ?? this.hero,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      hasError: hasError ?? this.hasError,
      fromCache: fromCache ?? this.fromCache,
      offline: offline ?? this.offline,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}
