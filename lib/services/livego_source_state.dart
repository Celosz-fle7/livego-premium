import 'livego_source_registry.dart';

class LiveGoSourceState {
  static final Set<String> _enabled = {
    ...LiveGoSourceRegistry.defaultSlugs,
  };

  static List<String> get enabledSlugs {
    return _enabled.toList();
  }

  static bool enabled(String slug) {
    return _enabled.contains(slug);
  }

  static void toggle(String slug) {
    if (_enabled.contains(slug)) {
      _enabled.remove(slug);
    } else {
      _enabled.add(slug);
    }

    if (_enabled.isEmpty) {
      _enabled.addAll(LiveGoSourceRegistry.defaultSlugs);
    }
  }

  static void enableDefault() {
    _enabled
      ..clear()
      ..addAll(LiveGoSourceRegistry.defaultSlugs);
  }
}
