import 'package:flutter/foundation.dart';

/// Lightweight custom analytics hook for TV public-readiness.
///
/// This intentionally avoids a hard Firebase dependency. Later, this can forward
/// the same events to Firebase, PostHog, or a private endpoint without touching
/// TV screens again.
class LiveGoAnalytics {
  const LiveGoAnalytics._();

  static bool enabled = true;

  static void track(String event, {Map<String, Object?> params = const <String, Object?>{}}) {
    if (!enabled) return;
    final cleaned = <String, Object?>{
      for (final entry in params.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    debugPrint('[LiveGoAnalytics] $event $cleaned');
  }

  static void screen(String name, {Map<String, Object?> params = const <String, Object?>{}}) {
    track('screen_view', params: <String, Object?>{'screen': name, ...params});
  }

  static void contentOpen(String source, String id, String title) {
    track('content_open', params: <String, Object?>{'source': source, 'id': id, 'title': title});
  }

  static void play(String source, String id, String title, int episode) {
    track('play', params: <String, Object?>{'source': source, 'id': id, 'title': title, 'episode': episode});
  }

  static void search(String query, int count) {
    track('search', params: <String, Object?>{'query': query, 'count': count});
  }

  static void error(String scope, Object error) {
    track('error', params: <String, Object?>{'scope': scope, 'message': '$error'});
  }
}
