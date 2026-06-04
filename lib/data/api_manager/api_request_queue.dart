import 'dart:async';

class ApiRequestQueue {
  final int maxParallel;
  int _running = 0;
  final List<Future<void> Function()> _waiting = <Future<void> Function()>[];

  ApiRequestQueue({this.maxParallel = 3});

  Future<T> schedule<T>(Future<T> Function() task) {
    final completer = Completer<T>();

    Future<void> run() async {
      _running++;
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _running--;
        _drain();
      }
    }

    if (_running < maxParallel) {
      unawaited(run());
    } else {
      _waiting.add(run);
    }

    return completer.future;
  }

  void _drain() {
    if (_running >= maxParallel || _waiting.isEmpty) return;
    final next = _waiting.removeAt(0);
    unawaited(next());
  }
}
