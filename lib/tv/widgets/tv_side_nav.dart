import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';

class TvSideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final bool expanded;

  const TvSideNav({super.key, required this.index, required this.onChanged, this.expanded = false});

  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.download_rounded, 'Unduhan'),
    (Icons.history_rounded, 'Riwayat'),
    (Icons.favorite_border_rounded, 'Favorit'),
    (Icons.person_rounded, 'Akun'),
    (Icons.search_rounded, 'Cari'),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: 118,
        margin: const EdgeInsets.fromLTRB(24, 24, 16, 24),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220).withOpacity(0.92),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFF203149)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
        ),
        child: FocusTraversalGroup(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFF111B2B),
                  border: Border.all(color: const Color(0xFF263A55)),
                ),
                child: Container(
                  margin: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _TvNavIcon(
                    icon: items[i].$1,
                    label: items[i].$2,
                    active: i == index,
                    autofocus: i == index,
                    onTap: () => onChanged(i),
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

class _TvNavIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool autofocus;
  final VoidCallback onTap;

  const _TvNavIcon({required this.icon, required this.label, required this.active, required this.autofocus, required this.onTap});

  @override
  State<_TvNavIcon> createState() => _TvNavIconState();
}

class _TvNavIconState extends State<_TvNavIcon> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active || focused;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<Intent>(onInvoke: (_) { widget.onTap(); return null; }),
      },
      onShowFocusHighlight: (v) => setState(() => focused = v),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 450),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(28),
          focusColor: Colors.transparent,
          hoverColor: Colors.white10,
          child: AnimatedScale(
            scale: focused ? 1.08 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 74,
              decoration: BoxDecoration(
                gradient: widget.active ? const LinearGradient(colors: [Color(0xFF123D5B), Color(0xFF41248E)]) : null,
                color: widget.active ? null : const Color(0xFF111A29).withOpacity(0.72),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? AppTheme.cyan.withOpacity(.45) : Colors.white10), width: focused ? 2.2 : 1),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(.38), blurRadius: 22)] : null,
              ),
              child: Icon(widget.icon, color: active ? Colors.white : AppTheme.textSoft, size: 33),
            ),
          ),
        ),
      ),
    );
  }
}
