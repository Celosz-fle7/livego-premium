import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Gerbang splash saat masuk aplikasi.
///
/// Tampilkan logo LiveGO di tengah + animasi loading di BAWAH (bukan di
/// tengah), lalu ganti ke [child] setelah jeda singkat. Splash ini hanya
/// transisi branding — init berat (runtime detect + store) sudah selesai
/// di main() sebelum runApp.
class LiveGoSplashGate extends StatefulWidget {
  final Widget child;

  const LiveGoSplashGate({super.key, required this.child});

  @override
  State<LiveGoSplashGate> createState() => _LiveGoSplashGateState();
}

class _LiveGoSplashGateState extends State<LiveGoSplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return const _LiveGoSplashScreen();
  }
}

class _LiveGoSplashScreen extends StatefulWidget {
  const _LiveGoSplashScreen();

  @override
  State<_LiveGoSplashScreen> createState() => _LiveGoSplashScreenState();
}

class _LiveGoSplashScreenState extends State<_LiveGoSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logoWidth = (width * 0.52).clamp(180.0, 300.0);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Glow ungu kiri atas + teal kanan bawah (vibe screenshot).
          Positioned(
            top: -140,
            left: -140,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B2FF7).withOpacity(0.38),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            right: -160,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00B4D8).withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Logo di TENGAH (crop dari screenshot).
          Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Opacity(
                opacity: 0.85 + 0.15 * _pulse.value,
                child: Image.asset(
                  'assets/images/livego_logo.png',
                  width: logoWidth,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Animasi loading di BAWAH.
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Memuat LiveGO...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Spacer(),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppTheme.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(
                          minHeight: 7,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.cyan,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sebentar ya, menyiapkan beranda.',
                        style: TextStyle(
                          color: AppTheme.textSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
