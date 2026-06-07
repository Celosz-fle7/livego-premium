import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/livego_settings.dart';
import 'core/livego_local_store.dart';
import 'tv/tv_app.dart';
import 'tv/debug/tv_global_debug_hud.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      TvGlobalDebugErrors.reportFlutter(details);
      debugPrint('LIVEGO FLUTTER ERROR: ${details.exception}');
      final stack = details.stack;
      if (stack != null) debugPrint(stack.toString());
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      TvGlobalDebugErrors.reportFlutter(details);
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(22),
                constraints: const BoxConstraints(maxWidth: 900),
                decoration: BoxDecoration(
                  color: const Color(0xEE000000),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Text(
                  'LIVEGO WIDGET ERROR\\n${details.exception}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    };

    await LiveGoLocalStore.init();
    runApp(const LiveGoPremiumApp());
  }, (Object error, StackTrace stackTrace) {
    TvGlobalDebugErrors.report(error, stackTrace);
    debugPrint('LIVEGO ZONE ERROR: $error');
    debugPrint(stackTrace.toString());
  });
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
      // This helps diagnose/remove white frames during TV Player handoff
      // without touching Android native resources yet.
      builder: (context, child) {
        return ColoredBox(
          color: Colors.black,
          child: TvGlobalDebugHud(
            child: child ?? const SizedBox.shrink(),
          ),
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
    // Android TV build is hard-locked to TV UI.
    //
    // Mobile UI/player still exists in source for backup, but it must never be
    // selected by the TV APK. This removes any chance that old saved settings,
    // window metrics, or landscape detection accidentally route TV users into
    // MobileApp/MobilePlayerScreen.
    LiveGoSettings.layoutMode = 'TV';
    return const TvApp();
  }
}
