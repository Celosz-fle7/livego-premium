import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';

class TvNavItem {
  final IconData icon;
  final String label;

  const TvNavItem(this.icon, this.label);
}

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
    TvNavItem(Icons.home_rounded, 'Home'),
    TvNavItem(Icons.history_rounded, 'Histori'),
    TvNavItem(Icons.search_rounded, 'Cari'),
    TvNavItem(Icons.favorite_rounded, 'Favorit'),
    TvNavItem(Icons.download_rounded, 'Unduhan'),
    TvNavItem(Icons.person_rounded, 'Akun'),
  ];

  @override
  State<TvSideNav> createState() => _TvSideNavState();
}

class _TvSideNavState extends State<TvSideNav> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _bindNodeListeners(widget.focusNodes);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpanded());
  }

  @override
  void didUpdateWidget(covariant TvSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNodes != widget.focusNodes) {
      _unbindNodeListeners(oldWidget.focusNodes);
      _bindNodeListeners(widget.focusNodes);
      _syncExpanded();
    }
  }

  @override
  void dispose() {
    _unbindNodeListeners(widget.focusNodes);
    super.dispose();
  }

  void _bindNodeListeners(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.addListener(_syncExpanded);
    }
  }

  void _unbindNodeListeners(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.removeListener(_syncExpanded);
    }
  }

  void _syncExpanded() {
    if (!mounted) return;
    final next = widget.focusNodes.any((node) => node.hasFocus);
    if (next != _expanded) setState(() => _expanded = next);
  }

  int _safeIndex(int value) {
    final max = TvSideNav.items.length - 1;
    if (value < 0) return 0;
    if (value > max) return max;
    return value;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleKey(int i, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

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

    if (_isSelect(key)) {
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
        width: _expanded ? 214 : 88,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 18, 10, 18),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF050D18).withOpacity(0.97),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: _expanded ? AppTheme.cyan.withOpacity(0.35) : const Color(0xFF172A3E),
            ),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 22)],
          ),
          child: Column(
            children: [
              _NavButton(
                focusNode: widget.focusNodes[0],
                icon: TvSideNav.items[0].icon,
                label: TvSideNav.items[0].label,
                active: widget.index == 0,
                expanded: _expanded,
                logo: true,
                onTap: () => widget.onChanged(0),
                onKey: (node, event) => _handleKey(0, event),
              ),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _expanded ? 154 : 38,
                height: 1,
                color: Colors.white10,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(TvSideNav.items.length - 1, (raw) {
                    final i = raw + 1;
                    return _NavButton(
                      focusNode: widget.focusNodes[i],
                      icon: TvSideNav.items[i].icon,
                      label: TvSideNav.items[i].label,
                      active: i == widget.index,
                      expanded: _expanded,
                      onTap: () => widget.onChanged(i),
                      onKey: (node, event) => _handleKey(i, event),
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
  final FocusOnKeyEventCallback onKey;

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
    final height = widget.logo ? 60.0 : 54.0;
    final collapsedWidth = widget.logo ? 58.0 : 54.0;

    return Tooltip(
      message: widget.label,
      child: Focus(
        focusNode: widget.focusNode,
        skipTraversal: true,
        autofocus: false,
        onKeyEvent: widget.onKey,
        onFocusChange: (v) => setState(() => focused = v),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: widget.expanded ? 182 : collapsedWidth,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 12 : 0),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF123B54), Color(0xFF3C207E)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: selected ? null : const Color(0xFF0A1422),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: focused
                    ? AppTheme.cyan
                    : (widget.active ? AppTheme.cyan.withOpacity(0.62) : Colors.white10),
                width: focused ? 2.2 : 1,
              ),
              boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.24), blurRadius: 18)] : null,
            ),
            child: Row(
              mainAxisAlignment: widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: focused ? 4 : 0,
                  height: 28,
                  margin: EdgeInsets.only(right: focused && widget.expanded ? 10 : 0),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Icon(
                  widget.icon,
                  color: selected ? Colors.white : Colors.white54,
                  size: widget.logo ? 28 : 23,
                ),
                if (widget.expanded) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: widget.logo ? 13 : 12.2,
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
