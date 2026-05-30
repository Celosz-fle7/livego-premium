import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatelessWidget {
  final int index;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onOpenContent;

  const TvSideNav({
    super.key,
    required this.index,
    required this.focusNodes,
    required this.onChanged,
    required this.onOpenContent,
  });

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.download_rounded, 'Unduhan'),
    (Icons.history_rounded, 'Riwayat'),
    (Icons.favorite_border_rounded, 'Favorit'),
    (Icons.person_rounded, 'Akun'),
    (Icons.search_rounded, 'Cari'),
  ];

  KeyEventResult _handleKey(BuildContext context, int i, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = (i + 1).clamp(0, items.length - 1);
      focusNodes[next].requestFocus();
      onChanged(next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final prev = (i - 1).clamp(0, items.length - 1);
      focusNodes[prev].requestFocus();
      onChanged(prev);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      onOpenContent(i);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      onOpenContent(i);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 86,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 18, 8, 18),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF050D18).withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF172A3E)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 22)],
          ),
          child: Column(
            children: [
              _NavButton(
                focusNode: focusNodes[0],
                icon: items[0].$1,
                label: items[0].$2,
                active: index == 0,
                logo: true,
                onTap: () => onOpenContent(0),
                onKeyEvent: (node, event) => _handleKey(context, 0, event),
              ),
              const SizedBox(height: 12),
              Container(width: 40, height: 1, color: Colors.white10),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(items.length - 1, (raw) {
                    final i = raw + 1;
                    return _NavButton(
                      focusNode: focusNodes[i],
                      icon: items[i].$1,
                      label: items[i].$2,
                      active: i == index,
                      onTap: () => onOpenContent(i),
                      onKeyEvent: (node, event) => _handleKey(context, i, event),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool logo;
  final FocusOnKeyEventCallback onKeyEvent;

  const _NavButton({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.onKeyEvent,
    this.logo = false,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = focused || widget.active;
    return Tooltip(
      message: widget.label,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        onKeyEvent: widget.onKeyEvent,
        onShowFocusHighlight: (v) => setState(() => focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap();
            return null;
          }),
        },
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.logo ? 54 : 58,
            height: widget.logo ? 58 : 58,
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [Color(0xFF123B54), Color(0xFF3C207E)]) : null,
              color: selected ? null : const Color(0xFF0A1422),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.65) : Colors.white10), width: focused ? 2.2 : 1),
              boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.25), blurRadius: 18)] : null,
            ),
            child: Icon(widget.icon, color: selected ? Colors.white : Colors.white54, size: widget.logo ? 30 : 27),
          ),
        ),
      ),
    );
  }
}
