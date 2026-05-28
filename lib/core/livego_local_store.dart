import 'package:flutter/foundation.dart';

import '../models/content_item.dart';

class LiveGoLocalStore {
  static final ValueNotifier<int> version = ValueNotifier<int>(0);
  static final List<ContentItem> _history = <ContentItem>[];
  static final List<ContentItem> _favorites = <ContentItem>[];

  static List<ContentItem> get history => List.unmodifiable(_history);
  static List<ContentItem> get favorites => List.unmodifiable(_favorites);

  static bool isFavorite(ContentItem item) {
    return _favorites.any((e) => e.id == item.id && e.platformSlug == item.platformSlug);
  }

  static void addHistory(ContentItem item) {
    _history.removeWhere((e) => e.id == item.id && e.platformSlug == item.platformSlug);
    _history.insert(0, item);
    if (_history.length > 80) _history.removeRange(80, _history.length);
    _bump();
  }

  static void toggleFavorite(ContentItem item) {
    final index = _favorites.indexWhere((e) => e.id == item.id && e.platformSlug == item.platformSlug);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.insert(0, item);
    }
    _bump();
  }

  static void clearHistory() {
    _history.clear();
    _bump();
  }

  static void clearFavorites() {
    _favorites.clear();
    _bump();
  }

  static void clearAll() {
    _history.clear();
    _favorites.clear();
    _bump();
  }

  static void _bump() => version.value++;
}
