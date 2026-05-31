import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../focus/tv_scroll_engine.dart';

class TvPlaceholderScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvPlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.onMoveToNav,
    this.focusTicket = 0,
  });

  @override
  State<TvPlaceholderScreen> createState() => _TvPlaceholderScreenState();
}

class _TvPlaceholderScreenState extends State<TvPlaceholderScreen> {
  final FocusNode _node = FocusNode(skipTraversal: true, debugLabel: 'tv-placeholder-card');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusAndReveal(_node);
    });
  }

  @override
  void didUpdateWidget(covariant TvPlaceholderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTicket != widget.focusTicket) {
      focusAndReveal(_node);
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      focusAndReveal(_node);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) return KeyEventResult.ignored;
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Focus(
        focusNode: _node,
        skipTraversal: true,
        onKeyEvent: _key,
        child: _FocusedPlaceholderCard(title: widget.title, icon: widget.icon, node: _node),
      ),
    );
  }
}

class _FocusedPlaceholderCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final FocusNode node;

  const _FocusedPlaceholderCard({required this.title, required this.icon, required this.node});

  @override
  State<_FocusedPlaceholderCard> createState() => _FocusedPlaceholderCardState();
}

class _FocusedPlaceholderCardState extends State<_FocusedPlaceholderCard> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(covariant _FocusedPlaceholderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      oldWidget.node.removeListener(_syncFocus);
      widget.node.addListener(_syncFocus);
      _syncFocus();
    }
  }

  @override
  void dispose() {
    widget.node.removeListener(_syncFocus);
    super.dispose();
  }

  void _syncFocus() {
    if (mounted) setState(() => _focused = widget.node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 430,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _focused ? AppTheme.cyan : const Color(0xFF1F3B55), width: _focused ? 2.4 : 1),
        boxShadow: _focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 22)] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: AppTheme.cyan, size: 68),
          const SizedBox(height: 20),
          Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 10),
          const Text('Tekan ← untuk kembali ke navbar', style: TextStyle(color: AppTheme.textSoft, fontSize: 16, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}
