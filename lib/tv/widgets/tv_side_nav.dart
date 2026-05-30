import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onClose;
  final bool expanded;
  final FocusNode focusNode;

  const TvSideNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onClose,
    required this.expanded,
    required this.focusNode,
  });

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.history_rounded, 'Histori'),
    (Icons.search_rounded, 'Search'),
    (Icons.favorite_border_rounded, 'Favorit'),
    (Icons.person_rounded, 'Akun'),
    (Icons.settings_rounded, 'Setting'),
  ];

  @override
  State<TvSideNav> createState() => _TvSideNavState();
}

class _TvSideNavState extends State<TvSideNav> {
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(TvSideNav.items.length, (i) => FocusNode(debugLabel: 'tv-nav-$i'));
  }

  @override
  void didUpdateWidget(covariant TvSideNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.expanded && widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nodes[widget.index.clamp(0, _nodes.length - 1)].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: _handleKey,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 255,
          margin: const EdgeInsets.fromLTRB(22, 22, 0, 22),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: const Color(0xFF24344A)),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 34)],
          ),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                  boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.35), blurRadius: 20)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: TvSideNav.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _TvNavItem(
                    node: _nodes[i],
                    icon: TvSideNav.items[i].$1,
                    label: TvSideNav.items[i].$2,
                    active: i == widget.index,
                    autofocus: i == widget.index,
                    onTap: () => widget.onChanged(i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvNavItem extends StatefulWidget {
  final FocusNode node;
  final IconData icon;
  final String label;
  final bool active;
  final bool autofocus;
  final VoidCallback onTap;

  const _TvNavItem({
    required this.node,
    required this.icon,
    required this.label,
    required this.active,
    required this.autofocus,
    required this.onTap,
  });

  @override
  State<_TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<_TvNavItem> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.active || focused;

    return FocusableActionDetector(
      focusNode: widget.node,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(24),
        focusColor: Colors.transparent,
        hoverColor: Colors.white10,
        child: AnimatedScale(
          scale: focused ? 1.035 : 1,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              gradient: highlight ? const LinearGradient(colors: [Color(0xFF183455), Color(0xFF261B5B)]) : null,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(0.55) : Colors.white10),
                width: focused ? 2.4 : 1,
              ),
              boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 20)] : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: highlight ? Colors.white : AppTheme.textSoft, size: 30),
                const SizedBox(width: 16),
                Expanded(child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
