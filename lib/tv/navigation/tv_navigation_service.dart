import 'package:flutter/foundation.dart';

class TvNavigationSnapshot {
  final int index;
  final bool navFocused;
  final String owner;
  final String navMode;
  final int tick;

  const TvNavigationSnapshot({
    required this.index,
    required this.navFocused,
    required this.owner,
    required this.navMode,
    required this.tick,
  });
}

class TvNavigationService extends ChangeNotifier {
  TvNavigationService._();

  static final TvNavigationService instance = TvNavigationService._();

  int _index = 0;
  bool _navFocused = false;
  String _owner = 'home';
  String _navMode = 'hidden';
  int _tick = 0;

  int get index => _index;
  bool get navFocused => _navFocused;
  String get owner => _owner;
  String get navMode => _navMode;
  int get tick => _tick;

  TvNavigationSnapshot get snapshot => TvNavigationSnapshot(
        index: _index,
        navFocused: _navFocused,
        owner: _owner,
        navMode: _navMode,
        tick: _tick,
      );

  void update({
    required int index,
    required bool navFocused,
    required String owner,
    required String navMode,
  }) {
    final changed = index != _index ||
        navFocused != _navFocused ||
        owner != _owner ||
        navMode != _navMode;
    if (!changed) return;
    _index = index;
    _navFocused = navFocused;
    _owner = owner;
    _navMode = navMode;
    _tick++;
    notifyListeners();
  }
}
