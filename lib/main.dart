import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'mobile/mobile_app.dart';
import 'tv/tv_app.dart';

void main() {
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

  @override
  Widget build(BuildContext context) {
    // Stabilkan dulu: HP portrait/landscape tetap MobileApp.
    // TV mode nanti dibuat manual dari setting/device detection yang lebih aman.
    return const MobileApp();
  }
}
