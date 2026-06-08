part of 'tv_source_manager_screen.dart';

class _SourceHeaderLite extends StatelessWidget {
  final bool focused;
  final int activeCount;
  final bool dirty;
  final double height;

  const _SourceHeaderLite({
    required this.focused,
    required this.activeCount,
    required this.dirty,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          color: focused ? null : AppTheme.surface.withOpacity(0.86),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.74), width: focused ? 2.1 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: focused ? AppTheme.cyan.withOpacity(0.18) : AppTheme.surface2.withOpacity(0.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: focused ? AppTheme.whiteGlow.withOpacity(0.42) : Colors.white10),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kelola Sumber Data',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dirty ? 'Ada perubahan. BACK untuk simpan atau batal.' : 'Pilih platform dan kategori untuk Beranda TV.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSoft.withOpacity(0.86), fontSize: 11.2, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface2.withOpacity(0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.cyan.withOpacity(0.28)),
              ),
              child: Text(
                '$activeCount AKTIF',
                style: const TextStyle(color: AppTheme.cyan, fontSize: 11.2, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceGroupHeaderLite extends StatelessWidget {
  final String text;
  final double height;

  const _SourceGroupHeaderLite({required this.text, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        width: double.infinity,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Text(
          text,
          style: const TextStyle(
            color: AppTheme.cyan,
            fontSize: 11.2,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _SourceRowLite extends StatelessWidget {
  final double height;
  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;
  final bool active;
  final bool recommended;
  final bool beta;
  final bool showCategories;
  final List<String> categories;
  final List<String> selectedCategories;
  final bool platformFocused;
  final bool categoryFocused;
  final int categoryIndex;
  final bool isLast;

  const _SourceRowLite({
    required this.height,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    required this.active,
    required this.recommended,
    required this.beta,
    required this.showCategories,
    required this.categories,
    required this.selectedCategories,
    required this.platformFocused,
    required this.categoryFocused,
    required this.categoryIndex,
    required this.isLast,
  });

  List<int> _visibleIndexes() {
    if (!showCategories || categories.isEmpty) return const <int>[];
    const maxVisible = 6;
    if (categories.length <= maxVisible) return List<int>.generate(categories.length, (i) => i);
    final safe = categoryIndex.clamp(0, categories.length - 1).toInt();
    final start = (safe - 2).clamp(0, categories.length - maxVisible).toInt();
    return List<int>.generate(maxVisible, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexes();
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Expanded(
                    flex: 50,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                      decoration: _decoration(platformFocused),
                      child: Row(
                        children: [
                          _StatusLampLite(color: statusColor, text: statusText),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                          fontSize: 15.8,
                                          fontWeight: FontWeight.w900,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                    if (recommended) const _SmallBadgeLite(text: 'REKOMENDASI', color: Colors.greenAccent),
                                    if (beta) const _SmallBadgeLite(text: 'BETA', color: Colors.orangeAccent),
                                    if (platformFocused) const _SmallBadgeLite(text: 'FOKUS', color: Colors.white),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  active ? subtitle : 'OFF. Tekan OK untuk aktifkan.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: active ? AppTheme.textSoft.withOpacity(0.82) : Colors.white38,
                                    fontSize: 10.8,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _SwitchPillLite(active: active, focused: platformFocused),
                        ],
                      ),
                    ),
                  ),
                  if (showCategories) ...[
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 38,
                      child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
                      decoration: _decoration(categoryFocused),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 84,
                            child: Row(
                              children: [
                                Icon(Icons.category_rounded, color: active ? AppTheme.cyan.withOpacity(0.70) : Colors.white24, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  active ? 'Kategori' : 'OFF',
                                  style: TextStyle(
                                    color: active ? AppTheme.textSoft.withOpacity(0.82) : Colors.white38,
                                    fontSize: 10.0,
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
                                  if (j != visible.length - 1) const SizedBox(width: 6),
                                ],
                              ],
                            ),
                          ),
                          if (categoryFocused) ...[
                            const SizedBox(width: 8),
                            const _SmallBadgeLite(text: 'FOKUS', color: Colors.white),
                          ],
                        ],
                      ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isLast) Divider(color: AppTheme.borderSoft.withOpacity(0.70), height: 1),
        ],
      ),
    );
  }

  BoxDecoration _decoration(bool focused) {
    return BoxDecoration(
      color: focused
          ? AppTheme.surface2.withOpacity(0.96)
          : (active ? AppTheme.surface.withOpacity(0.82) : AppTheme.bgDeep.withOpacity(0.78)),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: focused ? AppTheme.whiteGlow : (active ? AppTheme.borderSoft.withOpacity(0.74) : Colors.white.withOpacity(0.06)),
        width: focused ? 2.1 : 1,
      ),
      boxShadow: focused
          ? [
              BoxShadow(color: Colors.white.withOpacity(0.10), blurRadius: 14),
              BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 18),
            ]
          : null,
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
      width: 64,
      child: Row(
        children: [
          Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 9.6, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
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
      width: 74,
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: active ? Colors.greenAccent.withOpacity(0.20) : Colors.white.withOpacity(0.050),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? AppTheme.whiteGlow : (active ? Colors.greenAccent.withOpacity(0.42) : Colors.white12), width: focused ? 1.7 : 1),
      ),
      child: Stack(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: active ? Colors.white : Colors.white38, shape: BoxShape.circle),
          ),
          Center(
            child: Text(
              active ? 'ON' : 'OFF',
              style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 10.0, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
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
    final color = focused ? AppTheme.whiteGlow : (selected ? Colors.greenAccent.withOpacity(0.50) : Colors.white12);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? Colors.greenAccent.withOpacity(0.16) : (disabled ? Colors.white.withOpacity(0.020) : Colors.white.withOpacity(0.048)),
        border: Border.all(color: color, width: focused ? 1.7 : 1),
        boxShadow: focused ? [BoxShadow(color: Colors.white.withOpacity(0.09), blurRadius: 10)] : null,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: disabled ? Colors.white30 : (focused ? Colors.white : (selected ? Colors.greenAccent : Colors.white54)),
          fontSize: 10.6,
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
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.23)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8.6, fontWeight: FontWeight.w900, letterSpacing: 0.2, decoration: TextDecoration.none),
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
      color: Colors.black.withOpacity(0.68),
      alignment: Alignment.center,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.26), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simpan perubahan?',
              style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 7),
            const Text(
              'Batal membuang perubahan. Simpan menerapkan ke Beranda TV.',
              style: TextStyle(color: AppTheme.textSoft, fontSize: 12.2, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButtonLite(text: 'Batal', focused: cursor == 0),
                const SizedBox(width: 12),
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
      height: 44,
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(focused ? 0.075 : 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused ? AppTheme.whiteGlow : (filled ? Colors.white.withOpacity(0.16) : Colors.white12),
          width: focused ? 1.7 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(color: filled || focused ? Colors.white : Colors.white70, fontSize: 12.8, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
      ),
    );
  }
}

class _SourceEmptyLite extends StatelessWidget {
  const _SourceEmptyLite();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.74)),
      ),
      child: const Text(
        'Source belum tersedia',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
      ),
    );
  }
}
