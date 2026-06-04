import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';

class TvHomeRowsState {
  final List<WatchProgress> continueWatching;
  final List<ContentItem> myList;

  const TvHomeRowsState({
    required this.continueWatching,
    required this.myList,
  });

  bool get hasAny => continueWatching.isNotEmpty || myList.isNotEmpty;

  factory TvHomeRowsState.fromStore() {
    return TvHomeRowsState(
      continueWatching: LiveGoLocalStore.continueWatching.take(12).toList(growable: false),
      myList: LiveGoLocalStore.favorites.take(12).toList(growable: false),
    );
  }
}
