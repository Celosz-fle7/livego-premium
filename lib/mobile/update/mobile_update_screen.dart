import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../shared/widgets/glow_container.dart';
import '../../tv/update/tv_update_model.dart';
import '../../tv/update/tv_update_service.dart';

enum _MobileUpdateStatus { idle, checking, noUpdate, found, downloading, ready, error }

class MobileUpdateScreen extends StatefulWidget {
  const MobileUpdateScreen({super.key});

  @override
  State<MobileUpdateScreen> createState() => _MobileUpdateScreenState();
}

class _MobileUpdateScreenState extends State<MobileUpdateScreen> {
  final TvUpdateService _service = const TvUpdateService();

  _MobileUpdateStatus _status = _MobileUpdateStatus.idle;
  TvUpdateAppInfo? _current;
  TvUpdateInfo? _latest;
  String _message = 'Cek versi terbaru LiveGo Premium.';
  String _apkPath = '';
  double _progress = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkUpdate());
  }

  Future<void> _checkUpdate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = _MobileUpdateStatus.checking;
      _message = 'Mengecek pembaruan...';
      _progress = 0;
    });
    try {
      final result = await _service.check();
      if (!mounted) return;
      setState(() {
        _current = result.current;
        _latest = result.latest;
        _status = result.updateAvailable ? _MobileUpdateStatus.found : _MobileUpdateStatus.noUpdate;
        _message = result.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _MobileUpdateStatus.error;
        _message = 'Belum bisa cek pembaruan. Pastikan koneksi internet aktif lalu coba lagi.';
        _busy = false;
      });
    }
  }

  Future<void> _downloadUpdate() async {
    final latest = _latest;
    if (_busy || latest == null) return;
    setState(() {
      _busy = true;
      _status = _MobileUpdateStatus.downloading;
      _message = 'Mengunduh APK pembaruan...';
      _progress = 0;
    });
    try {
      final result = await _service.downloadApk(
        latest,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        _apkPath = result.path;
        _status = _MobileUpdateStatus.ready;
        _message = 'APK siap di-install. Ketuk Install Update untuk membuka konfirmasi Android.';
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _MobileUpdateStatus.error;
        _message = 'Download pembaruan gagal. Coba lagi dengan koneksi yang lebih stabil.';
        _busy = false;
      });
    }
  }

  Future<void> _installUpdate() async {
    if (_apkPath.isEmpty) return;
    try {
      await _service.openInstaller(_apkPath);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _MobileUpdateStatus.error;
        _message = 'Installer Android belum bisa dibuka. Periksa izin install APK dari sumber ini.';
      });
    }
  }

  String get _primaryLabel {
    switch (_status) {
      case _MobileUpdateStatus.found:
        return 'Download Update';
      case _MobileUpdateStatus.ready:
        return 'Install Update';
      case _MobileUpdateStatus.checking:
        return 'Mengecek...';
      case _MobileUpdateStatus.downloading:
        return 'Download ${(100 * _progress).clamp(0, 100).round()}%';
      case _MobileUpdateStatus.idle:
      case _MobileUpdateStatus.noUpdate:
      case _MobileUpdateStatus.error:
        return 'Cek Lagi';
    }
  }

  VoidCallback? get _primaryAction {
    if (_busy) return null;
    switch (_status) {
      case _MobileUpdateStatus.found:
        return () => unawaited(_downloadUpdate());
      case _MobileUpdateStatus.ready:
        return () => unawaited(_installUpdate());
      case _MobileUpdateStatus.idle:
      case _MobileUpdateStatus.noUpdate:
      case _MobileUpdateStatus.error:
        return () => unawaited(_checkUpdate());
      case _MobileUpdateStatus.checking:
      case _MobileUpdateStatus.downloading:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final latest = _latest;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 42),
          children: [
            IconButton(
              alignment: Alignment.centerLeft,
              onPressed: _busy ? null : () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            GlowContainer(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(gradient: AppTheme.activeGradient, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text('Periksa Pembaruan', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_message, style: const TextStyle(color: AppTheme.textSoft, height: 1.4, fontWeight: FontWeight.w700)),
                  if (_status == _MobileUpdateStatus.downloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _progress <= 0 ? null : _progress, color: AppTheme.cyan, backgroundColor: Colors.white12),
                  ],
                  const SizedBox(height: 18),
                  if (current != null) Text('Versi saat ini: ${current.versionName} (${current.versionCode})', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                  if (latest != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Versi terbaru: ${latest.versionName} (${latest.versionCode})', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _primaryAction,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(_primaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
