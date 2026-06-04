import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';

class TvLocalStoreVersionController extends StateNotifier<int> {
  late final void Function() _listener;

  TvLocalStoreVersionController() : super(LiveGoLocalStore.version.value) {
    _listener = () => state = LiveGoLocalStore.version.value;
    LiveGoLocalStore.version.addListener(_listener);
  }

  @override
  void dispose() {
    LiveGoLocalStore.version.removeListener(_listener);
    super.dispose();
  }
}

final tvLocalStoreVersionProvider = StateNotifierProvider<TvLocalStoreVersionController, int>(
  (ref) => TvLocalStoreVersionController(),
);

final tvLibraryItemsProvider = Provider.family<List<ContentItem>, bool>((ref, favorites) {
  ref.watch(tvLocalStoreVersionProvider);
  final raw = favorites ? LiveGoLocalStore.favorites : LiveGoLocalStore.history;
  return ContentHealthService.filterPlayable(raw);
});
