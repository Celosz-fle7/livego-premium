import '../../../models/content_item.dart';

class TvHomeContentState {
  final ContentItem? hero;
  final List<ContentItem> items;
  final bool loading;
  final bool refreshing;
  final bool hasError;
  final bool fromCache;
  final bool offline;

  const TvHomeContentState({
    this.hero,
    this.items = const <ContentItem>[],
    this.loading = true,
    this.refreshing = false,
    this.hasError = false,
    this.fromCache = false,
    this.offline = false,
  });

  TvHomeContentState copyWith({
    ContentItem? hero,
    List<ContentItem>? items,
    bool? loading,
    bool? refreshing,
    bool? hasError,
    bool? fromCache,
    bool? offline,
  }) {
    return TvHomeContentState(
      hero: hero ?? this.hero,
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      hasError: hasError ?? this.hasError,
      fromCache: fromCache ?? this.fromCache,
      offline: offline ?? this.offline,
    );
  }
}
