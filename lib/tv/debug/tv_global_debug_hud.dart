import 'dart:async';
import 'dart:collection';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class TvDebugRecorder {
  static const MethodChannel _channel = MethodChannel('livego/debug_file');
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final List<String> _lines = <String>[];

  static Timer? _flushTimer;
  static bool _started = false;
  static bool _saving = false;

  static String lastPath = 'not-saved-yet';
  static String lastStatus = 'idle';
  static int lineCount = 0;

  static void start() {
    if (_started) return;
    _started = true;
    record('RECORDER_START app=LiveGO Premium target=Download/LiveGoDebug/livego_debug_record.txt');
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(flushNow(reason: 'timer')));
  }

  static void stop() {
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(flushNow(reason: 'stop'));
  }

  static void record(String message) {
    final time = DateTime.now().toIso8601String();
    final clean = message.replaceAll('\n', ' ').trim();
    _lines.add('[$time] $clean');
    if (_lines.length > 2200) {
      _lines.removeRange(0, _lines.length - 2200);
    }
    lineCount = _lines.length;
    revision.value++;
  }

  static Future<void> flushNow({String reason = 'manual'}) async {
    if (_saving || !_started) return;
    _saving = true;
    lastStatus = 'saving:$reason';
    revision.value++;

    final buffer = StringBuffer()
      ..writeln('LIVEGO DEBUG RECORD')
      ..writeln('target=Android TV')
      ..writeln('file=Download/LiveGoDebug/livego_debug_record.txt')
      ..writeln('generated=${DateTime.now().toIso8601String()}')
      ..writeln('lines=${_lines.length}')
      ..writeln('');

    for (final line in _lines) {
      buffer.writeln(line);
    }

    try {
      final path = await _channel.invokeMethod<String>(
        'saveDebugLog',
        <String, Object?>{
          'fileName': 'livego_debug_record.txt',
          'content': buffer.toString(),
        },
      );
      lastPath = path ?? 'Download/LiveGoDebug/livego_debug_record.txt';
      lastStatus = 'saved:$reason';
    } catch (error) {
      lastStatus = 'save-failed:$error';
      debugPrint('LIVEGO DEBUG RECORDER SAVE FAILED: $error');
    } finally {
      _saving = false;
      revision.value++;
    }
  }
}

class TvGlobalDebugErrors {
  static final ValueNotifier<String> lastError = ValueNotifier<String>('-');

  static void report(Object error, [StackTrace? stackTrace]) {
    final raw = '$error';
    final clean = raw.replaceAll('\n', ' ').trim();
    final text = clean.isEmpty ? error.runtimeType.toString() : clean;
    lastError.value = text.length > 220 ? '${text.substring(0, 220)}...' : text;
    debugPrint('LIVEGO GLOBAL ERROR HUD: ${lastError.value}');
    TvDebugRecorder.record('ERROR ${lastError.value}');
    unawaited(TvDebugRecorder.flushNow(reason: 'error'));
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void reportFlutter(FlutterErrorDetails details) {
    report(details.exception, details.stack);
  }
}

/// Global TV debug/performance overlay.
///
/// Lives above MaterialApp routes through MaterialApp.builder, so it should be
/// visible from app start through Home, Detail, and Player routes.
///
/// It must never steal focus or consume remote events.
class TvGlobalDebugHud extends StatefulWidget {
  final Widget child;

  const TvGlobalDebugHud({
    super.key,
    required this.child,
  });

  @override
  State<TvGlobalDebugHud> createState() => _TvGlobalDebugHudState();
}

class _TvGlobalDebugHudState extends State<TvGlobalDebugHud> {
  // Temporary diagnostic flag. Keep HUD visible even when the APK is built in
  // release/profile mode by CI. Remove or set false only before final release.
  static const bool _forceVisible = true;

  final Stopwatch _uptime = Stopwatch()..start();
  final Queue<double> _recentFrameMs = Queue<double>();

  Timer? _ticker;

  String _lastKey = '-';
  String _lastEvent = '-';
  int _keyCount = 0;
  String _primaryFocus = '-';
  String _route = '-';
  String _lastError = '-';

  int _frameCount = 0;
  int _jank30Count = 0;
  int _jank50Count = 0;
  double _lastFrameMs = 0;
  double _lastBuildMs = 0;
  double _lastRasterMs = 0;
  double _avgFrameMs = 0;
  double _maxFrameMs = 0;

  int _imageCount = 0;
  int _imageLive = 0;
  int _imagePending = 0;
  int _imageMax = 0;
  double _imageMb = 0;

  int _lastRecordedSecond = -1;

