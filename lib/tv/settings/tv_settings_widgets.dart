part of 'tv_settings_screen.dart';

class _Header extends StatelessWidget {
  final double height;
  final bool showBackButton;
  final bool focused;
  final VoidCallback onTap;

  const _Header({
    required this.height,
    required this.showBackButton,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        focusColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 1.8 : 1),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14)],
          ),
          child: Row(
            children: [
              if (showBackButton) ...[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: focused ? AppTheme.surface3 : AppTheme.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.white10, width: focused ? 2 : 1),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
              ],
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.activeGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.settings_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('CONTROL CENTER', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2, decoration: TextDecoration.none)),
                    SizedBox(height: 8),
                    Text('Pengaturan LiveGo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                    SizedBox(height: 6),
                    Text('Rapikan mode tampilan, source, izin, dan cache dari satu tempat.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSoft, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, decoration: TextDecoration.none)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 7),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.1, decoration: TextDecoration.none)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String? description;
  final List<Widget> children;

  const _SettingsCard({required this.children, this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                child: Text(description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.35, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _DeterministicSettingRow extends StatelessWidget {
  final _SettingItem item;
  final bool focused;
  final double height;
  final VoidCallback onTap;

  const _DeterministicSettingRow({
    required this.item,
    required this.focused,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.danger ? AppTheme.danger : AppTheme.cyan;
    final isRadio = item.style == _SettingItemStyle.radio;
    return SizedBox(
      height: height,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        focusColor: Colors.transparent,
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: EdgeInsets.symmetric(horizontal: isRadio ? 12 : 13, vertical: isRadio ? 11 : 9),
                decoration: BoxDecoration(
                  color: focused ? AppTheme.surface3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: focused ? accent : Colors.transparent, width: 2),
                  boxShadow: null,
                ),
                child: isRadio ? _RadioContent(item: item, focused: focused) : _TileContent(item: item, focused: focused, accent: accent),
              ),
            ),
            const Divider(color: AppTheme.border, height: 1),
          ],
        ),
      ),
    );
  }
}

class _RadioContent extends StatelessWidget {
  final _SettingItem item;
  final bool focused;

  const _RadioContent({required this.item, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(item.active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: item.active || focused ? AppTheme.cyan : AppTheme.textSoft, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Text(item.title, style: TextStyle(color: item.active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 15.5, decoration: TextDecoration.none)),
        ),
        if (item.active) const Text('AKTIF', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11.5, decoration: TextDecoration.none)),
      ],
    );
  }
}

class _TileContent extends StatelessWidget {
  final _SettingItem item;
  final bool focused;
  final Color accent;

  const _TileContent({required this.item, required this.focused, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.surface3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: focused ? accent.withOpacity(0.85) : AppTheme.border),
          ),
          child: Icon(item.icon, color: item.danger ? accent : Colors.white, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: TextStyle(color: item.danger ? accent : Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(height: 5),
              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              if (item.showGridBar) ...[
                const SizedBox(height: 12),
                _TvGridStepper(value: LiveGoSettings.tvHomeGrid, focused: focused),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (item.switchValue != null)
          _SwitchPill(value: item.switchValue!, focused: focused)
        else if (item.showGridBar)
          Text('←  ${LiveGoSettings.tvHomeGrid}  →', style: TextStyle(color: focused ? accent : AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 12.5, decoration: TextDecoration.none))
        else
          Text(item.value, style: TextStyle(color: focused ? accent : (item.danger ? accent : AppTheme.cyan), fontWeight: FontWeight.w900, fontSize: 12.5, decoration: TextDecoration.none)),
        const SizedBox(width: 12),
        Icon(item.danger ? Icons.arrow_forward_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? accent : Colors.white38, size: 26),
      ],
    );
  }
}

class _SwitchPill extends StatelessWidget {
  final bool value;
  final bool focused;

  const _SwitchPill({required this.value, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppTheme.cyan.withOpacity(focused ? 0.95 : 0.78) : AppTheme.surface3,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? Colors.white70 : Colors.transparent),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}

class _TvGridStepper extends StatelessWidget {
  final int value;
  final bool focused;

  const _TvGridStepper({required this.value, required this.focused});

  @override
  Widget build(BuildContext context) {
    Widget box(String text, {bool active = false}) {
      return Container(
        width: active ? 56 : 36,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active || focused ? AppTheme.cyan.withOpacity(0.75) : Colors.white12),
        ),
        child: Text(text, style: TextStyle(color: active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 12, decoration: TextDecoration.none)),
      );
    }

    return Row(
      children: [
        box('-'),
        const SizedBox(width: 8),
        box('$value', active: true),
        const SizedBox(width: 8),
        box('+'),
        const SizedBox(width: 14),
        Expanded(child: _GridPreview(value: value)),
      ],
    );
  }
}

class _GridPreview extends StatelessWidget {
  final int value;
  const _GridPreview({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(10, (i) {
        final active = i < value;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i == 9 ? 0 : 4),
            decoration: BoxDecoration(
              color: active ? AppTheme.cyan : AppTheme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
