import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../services/api/api_platform.dart';
import '../theme/tv_focus_style.dart';
import '../focus/tv_focus_utils.dart';

class TvFirstSourceSetup extends StatefulWidget {
  final VoidCallback onDone;

  const TvFirstSourceSetup({super.key, required this.onDone});

  @override
  State<TvFirstSourceSetup> createState() => _TvFirstSourceSetupState();
}

class _TvFirstSourceSetupState extends State<TvFirstSourceSetup> {
  static const int _maxActive = 6;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-first-source-root');
  final FocusNode _saveNode = FocusNode(skipTraversal: true, debugLabel: 'tv-first-source-save');
  final List<FocusNode> _nodes = <FocusNode>[];

  late final List<String> _platforms;
  late final Set<String> _selected;
  int _index = 0;
  bool _saving = false;
  Timer? _focusRetryTimer;

  @override
  void initState() {
    super.initState();
    _platforms = LiveGoCatalog.allPlatforms;
    final current = LiveGoSettings.homePlatforms.where(_platforms.contains).take(_maxActive).toList();
    final fallback = LiveGoSettings.defaultPlatforms.where(_platforms.contains).take(_maxActive).toList();
    _selected = <String>{...(current.isNotEmpty ? current : fallback)};
    if (_selected.isEmpty && _platforms.isNotEmpty) _selected.add(_platforms.first);
    for (var i = 0; i < _platforms.length; i++) {
      _nodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-first-source-$i'));
    }
    _scheduleInitialFocus();
  }

