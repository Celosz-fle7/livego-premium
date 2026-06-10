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
        borderRadius: BorderRadius.circular(18),
        focusColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: focused
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppTheme.surface3.withOpacity(0.98),
                      AppTheme.surface2.withOpacity(0.88),
                    ],
                  )
                : null,
            color: focused ? null : AppTheme.surface.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.74), width: focused ? 2.1 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.09), blurRadius: 16)] : const [BoxShadow(color: Colors.black38, blurRadius: 12)],
          ),
          child: Row(
            children: [
              if (showBackButton) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: focused ? AppTheme.surface3 : AppTheme.surface2.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: focused ? AppTheme.whiteGlow.withOpacity(0.42) : Colors.white10, width: focused ? 2 : 1),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.activeGradient,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.settings_rounded, color: Colors.white, size: 29),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('CONTROL CENTER', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 10.2, letterSpacing: 1.1, decoration: TextDecoration.none)),
                    SizedBox(height: 5),
                    Text('Pengaturan LiveGo', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                    SizedBox(height: 4),
                    Text('Mode TV, source, izin, dan cache dari satu tempat.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSoft, fontSize: 11, height: 1.25, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface3.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.62)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10.8, decoration: TextDecoration.none)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 5),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white60, fontSize: 11.8, fontWeight: FontWeight.w900, letterSpacing: 1.0, decoration: TextDecoration.none)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            SizedBox(
              height: 42,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 3),
                child: Text(description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.4, height: 1.25, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
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
        borderRadius: BorderRadius.circular(14),
        focusColor: Colors.transparent,
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: EdgeInsets.symmetric(horizontal: isRadio ? 11 : 12, vertical: isRadio ? 9 : 8),
                decoration: BoxDecoration(
                  color: focused ? AppTheme.surface3.withOpacity(0.96) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: focused ? AppTheme.whiteGlow : Colors.transparent, width: focused ? 2.1 : 1),
                  boxShadow: null,
                ),
                child: isRadio ? _RadioContent(item: item, focused: focused) : _TileContent(item: item, focused: focused, accent: accent),
              ),
            ),
            Divider(color: AppTheme.borderSoft.withOpacity(0.58), height: 1),
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
        Icon(item.active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: item.active || focused ? AppTheme.cyan : AppTheme.textSoft, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(item.title, style: TextStyle(color: item.active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 14.4, decoration: TextDecoration.none)),
        ),
        if (item.active) const Text('AKTIF', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 10.8, decoration: TextDecoration.none)),
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.surface3.withOpacity(0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: focused ? AppTheme.whiteGlow.withOpacity(0.44) : AppTheme.borderSoft.withOpacity(0.70)),
          ),
          child: Icon(item.icon, color: item.danger ? accent : Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: TextStyle(color: item.danger ? accent : Colors.white, fontSize: 14.8, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(height: 4),
              Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 10.8, height: 1.20, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              if (item.showGridBar) ...[
                const SizedBox(height: 9),
                _TvGridStepper(value: LiveGoSettings.tvHomeGrid, focused: focused),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        if (item.switchValue != null)
          _SwitchPill(value: item.switchValue!, focused: focused)
        else if (item.showGridBar)
          Text('←  ${LiveGoSettings.tvHomeGrid}  →', style: TextStyle(color: focused ? accent : AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 11.6, decoration: TextDecoration.none))
        else
          Text(item.value, style: TextStyle(color: focused ? accent : (item.danger ? accent : AppTheme.cyan), fontWeight: FontWeight.w900, fontSize: 11.6, decoration: TextDecoration.none)),
        const SizedBox(width: 10),
        Icon(item.danger ? Icons.arrow_forward_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? accent : Colors.white38, size: 24),
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
      width: 54,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppTheme.cyan.withOpacity(focused ? 0.95 : 0.78) : AppTheme.surface3.withOpacity(0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? AppTheme.whiteGlow.withOpacity(0.70) : Colors.transparent),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
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
        width: active ? 52 : 34,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active || focused ? AppTheme.whiteGlow.withOpacity(0.64) : Colors.white12),
        ),
        child: Text(text, style: TextStyle(color: active || focused ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 11.4, decoration: TextDecoration.none)),
      );
    }

    return Row(
      children: [
        box('-'),
        const SizedBox(width: 7),
        box('$value', active: true),
        const SizedBox(width: 7),
        box('+'),
        const SizedBox(width: 12),
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
            height: 5,
            margin: EdgeInsets.only(right: i == 9 ? 0 : 4),
            decoration: BoxDecoration(
              color: active ? AppTheme.cyan : AppTheme.borderSoft.withOpacity(0.72),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _CacheMaintenanceDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool loading;

  const _CacheMaintenanceDialog({
    required this.title,
    required this.message,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.cyan),
              )
            else
              const Icon(Icons.check_circle_rounded, color: AppTheme.cyan, size: 34),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                  const SizedBox(height: 6),
                  Text(message, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
