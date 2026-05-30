import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatefulWidget {
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

  @override
  State<TvSideNav> createState() => _TvSideNavState();
}

class _TvSideNavState extends State<TvSideNav> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    for (final node in widget.focusNodes) {
      node.addListener(_syncExpanded);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpanded());
  }

  @override
  void didUpdateWidget(covariant TvSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNodes != widget.focusNodes) {
      for (final node in oldWidget.focusNodes) {
        node.removeListener(_syncExpanded);
      }
      for (final node in widget.focusNodes) {
        node.addListener(_syncExpanded);
      }
      _syncExpanded();
    }
  }

  @override
  void dispose() {
    for (final node in widget.focusNodes) {
      node.removeListener(_syncExpanded);
    }
    super.dispose();
  }

  void _syncExpanded() {
    if (!mounted) return;
    final next = widget.focusNodes.any((node) => node.hasFocus);
    if (next != _expanded) setState(() => _expanded = next);
  }

  int _safeIndex(int value) => value.clamp(0, TvSideNav.items.length - 1);

  KeyEventResult _handleKey(BuildContext context, int i, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      widget.focusNodes[_safeIndex(i + 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.focusNodes[_safeIndex(i - 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.focusNodes[_safeIndex(i)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onOpenContent(i);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      widget.onChanged(i);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: _expanded ? 220 : 92,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 18, 10, 18),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF050D18).withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _expanded ? AppTheme.cyan.withOpacity(0.35) : const Color(0xFF172A3E)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 22)],
          ),
          child: Column(
            children: [
              _NavButton(
                focusNode: widget.focusNodes[0],
                icon: TvSideNav.items[0].$1,
                label: TvSideNav.items[0].$2,
                active: widget.index == 0,
                expanded: _expanded,
                logo: true,
                onTap: () => widget.onChanged(0),
                onKey: (node, event) => _handleKey(context, 0, event),
              ),
              const SizedBox(height: 12),
              Container(width: _expanded ? 150 : 40, height: 1, color: Colors.white10),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(TvSideNav.items.length - 1, (raw) {
                    final i = raw + 1;
                    return _NavButton(
                      focusNode: widget.focusNodes[i],
                      icon: TvSideNav.items[i].$1,
                      label: TvSideNav.items[i].$2,
                      active: i == widget.index,
                      expanded: _expanded,
                      onTap: () => widget.onChanged(i),
                      onKey: (node, event) => _handleKey(context, i, event),
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
  final bool expanded;
  final VoidCallback onTap;
  final bool logo;
  final FocusOnKeyCallback onKey;

  const _NavButton({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
    required this.onKey,
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
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.logo,
        onKey: widget.onKey,
        onFocusChange: (v) => setState(() => focused = v),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: widget.expanded ? 188 : 58,
            height: widget.logo ? 62 : 58,
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 14 : 0),
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [Color(0xFF123B54), Color(0xFF3C207E)]) : null,
              color: selected ? null : const Color(0xFF0A1422),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.65) : Colors.white10), width: focused ? 2.2 : 1),
              boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.25), blurRadius: 18)] : null,
            ),
            child: Row(
              mainAxisAlignment: widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: selected ? Colors.white : Colors.white54, size: widget.logo ? 28 : 24),
                if (widget.expanded) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: widget.logo ? 13 : 12.5,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
