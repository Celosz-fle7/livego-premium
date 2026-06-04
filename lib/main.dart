import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'core/livego_settings.dart';
import 'core/livego_local_store.dart';
import 'mobile/mobile_app.dart';
import 'tv/tv_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiveGoLocalStore.init();
  runApp(const LiveGoPremiumApp());
}

class LiveGoPremiumApp extends StatelessWidget {
  const LiveGoPremiumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LiveGO Premium',
      theme: AppTheme.dark(),
      home: const AdaptiveRoot(),
    );
  }
}

class AdaptiveRoot extends StatelessWidget {
  const AdaptiveRoot({super.key});

  bool _isTvLayout(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    if (const bool.fromEnvironment('LIVEGO_FORCE_TV')) return true;
    if (LiveGoSettings.layoutMode == 'TV') return true;
    if (LiveGoSettings.layoutMode == 'Mobile') return false;

    // Aman untuk HP: landscape phone tidak boleh otomatis masuk TvApp.
    // Android TV/box biasanya punya width besar dan tinggi/shortestSide besar.
    final landscape = size.width > size.height;
    final bigLandscape = landscape && size.width >= 960 && size.shortestSide >= 540;
    return bigLandscape;
  }

  @override
  Widget build(BuildContext context) {
    return _isTvLayout(context) ? const TvApp() : const MobileApp();
  }
}
