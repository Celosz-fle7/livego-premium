import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';

class WatchHistoryService {
  static List<ContentItem> get items => LiveGoLocalStore.history;
  static List<WatchProgress> get continueWatching => LiveGoLocalStore.continueWatching;
  static void add(ContentItem item) => LiveGoLocalStore.addHistory(item);
  static Future<void> clear() => LiveGoLocalStore.clearHistory();
}