  @override
  void dispose() {
    _focusRetryTimer?.cancel();
    for (final node in _nodes) {
      node.dispose();
    }
    _rootNode.dispose();
    _saveNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleInitialFocus() {
    void run() {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      _rootNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_nodes.isNotEmpty) {
          _focusRow(_index.clamp(0, _nodes.length - 1).toInt());
        } else {
          _focusSave();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => run());
    _focusRetryTimer?.cancel();
    _focusRetryTimer = Timer(const Duration(milliseconds: 220), run);
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space;

  bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack;

  void _focusRow(int value) {
    if (_nodes.isEmpty) return;
    _index = value.clamp(0, _nodes.length - 1).toInt();
    tvFocusComfort(_nodes[_index], topMargin: 132, bottomMargin: 178);
    if (mounted) setState(() {});
  }

  void _focusSave() {
    tvFocus(_saveNode, alignment: 0.82);
    if (mounted) setState(() {});
  }

  void _toggleCurrent() {
    if (_nodes.isEmpty || _index < 0 || _index >= _platforms.length) return;
    _toggle(_platforms[_index]);
  }

  void _toggle(String slug) {
    if (_selected.contains(slug)) {
      if (_selected.length <= 1) {
        _showSnack('Minimal 1 platform harus aktif.');
        return;
      }
      _selected.remove(slug);
    } else {
      if (_selected.length >= _maxActive) {
        _showSnack('Maksimal 6 platform aktif di Beranda TV.');
        return;
      }
      _selected.add(slug);
    }
    setState(() {});
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface2,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _saveAndContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    final chosen = _platforms.where(_selected.contains).take(_maxActive).toList();
    if (chosen.isEmpty) {
      chosen.addAll(LiveGoSettings.defaultPlatforms.where(_platforms.contains).take(_maxActive));
    }
    if (chosen.isEmpty && _platforms.isNotEmpty) chosen.add(_platforms.first);

    if (chosen.isNotEmpty) {
      LiveGoSettings.activePlatforms
        ..clear()
        ..addAll(chosen);
      LiveGoSettings.homePlatforms
        ..clear()
        ..addAll(chosen);
      LiveGoSettings.defaultPlatform = chosen.first;
      for (final slug in chosen) {
        LiveGoSettings.setCategoriesFor(slug, LiveGoApiPlatforms.categoriesFor(slug).take(2).toList());
      }
    }
    LiveGoSettings.tvSourceSetupCompleted = true;
    await LiveGoLocalStore.saveSettings();
    if (!mounted) return;
    widget.onDone();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_saveNode.hasFocus) {
        _focusRow(_nodes.isEmpty ? 0 : _nodes.length - 1);
      } else {
        _focusRow(_index == 0 ? 0 : _index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_nodes.isEmpty || (!_saveNode.hasFocus && _index >= _nodes.length - 1)) {
        _focusSave();
      } else if (!_saveNode.hasFocus) {
        _focusRow(_index + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_saveNode.hasFocus) _focusRow(_nodes.isEmpty ? 0 : _nodes.length - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (!_saveNode.hasFocus && _nodes.isNotEmpty && _index >= _nodes.length - 1) _focusSave();
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (_saveNode.hasFocus || _nodes.isEmpty) {
        unawaited(_saveAndContinue());
      } else {
        _toggleCurrent();
        _focusRow(_index);
      }
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      unawaited(_saveAndContinue());
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  String _statusText(String slug) {
    final config = LiveGoApiPlatforms.bySlug(slug);
    if (config.isDobda) return 'BETA';
    if (config.isEncrypted) return 'DRM';
    return 'OK';
  }

  Color _statusColor(String slug) {
    final config = LiveGoApiPlatforms.bySlug(slug);
    if (config.isDobda) return Colors.orangeAccent;
    if (config.isEncrypted) return AppTheme.warning;
    return Colors.greenAccent;
  }

  String _description(String slug) {
    final config = LiveGoApiPlatforms.bySlug(slug);
    if (config.isDobda) return 'Nobuzero source. Bisa dipakai, tapi jangan aktifkan terlalu banyak.';
    if (config.isEncrypted) return 'Eksperimental. DRM/audio belum final.';
    if (config.isHls) return 'HLS source. Cocok untuk TV player.';
    return 'Direct source. Ringan untuk TV.';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Focus(
          focusNode: _rootNode,
          autofocus: true,
          skipTraversal: true,
          onKeyEvent: (_, event) => _handleKey(event),
          child: Container(
            color: Colors.black.withOpacity(0.78),
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(34, 30, 34, 34),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 940, maxHeight: 650),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF10243A), Color(0xFF07111F), Color(0xFF020617)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppTheme.cyan.withOpacity(0.28), width: 1.2),
                    boxShadow: [
                      const BoxShadow(color: Colors.black87, blurRadius: 36),
                      BoxShadow(color: AppTheme.cyan.withOpacity(0.12), blurRadius: 30),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppTheme.activeGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [TvFocusStyle.glow(0.10, 8)],
                            ),
                            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih Sumber Konten',
                                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Centang platform yang ingin tampil di Home. Maksimal 6 agar TV tetap ringan.',
                                  style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surface2,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppTheme.cyan.withOpacity(0.24)),
                            ),
                            child: Text(
                              '${_selected.length}/$_maxActive AKTIF',
                              style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _platforms.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada platform tersedia.',
                                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 130),
                                itemCount: _platforms.length,
                                itemBuilder: (context, index) {
                                  final slug = _platforms[index];
                                  return _SetupSourceRow(
                                    node: _nodes[index],
                                    title: LiveGoCatalog.label(slug),
                                    backend: LiveGoCatalog.backendLabel(slug),
                                    description: _description(slug),
                                    selected: _selected.contains(slug),
                                    statusText: _statusText(slug),
                                    statusColor: _statusColor(slug),
                                    onKey: (node, event) => _handleKey(event),
                                    onTap: () {
                                      _index = index;
                                      _toggle(slug);
                                      _focusRow(index);
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'OK pilih/batal • UP/DOWN pindah • BACK simpan pilihan dan mulai',
                              style: TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                            ),
                          ),
                          Focus(
                            focusNode: _saveNode,
                            skipTraversal: true,
                            onKeyEvent: (_, event) => _handleKey(event),
                            child: GestureDetector(
                              onTap: _saveAndContinue,
                              child: ListenableBuilder(
                                listenable: _saveNode,
                                builder: (context, _) {
                                  final focused = _saveNode.hasFocus;
                                  return AnimatedContainer(
                                    duration: TvFocusStyle.fast,
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.activeGradient,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: focused ? AppTheme.whiteGlow : Colors.white.withOpacity(0.14), width: focused ? 1.8 : 1),
                                      boxShadow: focused ? [TvFocusStyle.glow(0.08, 8)] : null,
                                    ),
                                    child: Text(
                                      _saving ? 'Menyimpan...' : 'Simpan & Mulai',
                                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupSourceRow extends StatelessWidget {
  final FocusNode node;
  final String title;
  final String backend;
  final String description;
  final bool selected;
  final String statusText;
  final Color statusColor;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _SetupSourceRow({
    required this.node,
    required this.title,
    required this.backend,
    required this.description,
    required this.selected,
    required this.statusText,
    required this.statusColor,
    required this.onKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10243A), Color(0xFF07111F)],
                      )
                    : LinearGradient(colors: [Colors.white.withOpacity(0.035), Colors.black.withOpacity(0.26)]),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: focused ? AppTheme.whiteGlow : (selected ? AppTheme.cyan.withOpacity(0.30) : Colors.white.withOpacity(0.08)),
                  width: focused ? 1.8 : 1,
                ),
                boxShadow: focused ? [TvFocusStyle.glow(0.07, 8)] : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: selected ? AppTheme.activeGradient : null,
                      color: selected ? null : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? Colors.white.withOpacity(0.18) : Colors.white12),
                    ),
                    child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, color: selected ? Colors.white : AppTheme.textMuted, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.white70,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColor.withOpacity(0.26)),
                              ),
                              child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$backend • $description',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.3, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    selected ? 'AKTIF' : 'OFF',
                    style: TextStyle(
                      color: selected ? AppTheme.cyan : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
