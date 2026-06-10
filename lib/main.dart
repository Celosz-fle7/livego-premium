import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/livego_settings.dart';
import 'core/livego_local_store.dart';
import 'mobile/mobile_app.dart';
import 'tv/tv_app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('LIVEGO FLUTTER ERROR: ${details.exception}');
      final stack = details.stack;
      if (stack != null) debugPrint(stack.toString());
    };

    final isTvRuntime = await LiveGoRuntimeDetector.isTvRuntime();
    LiveGoSettings.applyRuntimeLayoutGuard(isTvRuntime: isTvRuntime);
    await LiveGoLocalStore.init();
    runApp(
      const ProviderScope(
        child: LiveGoPremiumApp(),
      ),
    );
  }, (Object error, StackTrace stackTrace) {
    debugPrint('LIVEGO ZONE ERROR: $error');
    debugPrint(stackTrace.toString());
  });
}

class LiveGoRuntimeDetector {
  const LiveGoRuntimeDetector._();

  static const MethodChannel _channel = MethodChannel('livego/runtime');

  static Future<bool> isTvRuntime() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final value = await _channel.invokeMethod<bool>('isTvRuntime');
      return value ?? false;
    } on PlatformException catch (e) {
      debugPrint('LIVEGO RUNTIME DETECT ERROR: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class LiveGoPremiumApp extends StatelessWidget {
  const LiveGoPremiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LiveGO Premium',
      theme: AppTheme.dark(),

      // Root black guard:
      // Keep the whole Flutter app canvas black underneath every route.
      builder: (context, child) {
        return ColoredBox(
          color: Colors.black,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AdaptiveRoot(),
    );
  }
}

class AdaptiveRoot extends StatelessWidget {
  const AdaptiveRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final effectiveLayout = LiveGoSettings.effectiveLayoutModeForRuntime(
      isTvRuntime: LiveGoSettings.runtimeLockedToTv,
    );

    if (effectiveLayout == LiveGoSettings.layoutTv) return const TvApp();
    if (effectiveLayout == LiveGoSettings.layoutMobile) return const MobileApp();

    return _prefersTvLayout(context) ? const TvApp() : const MobileApp();
  }

  bool _prefersTvLayout(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    final size = media.size;
    return size.width >= 900 && size.width > size.height;
  }
}
