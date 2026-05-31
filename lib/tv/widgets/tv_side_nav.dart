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
    _bind(widget.focusNodes);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncExpanded());
  }

  @override
  void didUpdateWidget(covariant TvSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNodes != widget.focusNodes) {
      _unbind(oldWidget.focusNodes);
      _bind(widget.focusNodes);
      _syncExpanded();
    }
  }

  @override
  void dispose() {
    _unbind(widget.focusNodes);
    super.dispose();
  }

  void _bind(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.addListener(_syncExpanded);
    }
  }

  void _unbind(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.removeListener(_syncExpanded);
    }
  }

  void _syncExpanded() {
    if (!mounted) return;
    final next = widget.focusNodes.any((node) => node.hasFocus);
    if (next != _expanded) setState(() => _expanded = next);
  }

  int _safe(int value) {
    if (widget.focusNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = widget.focusNodes.length - 1;
    if (value > max) return max;
    return value;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.focusNodes[_safe(index - 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.focusNodes[_safe(index + 1)].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onOpenContent(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.focusNodes[_safe(index)].requestFocus();
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      widget.onChanged(index);
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
            border: Border.all(color: _expanded ? AppTheme.cyan.withOpacity(0.35) : const Color(0xFF172A3E)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 22)],
          ),
          child: Column(
            children: [
              for (var i = 0; i < TvSideNav.items.length; i++) ...[
                _NavButton(
                  focusNode: widget.focusNodes[i],
                  icon: TvSideNav.items[i].icon,
                  label: TvSideNav.items[i].label,
                  active: i == widget.index,
                  expanded: _expanded,
                  logo: i == 0,
                  onTap: () => widget.onChanged(i),
                  onKey: (node, event) => _handleKey(i, event),
                ),
                if (i == 0) ...[
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _expanded ? 154 : 38,
                    height: 1,
                    color: Colors.white10,
                  ),
                  const SizedBox(height: 10),
                ] else if (i < TvSideNav.items.length - 1)
                  const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;
  final bool logo;

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
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final selected = focused || active;
        final height = logo ? 60.0 : 54.0;
        final collapsedWidth = logo ? 58.0 : 54.0;
        return Tooltip(
          message: label,
          child: Focus(
            focusNode: focusNode,
            skipTraversal: true,
            autofocus: false,
            onKeyEvent: onKey,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              focusColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                height: height,
                width: expanded ? 178 : collapsedWidth,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.cyan.withOpacity(focused ? 0.22 : 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 2 : 0),
                  boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 18)] : null,
                ),
                child: Row(
                  mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: selected ? AppTheme.cyan : Colors.white70, size: logo ? 30 : 27),
                    if (expanded) ...[
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white70,
                            fontSize: 14,
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
      },
    );
  }
}
