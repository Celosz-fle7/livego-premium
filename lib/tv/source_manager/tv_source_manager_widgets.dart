part of 'tv_source_manager_screen.dart';

class _SourceHeaderLite extends StatelessWidget {
  final bool focused;
  final int activeCount;
  final bool dirty;

  const _SourceHeaderLite({
    required this.focused,
    required this.activeCount,
    required this.dirty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 1.8 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focused ? AppTheme.cyan.withOpacity(0.18) : AppTheme.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kelola Sumber Data',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 3),
                Text(
                  dirty ? 'Ada perubahan. BACK untuk simpan atau batal.' : 'Ringan: pilih platform dan kategori untuk Beranda TV.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.26)),
            ),
            child: Text(
              '$activeCount/6 AKTIF',
              style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceGroupHeaderLite extends StatelessWidget {
  final String text;

  const _SourceGroupHeaderLite({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _SourceRowLite extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;
  final bool active;
  final bool recommended;
  final bool beta;
  final List<String> categories;
  final List<String> selectedCategories;
  final bool platformFocused;
  final bool categoryFocused;
  final int categoryIndex;
  final bool isLast;

  const _SourceRowLite({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    required this.active,
    required this.recommended,
    required this.beta,
    required this.categories,
    required this.selectedCategories,
    required this.platformFocused,
    required this.categoryFocused,
    required this.categoryIndex,
    required this.isLast,
  });

  List<int> _visibleIndexes() {
    if (categories.isEmpty) return const <int>[];
    const maxVisible = 6;
    if (categories.length <= maxVisible) return List<int>.generate(categories.length, (i) => i);
    final safe = categoryIndex.clamp(0, categories.length - 1).toInt();
    final start = (safe - 2).clamp(0, categories.length - maxVisible).toInt();
    return List<int>.generate(maxVisible, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexes();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: _decoration(platformFocused),
                child: Row(
                  children: [
                    _StatusLampLite(color: statusColor, text: statusText),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active ? Colors.white : Colors.white54,
                                    fontSize: 17.2,
                                    fontWeight: FontWeight.w900,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              if (recommended) const _SmallBadgeLite(text: 'REKOMENDASI', color: Colors.greenAccent),
                              if (beta) const _SmallBadgeLite(text: 'BETA', color: Colors.orangeAccent),
                              if (platformFocused) const _SmallBadgeLite(text: 'OK ON/OFF', color: AppTheme.cyan),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            active ? subtitle : 'OFF. Tekan OK untuk aktifkan.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active ? AppTheme.textSoft : Colors.white38,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SwitchPillLite(active: active, focused: platformFocused),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                decoration: _decoration(categoryFocused),
                child: Row(
                  children: [
                    SizedBox(
                      width: 94,
                      child: Row(
                        children: [
                          Icon(Icons.category_rounded, color: active ? AppTheme.cyan.withOpacity(0.70) : Colors.white24, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            active ? 'Kategori' : 'OFF',
                            style: TextStyle(
                              color: active ? AppTheme.textSoft : Colors.white38,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          for (var j = 0; j < visible.length; j++) ...[
                            Expanded(
                              child: _CategoryChipLite(
                                text: categories[visible[j]],
                                selected: active && selectedCategories.contains(categories[visible[j]]),
                                focused: active && categoryFocused && visible[j] == categoryIndex,
                                disabled: !active,
                              ),
                            ),
                            if (j != visible.length - 1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    if (categoryFocused) ...[
                      const SizedBox(width: 10),
                      const _SmallBadgeLite(text: 'OK PILIH', color: AppTheme.cyan),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: AppTheme.borderSoft, height: 1),
      ],
    );
  }

  BoxDecoration _decoration(bool focused) {
    return BoxDecoration(
      color: active ? AppTheme.surface.withOpacity(0.92) : AppTheme.bgDeep.withOpacity(0.82),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: focused ? AppTheme.cyan : (active ? AppTheme.border : Colors.white.withOpacity(0.06)),
        width: focused ? 1.8 : 1,
      ),
    );
  }
}

class _StatusLampLite extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusLampLite({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Row(
        children: [
          Container(width: 13, height: 13, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchPillLite extends StatelessWidget {
  final bool active;
  final bool focused;

  const _SwitchPillLite({required this.active, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? AppTheme.cyan : (active ? Colors.white.withOpacity(0.20) : Colors.white12), width: focused ? 1.7 : 1),
      ),
      child: Stack(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: active ? Colors.white : Colors.white38, shape: BoxShape.circle),
          ),
          Center(
            child: Text(
              active ? 'ON' : 'OFF',
              style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChipLite extends StatelessWidget {
  final String text;
  final bool selected;
  final bool focused;
  final bool disabled;

  const _CategoryChipLite({
    required this.text,
    required this.selected,
    required this.focused,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final color = focused ? AppTheme.cyan : (selected ? Colors.white.withOpacity(0.14) : Colors.white12);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? AppTheme.cyan.withOpacity(0.22) : (disabled ? Colors.white.withOpacity(0.025) : Colors.white.withOpacity(0.052)),
        border: Border.all(color: color, width: focused ? 1.7 : 1),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: disabled ? Colors.white30 : (selected || focused ? Colors.white : Colors.white54),
          fontSize: 11.4,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _SmallBadgeLite extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallBadgeLite({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9.2, fontWeight: FontWeight.w900, letterSpacing: 0.3, decoration: TextDecoration.none),
      ),
    );
  }
}

class _SourceConfirmLite extends StatelessWidget {
  final int cursor;

  const _SourceConfirmLite({required this.cursor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.66),
      alignment: Alignment.center,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.28), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simpan perubahan?',
              style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 8),
            const Text(
              'Batal & Keluar akan membuang perubahan. Simpan akan menerapkan ke Beranda TV.',
              style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButtonLite(text: 'Batal & Keluar', focused: cursor == 0),
                const SizedBox(width: 14),
                _DialogButtonLite(text: 'Simpan', focused: cursor == 1, filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButtonLite extends StatelessWidget {
  final String text;
  final bool focused;
  final bool filled;

  const _DialogButtonLite({
    required this.text,
    required this.focused,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(focused ? 0.075 : 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused ? AppTheme.cyan : (filled ? Colors.white.withOpacity(0.16) : Colors.white12),
          width: focused ? 1.7 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(color: filled || focused ? Colors.white : Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
      ),
    );
  }
}

class _SourceEmptyLite extends StatelessWidget {
  const _SourceEmptyLite();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text(
        'Source belum tersedia',
        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
      ),
    );
  }
}
