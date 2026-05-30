import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';

class FavoriteService {
  static List<ContentItem> get items => LiveGoLocalStore.favorites;
  static bool contains(ContentItem item) => LiveGoLocalStore.isFavorite(item);
  static Future<void> toggle(ContentItem item) => LiveGoLocalStore.toggleFavorite(item);
  static Future<void> clear() => LiveGoLocalStore.clearFavorites();
}
