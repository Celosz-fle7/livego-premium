import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/livego_settings.dart';
import 'core/livego_local_store.dart';
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
    // Android TV build is hard-locked to TV UI.
    LiveGoSettings.layoutMode = 'TV';
    return const TvApp();
  }
}
