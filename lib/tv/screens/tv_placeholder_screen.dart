import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../utils/tv_focus_utils.dart';

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
  void didUpdateWidget(covariant TvPlaceholderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTicket != widget.focusTicket) {
      tvFocus(_node, alignment: 0.5);
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Focus(
        focusNode: _node,
        skipTraversal: true,
        autofocus: false,
        onKeyEvent: _key,
        child: _FocusedPlaceholderCard(title: widget.title, icon: widget.icon, node: _node),
      ),
    );
  }
}

class _FocusedPlaceholderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final FocusNode node;

  const _FocusedPlaceholderCard({required this.title, required this.icon, required this.node});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 430,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220).withOpacity(0.92),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: focused ? AppTheme.cyan : const Color(0xFF1F3B55), width: focused ? 2.4 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 22)] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.cyan, size: 68),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(height: 10),
              const Text('Tekan ← untuk kembali ke navbar', style: TextStyle(color: AppTheme.textSoft, fontSize: 16, decoration: TextDecoration.none)),
            ],
          ),
        );
      },
    );
  }
}
