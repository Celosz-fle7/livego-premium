import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvGlobalDebugErrors {
  static final ValueNotifier<String> lastError = ValueNotifier<String>('-');

  static void report(Object error, [StackTrace? stackTrace]) {
    final raw = '$error';
    final clean = raw.replaceAll('\n', ' ').trim();
    final text = clean.isEmpty ? error.runtimeType.toString() : clean;
    lastError.value = text.length > 220 ? '${text.substring(0, 220)}...' : text;
    debugPrint('LIVEGO GLOBAL ERROR HUD: ${lastError.value}');
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }

  static void reportFlutter(FlutterErrorDetails details) {
    report(details.exception, details.stack);
  }
}

/// Global TV debug overlay.
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
  // Temporary diagnostic flag. Keep HUD visible even when the APK is
  // built in release/profile mode by CI, because kDebugMode can be false
  // in Telegram-distributed APKs.
  static const bool _forceVisible = true;

  final Stopwatch _uptime = Stopwatch()..start();
  Timer? _ticker;

  String _lastKey = '-';
  String _lastEvent = '-';
  int _keyCount = 0;
  String _primaryFocus = '-';
  String _route = '-';
  String _lastError = '-';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    TvGlobalDebugErrors.lastError.addListener(_refresh);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    TvGlobalDebugErrors.lastError.removeListener(_refresh);
    _ticker?.cancel();
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
      _refresh();
    }

    // Diagnostics only. Never consume remote input.
    return false;
  }

  void _refresh() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    final label = primary?.debugLabel;
    final contextAlive = primary?.context != null;
    final route = _routeName();

    setState(() {
      _primaryFocus = [
        label == null || label.isEmpty ? primary.runtimeType.toString() : label,
        contextAlive ? 'ctx' : 'noctx',
      ].join('/');
      _route = route;
      _lastError = TvGlobalDebugErrors.lastError.value;
    });
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

    final lines = <String>[
      'LIVEGO GLOBAL DEBUG HUD',
      'up=${seconds}s keys=$_keyCount last=$_lastEvent/$_lastKey',
      'focus=$_primaryFocus',
      'route=$_route',
      'screen=$sizeText',
      'mode=global-root no-consume',
      if (_lastError != '-') 'ERR=$_lastError',
    ];

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 560),
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
                fontSize: 12,
                height: 1.15,
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