  @override
  void initState() {
    super.initState();
    TvDebugRecorder.start();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    SchedulerBinding.instance.addTimingsCallback(_handleFrameTimings);
    TvGlobalDebugErrors.lastError.addListener(_refresh);
    TvDebugRecorder.revision.addListener(_refresh);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh(true));
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(true));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    SchedulerBinding.instance.removeTimingsCallback(_handleFrameTimings);
    TvGlobalDebugErrors.lastError.removeListener(_refresh);
    TvDebugRecorder.revision.removeListener(_refresh);
    _ticker?.cancel();
    TvDebugRecorder.stop();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent || event is KeyUpEvent) {
      final type = event is KeyDownEvent
          ? 'down'
          : event is KeyRepeatEvent
              ? 'repeat'
              : 'up';
      _lastEvent = type;
      _lastKey = event.logicalKey.keyLabel.isNotEmpty
          ? event.logicalKey.keyLabel
          : event.logicalKey.debugName ?? event.logicalKey.keyId.toString();
      _keyCount += 1;
      TvDebugRecorder.record('KEY count=$_keyCount event=$_lastEvent key=$_lastKey focus=$_primaryFocus route=$_route');
      _refresh();
    }

    // Diagnostics only. Never consume remote input.
    return false;
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;

      _frameCount += 1;
      _lastBuildMs = buildMs;
      _lastRasterMs = rasterMs;
      _lastFrameMs = totalMs;
      _maxFrameMs = totalMs > _maxFrameMs ? totalMs : _maxFrameMs;

      if (totalMs > 30) _jank30Count += 1;
      if (totalMs > 50) _jank50Count += 1;

      _recentFrameMs.add(totalMs);
      while (_recentFrameMs.length > 60) {
        _recentFrameMs.removeFirst();
      }

      if (_recentFrameMs.isEmpty) {
        _avgFrameMs = totalMs;
      } else {
        var sum = 0.0;
        for (final value in _recentFrameMs) {
          sum += value;
        }
        _avgFrameMs = sum / _recentFrameMs.length;
      }

      if (totalMs > 50) {
        TvDebugRecorder.record(
          'JANK_BAD frame=${_ms(totalMs)} build=${_ms(buildMs)} raster=${_ms(rasterMs)} '
          'focus=$_primaryFocus route=$_route',
        );
      } else if (totalMs > 30) {
        TvDebugRecorder.record(
          'JANK_WARN frame=${_ms(totalMs)} build=${_ms(buildMs)} raster=${_ms(rasterMs)} '
          'focus=$_primaryFocus route=$_route',
        );
      }
    }
  }

  void _refresh([bool record = false]) {
    if (!mounted) return;

    final primary = FocusManager.instance.primaryFocus;
    final label = primary?.debugLabel;
    final contextAlive = primary?.context != null;
    final route = _routeName();

    final cache = PaintingBinding.instance.imageCache;
    final bytes = cache.currentSizeBytes;

    setState(() {
      _primaryFocus = [
        label == null || label.isEmpty ? primary.runtimeType.toString() : label,
        contextAlive ? 'ctx' : 'noctx',
      ].join('/');
      _route = route;
      _lastError = TvGlobalDebugErrors.lastError.value;

      _imageCount = cache.currentSize;
      _imageMax = cache.maximumSize;
      _imageLive = cache.liveImageCount;
      _imagePending = cache.pendingImageCount;
      _imageMb = bytes / (1024 * 1024);
    });

    if (record) {
      final second = _uptime.elapsed.inSeconds;
      if (second != _lastRecordedSecond) {
        _lastRecordedSecond = second;
        TvDebugRecorder.record(
          'SAMPLE up=${second}s route=$_route focus=$_primaryFocus '
          'frame=${_ms(_lastFrameMs)} avg=${_ms(_avgFrameMs)} max=${_ms(_maxFrameMs)} '
          'build=${_ms(_lastBuildMs)} raster=${_ms(_lastRasterMs)} '
          'jank30=$_jank30Count jank50=$_jank50Count '
          'img=${_mb(_imageMb)} cache=$_imageCount/$_imageMax live=$_imageLive pending=$_imagePending '
          'err=$_lastError',
        );
      }
    }
  }

  String _routeName() {
    try {
      final route = ModalRoute.of(context);
      final name = route?.settings.name;
      if (name != null && name.isNotEmpty) return name;
      if (route == null) return 'no-route';
      return route.runtimeType.toString();
    } catch (_) {
      return 'route?';
    }
  }

  String _ms(double value) => value <= 0 ? '-' : '${value.toStringAsFixed(1)}ms';
  String _mb(double value) => '${value.toStringAsFixed(1)}MB';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (kDebugMode || _forceVisible) _hud(context),
      ],
    );
  }

  Widget _hud(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final size = media?.size;
    final dpr = media?.devicePixelRatio.toStringAsFixed(2) ?? '-';
    final seconds = (_uptime.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final sizeText = size == null
        ? '-'
        : '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}@$dpr';

    final perfStatus = _lastFrameMs > 50
        ? 'BAD'
        : _lastFrameMs > 30
            ? 'WARN'
            : 'OK';

    final imageStatus = _imageMb > 90
        ? 'HIGH'
        : _imageMb > 55
            ? 'MID'
            : 'OK';

    final lines = <String>[
      'LIVEGO PERF REC HUD',
      'up=${seconds}s keys=$_keyCount last=$_lastEvent/$_lastKey',
      'focus=$_primaryFocus',
      'route=$_route screen=$sizeText',
      'frame=$perfStatus last=${_ms(_lastFrameMs)} avg=${_ms(_avgFrameMs)} max=${_ms(_maxFrameMs)}',
      'build=${_ms(_lastBuildMs)} raster=${_ms(_lastRasterMs)} jank30=$_jank30Count jank50=$_jank50Count',
      'img=$imageStatus cache=$_imageCount/$_imageMax live=$_imageLive pending=$_imagePending mem=${_mb(_imageMb)}',
      'rec=${TvDebugRecorder.lastStatus} lines=${TvDebugRecorder.lineCount}',
      'file=Download/LiveGoDebug/livego_debug_record.txt',
      if (_lastError != '-') 'ERR=$_lastError',
      'mode=global-root perf recorder no-consume',
    ];

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 760),
            decoration: BoxDecoration(
              color: const Color(0xE6000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22D3EE).withOpacity(0.75)),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 16),
              ],
            ),
            child: Text(
              lines.join('\n'),
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.10,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
