import 'package:flutter/foundation.dart';

import '../models/content_item.dart';

class WatchProgress {
  final ContentItem item;
  final int episode;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  const WatchProgress({
    required this.item,
    required this.episode,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  double get ratio {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }
}

class LiveGoLocalStore {
  static final ValueNotifier<int> version = ValueNotifier<int>(0);
  static final List<ContentItem> _history = <ContentItem>[];
  static final List<ContentItem> _favorites = <ContentItem>[];
  static final Map<String, WatchProgress> _progress = <String, WatchProgress>{};

  static List<ContentItem> get history => List.unmodifiable(_history);
  static List<ContentItem> get favorites => List.unmodifiable(_favorites);
  static List<WatchProgress> get continueWatching {
    final rows = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(rows);
  }

  static String _key(ContentItem item) => '${item.platformSlug}:${item.id}';

  static bool isFavorite(ContentItem item) {
    return _favorites.any((e) => e.id == item.id && e.platformSlug == item.platformSlug);
  }

  static int continueEpisode(ContentItem item) {
    return _progress[_key(item)]?.episode ?? int.tryParse(item.chapterId) ?? 1;
  }

  static WatchProgress? progressFor(ContentItem item) => _progress[_key(item)];

  static void saveProgress(ContentItem item, int episode, Duration position, Duration duration) {
    if (episode <= 0) return;
    _progress[_key(item)] = WatchProgress(
      item: item,
      episode: episode,
      position: position,
      duration: duration,
      updatedAt: DateTime.now(),
    );
    addHistory(item, notify: false);
    _bump();
  }

  static void markEpisodeComplete(ContentItem item, int episode) {
    final next = episode + 1;
    _progress[_key(item)] = WatchProgress(
      item: item,
      episode: next,
      position: Duration.zero,
      duration: Duration.zero,
      updatedAt: DateTime.now(),
    );
    addHistory(item, notify: false);
    _bump();
  }

  static void addHistory(ContentItem item, {bool notify = true}) {
    _history.removeWhere((e) => e.id == item.id && e.platformSlug == item.platformSlug);
    _history.insert(0, item);
    if (_history.length > 80) _history.removeRange(80, _history.length);
    if (notify) _bump();
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
    _progress.clear();
    _bump();
  }

  static void clearFavorites() {
    _favorites.clear();
    _bump();
  }

  static void clearAll() {
    _history.clear();
    _favorites.clear();
    _progress.clear();
    _bump();
  }

  static void _bump() => version.value++;
}
