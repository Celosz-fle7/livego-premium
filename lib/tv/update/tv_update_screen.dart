import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../layout/tv_safe_zone.dart';
import 'tv_update_model.dart';
import 'tv_update_service.dart';

enum _UpdateStatus {
  idle,
  checking,
  noUpdate,
  found,
  downloading,
  ready,
  error,
}

class TvUpdateScreen extends StatefulWidget {
  const TvUpdateScreen({super.key});

  @override
  State<TvUpdateScreen> createState() => _TvUpdateScreenState();
}

class _TvUpdateScreenState extends State<TvUpdateScreen> {
  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-update-root');
  final TvUpdateService _service = const TvUpdateService();

  _UpdateStatus _status = _UpdateStatus.idle;
  TvUpdateAppInfo? _current;
  TvUpdateInfo? _latest;
  String _message = 'Cek update terbaru dari GitHub Release.';
  String _apkPath = '';
  double _progress = 0.0;
  int _cursor = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootNode.requestFocus();
      unawaited(_checkUpdate());
    });
  }

  @override
  void dispose() {
    _rootNode.dispose();
    super.dispose();
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (event is KeyRepeatEvent && (_isBack(key) || _isSelect(key))) {
      return KeyEventResult.handled;
    }

    if (_isBack(key) || key == LogicalKeyboardKey.arrowLeft) {
      if (!_busy) Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      setState(() => _cursor = _cursor == 0 ? 1 : 0);
      return KeyEventResult.handled;
    }

    if (_isSelect(key) || key == LogicalKeyboardKey.arrowRight) {
      _activate();
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  Future<void> _checkUpdate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = _UpdateStatus.checking;
      _message = 'Mengecek update...';
      _progress = 0;
      _cursor = 0;
    });

    try {
      final result = await _service.check();
      if (!mounted) return;
      setState(() {
        _current = result.current;
        _latest = result.latest;
        _status = result.updateAvailable ? _UpdateStatus.found : _UpdateStatus.noUpdate;
        _message = result.message;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _UpdateStatus.error;
        _message = 'Gagal cek update: $error';
        _busy = false;
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final latest = _latest;
    if (_busy || latest == null) return;

    setState(() {
      _busy = true;
      _status = _UpdateStatus.downloading;
      _message = 'Mengunduh APK update...';
      _progress = 0;
      _cursor = 0;
    });

    try {
      final result = await _service.downloadApk(
        latest,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        _apkPath = result.path;
        _status = _UpdateStatus.ready;
        _message = 'APK siap di-install. Pilih Install Update.';
        _busy = false;
        _cursor = 0;
      });
      await _openInstaller();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _UpdateStatus.error;
        _message = 'Gagal download update: $error';
        _busy = false;
      });
    }
  }

  Future<void> _openInstaller() async {
    if (_apkPath.trim().isEmpty) return;
    try {
      await _service.openInstaller(_apkPath);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _UpdateStatus.error;
        _message = 'Gagal buka installer: $error';
        _busy = false;
      });
    }
  }

  void _activate() {
    if (_cursor == 1) {
      if (!_busy) Navigator.of(context).maybePop();
      return;
    }

    switch (_status) {
      case _UpdateStatus.found:
        unawaited(_downloadAndInstall());
        break;
      case _UpdateStatus.ready:
        unawaited(_openInstaller());
        break;
      case _UpdateStatus.checking:
      case _UpdateStatus.downloading:
        break;
      case _UpdateStatus.idle:
      case _UpdateStatus.noUpdate:
      case _UpdateStatus.error:
        unawaited(_checkUpdate());
        break;
    }
  }

  String get _primaryLabel {
    switch (_status) {
      case _UpdateStatus.found:
        return 'Download Update';
      case _UpdateStatus.ready:
        return 'Install Update';
      case _UpdateStatus.checking:
        return 'Mengecek...';
      case _UpdateStatus.downloading:
        return 'Download ${(100 * _progress).clamp(0, 100).round()}%';
      case _UpdateStatus.noUpdate:
      case _UpdateStatus.error:
      case _UpdateStatus.idle:
        return 'Cek Lagi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final latest = _latest;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Focus(
            focusNode: _rootNode,
            autofocus: true,
            skipTraversal: true,
            onKeyEvent: _handleKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TvSafeZone.accountSide,
                TvSafeZone.accountTop,
                TvSafeZone.accountSide,
                TvSafeZone.bottomReach,
              ),
              children: [
                const Text(
                  'Update Aplikasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Update langsung dari aplikasi tanpa hapus data. Android tetap akan menampilkan layar konfirmasi install.',
                  style: TextStyle(
                    color: AppTheme.textSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 26),
                _InfoCard(
                  title: 'Status',
                  body: _message,
                  footer: [
                    if (current != null) 'Versi sekarang: ${current.versionName} (${current.versionCode})',
                    if (latest != null) 'Versi terbaru: ${latest.versionName} (${latest.versionCode})',
                  ].join('\n'),
                  progress: _status == _UpdateStatus.downloading ? _progress : null,
                ),
                if (latest != null && latest.changelog.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _InfoCard(
                    title: 'Catatan Update',
                    body: latest.changelog.map((e) => '• $e').join('\n'),
                    footer: latest.requiredUpdate ? 'Update ini ditandai wajib.' : 'Update ini opsional.',
                  ),
                ],
                const SizedBox(height: 24),
                _ActionRow(
                  primaryLabel: _primaryLabel,
                  secondaryLabel: 'Kembali',
                  primaryFocused: _cursor == 0,
                  secondaryFocused: _cursor == 1,
                  busy: _busy,
                  onPrimary: _activate,
                  onSecondary: () {
                    if (!_busy) Navigator.of(context).maybePop();
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Syarat update menimpa aplikasi lama: packageName sama, signing key sama, dan versionCode APK baru lebih tinggi.',
                  style: TextStyle(
                    color: AppTheme.textSoft.withOpacity(0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final String footer;
  final double? progress;

  const _InfoCard({
    required this.title,
    required this.body,
    this.footer = '',
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.72), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(body, style: TextStyle(color: AppTheme.textSoft, fontSize: 15, height: 1.35, fontWeight: FontWeight.w700)),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white12,
              ),
            ),
          ],
          if (footer.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(footer, style: TextStyle(color: AppTheme.textSoft.withOpacity(0.82), fontSize: 13, height: 1.35, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String primaryLabel;
  final String secondaryLabel;
  final bool primaryFocused;
  final bool secondaryFocused;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _ActionRow({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryFocused,
    required this.secondaryFocused,
    required this.busy,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Button(
          label: primaryLabel,
          focused: primaryFocused,
          disabled: busy,
          onTap: busy ? null : onPrimary,
        ),
        const SizedBox(width: 14),
        _Button(
          label: secondaryLabel,
          focused: secondaryFocused,
          disabled: busy,
          onTap: busy ? null : onSecondary,
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final bool focused;
  final bool disabled;
  final VoidCallback? onTap;

  const _Button({
    required this.label,
    required this.focused,
    required this.disabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = focused ? Colors.white : AppTheme.borderSoft.withOpacity(0.54);
    final background = focused ? AppTheme.cyan : AppTheme.surface2.withOpacity(0.82);

    return InkWell(
      canRequestFocus: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 220,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? background.withOpacity(0.48) : background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: focused ? 2.4 : 1.2),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppTheme.cyan.withOpacity(0.32),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled ? Colors.white54 : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
