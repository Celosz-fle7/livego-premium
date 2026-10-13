import 'package:flutter/foundation.dart';

class TvNavigationSnapshot {
  final int index;
  final String owner;
  final int tick;

  const TvNavigationSnapshot({
    required this.index,
    required this.owner,
    required this.tick,
  });
}

class TvNavigationService extends ChangeNotifier {
  TvNavigationService._();

  static final TvNavigationService instance = TvNavigationService._();

  int _index = 0;
  String _owner = 'home';
  int _tick = 0;

  int get index => _index;
  String get owner => _owner;
  int get tick => _tick;

  TvNavigationSnapshot get snapshot => TvNavigationSnapshot(
        index: _index,
        owner: _owner,
        tick: _tick,
      );

  void update({
    required int index,
    required String owner,
  }) {
    final changed = index != _index || owner != _owner;
    if (!changed) return;
    _index = index;
    _owner = owner;
    _tick++;
    notifyListeners();
  }
}
