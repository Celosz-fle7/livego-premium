import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../shared/widgets/glow_container.dart';

class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
      child: Text(text.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 12)),
    );
  }

  Widget _mode(String title, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: AppTheme.cyan, size: 24),
            const SizedBox(width: 18),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, {Widget? trailing, VoidCallback? onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF142338),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2B4058)),
              ),
              child: Icon(icon, color: iconColor ?? Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.25)),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.arrow_forward_rounded, color: AppTheme.textSoft),
          ],
        ),
      ),
    );
  }

  Future<void> _showDrmDialog() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Mode Widevine DRM'),
        children: [
          for (final item in ['Auto', 'Paksa L3', 'Nonaktifkan Paksa L3'])
            RadioListTile<String>(
              value: item,
              groupValue: LiveGoSettings.drmMode,
              activeColor: Colors.teal,
              title: Text(item),
              onChanged: (v) => Navigator.pop(context, v),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ),
        ],
      ),
    );
    if (value != null) setState(() => LiveGoSettings.drmMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
      children: [
        GlowContainer(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFF0D1828), borderRadius: BorderRadius.circular(999)),
                    child: const Text('CONTROL CENTER', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Pengaturan LiveGo', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Rapikan mode tampilan, player, source, izin, dan cache dari satu tempat.', style: TextStyle(color: AppTheme.textSoft, height: 1.4)),
              const SizedBox(height: 14),
              Row(
                children: const [
                  _SmallPill('Display'),
                  SizedBox(width: 8),
                  _SmallPill('Player'),
                  SizedBox(width: 8),
                  _SmallPill('Source'),
                ],
              )
            ],
          ),
        ),
        _section('Tampilan & Navigasi'),
        GlowContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text('Pilih antarmuka yang paling cocok. Mode Auto mengikuti perangkat saat aplikasi dibuka.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.35)),
              ),
              _mode('Otomatis (Ikuti Hardware)', LiveGoSettings.layoutMode == 'Auto', () => setState(() => LiveGoSettings.layoutMode = 'Auto')),
              _mode('Smartphone / Tablet (Android)', LiveGoSettings.layoutMode == 'Mobile', () => setState(() => LiveGoSettings.layoutMode = 'Mobile')),
              _mode('Android TV (Leanback Style)', LiveGoSettings.layoutMode == 'TV', () => setState(() => LiveGoSettings.layoutMode = 'TV')),
            ],
          ),
        ),
        _section('Player'),
        GlowContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _tile(Icons.image_rounded, 'Tampilkan Background Poster', 'Poster menjadi ambience di halaman detail dan player.', trailing: Switch(value: LiveGoSettings.backgroundPoster, activeColor: AppTheme.cyan, onChanged: (v) => setState(() => LiveGoSettings.backgroundPoster = v))),
              const Divider(color: Color(0xFF24344A), height: 1),
              _tile(Icons.sync_rounded, 'Gunakan Cache Playback', 'Simpan potongan stream sementara agar perpindahan lebih stabil.', trailing: Switch(value: LiveGoSettings.cachePlayback, activeColor: AppTheme.cyan, onChanged: (v) => setState(() => LiveGoSettings.cachePlayback = v))),
              const Divider(color: Color(0xFF24344A), height: 1),
              _tile(Icons.screen_rotation_rounded, 'Tampilkan Tombol Rotasi Manual', 'Tampilkan kontrol rotasi manual saat menonton.', trailing: Switch(value: LiveGoSettings.manualRotateButton, activeColor: AppTheme.cyan, onChanged: (v) => setState(() => LiveGoSettings.manualRotateButton = v))),
              const Divider(color: Color(0xFF24344A), height: 1),
              _tile(Icons.lock_rounded, 'Kompatibilitas Widevine DRM', 'Mode saat ini: ${LiveGoSettings.drmMode}', trailing: const Text('ATUR', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900)), onTap: _showDrmDialog),
            ],
          ),
        ),
        _section('Tampilan Home'),
        GlowContainer(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, box) {
              final isTvLike = MediaQuery.sizeOf(context).shortestSide >= 540 && MediaQuery.sizeOf(context).width >= 960;
              final value = isTvLike ? LiveGoSettings.tvHomeGrid : LiveGoSettings.mobileHomeGrid;
              final max = isTvLike ? 10 : 6;
              final min = isTvLike ? 4 : 2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jumlah Grid Home', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Geser titik untuk mengatur jumlah poster. Perangkat ini dibatasi sampai $max grid.', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 18),
                  _GridSlider(
                    label: 'Grid',
                    value: value,
                    min: min,
                    max: max,
                    onChanged: (v) => setState(() {
                      if (isTvLike) {
                        LiveGoSettings.setTvHomeGrid(v);
                      } else {
                        LiveGoSettings.setMobileHomeGrid(v);
                      }
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        _section('Sumber & Izin'),
        GlowContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _tile(Icons.layers_rounded, 'Kelola Sumber Data', 'Pilih 6 platform Home, kategori, dan cek status server.', onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceManagerScreen()));
                setState(() {});
              }),
              const Divider(color: Color(0xFF24344A), height: 1),
              _tile(Icons.info_rounded, 'Kelola Notifikasi Unduhan', 'Belum aktif. Aktifkan lagi agar progress unduhan mudah dipantau.', trailing: const Text('AKTIFKAN', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
        _section('Perawatan'),
        GlowContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _tile(Icons.delete_rounded, 'Hapus Semua Cache', 'Bersihkan cache streaming dan gambar agar ruang penyimpanan lega.', iconColor: Colors.redAccent, trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.redAccent), onTap: () => setState(LiveGoSettings.reset)),
        ),
      ],
    );
  }
}

class SourceManagerScreen extends StatefulWidget {
  const SourceManagerScreen({super.key});

  @override
  State<SourceManagerScreen> createState() => _SourceManagerScreenState();
}

class _SourceManagerScreenState extends State<SourceManagerScreen> {
  late Set<String> _active;
  late List<String> _home;
  late Map<String, String> _languageDrafts;
  late Map<String, List<String>> _categoryDrafts;

  String _selectedPlatform = LiveGoSettings.defaultPlatform;
  List<String> _availableCategories = const ['Trending', 'For You'];
  bool _loadingCategories = false;
  bool _pinging = false;

  @override
  void initState() {
    super.initState();
    _active = Set<String>.from(LiveGoSettings.activePlatforms);
    _home = List<String>.from(LiveGoSettings.homePlatforms);
    _languageDrafts = {
      for (final slug in LiveGoCatalog.allPlatforms)
        slug: LiveGoSettings.languageForPlatform(slug),
    };
    _categoryDrafts = {
      for (final slug in LiveGoCatalog.allPlatforms)
        slug: LiveGoSettings.categoriesFor(slug),
    };
    _selectedPlatform = _home.isNotEmpty ? _home.first : LiveGoSettings.defaultPlatform;
    _loadCategories(_selectedPlatform);
    _pingVisibleOnce();
  }

  Future<void> _loadCategories(String platform) async {
    setState(() {
      _selectedPlatform = platform;
      _loadingCategories = true;
    });
    final rows = await LiveGoCatalog.fetchCategoriesFor(platform);
    if (!mounted) return;
    setState(() {
      _availableCategories = rows;
      _categoryDrafts.putIfAbsent(platform, () => LiveGoSettings.categoriesFor(platform));
      _loadingCategories = false;
    });
  }

  Future<void> _pingVisibleOnce() async {
    setState(() => _pinging = true);
    final platforms = LiveGoCatalog.allPlatforms;
    await Future.wait(platforms.map((p) => LiveGoCatalog.pingPlatform(p).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            LiveGoSettings.setPlatformStatus(p, 'offline');
            return 'offline';
          },
        )));
    if (!mounted) return;
    setState(() => _pinging = false);
  }

  void _toggleActive(String slug) {
    setState(() {
      if (_active.contains(slug)) {
        if (_active.length > 1) _active.remove(slug);
        _home.remove(slug);
      } else {
        _active.add(slug);
        if (_home.length < 6) _home.add(slug);
      }
      if (_home.isEmpty) _home.add(_active.first);
    });
  }

  void _toggleHome(String slug) {
    setState(() {
      if (_home.contains(slug)) {
        if (_home.length > 1) _home.remove(slug);
      } else if (_home.length < 6) {
        _home.add(slug);
        _active.add(slug);
      }
    });
  }

  void _setLanguage(String slug, String lang) {
    setState(() => _languageDrafts[slug] = lang);
  }

  void _toggleCategory(String slug, String name) {
    final current = List<String>.from(_categoryDrafts[slug] ?? LiveGoSettings.categoriesFor(slug));
    setState(() {
      if (current.contains(name)) {
        if (current.length > 1) current.remove(name);
      } else if (current.length < 6) {
        current.add(name);
      }
      _categoryDrafts[slug] = current;
    });
  }

  void _save() {
    LiveGoSettings.activePlatforms
      ..clear()
      ..addAll(_active);
    LiveGoSettings.homePlatforms
      ..clear()
      ..addAll(_home.take(6));
    if (LiveGoSettings.homePlatforms.isEmpty) {
      LiveGoSettings.homePlatforms.add(_active.first);
    }
    LiveGoSettings.defaultPlatform = LiveGoSettings.homePlatforms.first;

    for (final entry in _languageDrafts.entries) {
      LiveGoSettings.setLanguageForPlatform(entry.key, entry.value);
    }
    for (final entry in _categoryDrafts.entries) {
      LiveGoSettings.setCategoriesFor(entry.key, entry.value);
    }
    Navigator.pop(context);
  }

  Color _statusColor(String slug) {
    switch (LiveGoSettings.statusFor(slug)) {
      case 'online':
        return Colors.greenAccent;
      case 'slow':
        return Colors.orangeAccent;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final platforms = LiveGoCatalog.allPlatforms;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  const Expanded(child: Text('Kelola Sumber Data', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                  TextButton.icon(onPressed: _pinging ? null : _pingVisibleOnce, icon: const Icon(Icons.network_ping_rounded), label: Text(_pinging ? 'PING...' : 'PING')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                children: [
                  const Text('Atur platform, bahasa, dan kategori Home HP. Perubahan aktif setelah tombol Simpan ditekan.', style: TextStyle(color: AppTheme.textSoft, height: 1.35)),
                  const SizedBox(height: 14),
                  for (final slug in platforms) ...[
                    _SourceCard(
                      title: LiveGoCatalog.label(slug),
                      subtitle: _sourceDescription(slug),
                      active: _active.contains(slug),
                      home: _home.contains(slug),
                      selected: _selectedPlatform == slug,
                      statusColor: _statusColor(slug),
                      language: (_languageDrafts[slug] ?? LiveGoSettings.languageForPlatform(slug)).toUpperCase(),
                      categoryCount: (_categoryDrafts[slug] ?? LiveGoSettings.categoriesFor(slug)).length,
                      onTap: () {
                        if (_selectedPlatform == slug) {
                          setState(() => _selectedPlatform = '');
                        } else {
                          _loadCategories(slug);
                        }
                      },
                      onToggleActive: () => _toggleActive(slug),
                      onToggleHome: () => _toggleHome(slug),
                    ),
                    if (_selectedPlatform == slug)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlowContainer(
                          padding: const EdgeInsets.all(14),
                          child: _loadingCategories
                              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                              : _SourcePlatformEditor(
                                  slug: slug,
                                  languages: LiveGoCatalog.languagesFor(slug),
                                  selectedLanguage: _languageDrafts[slug] ?? LiveGoSettings.languageForPlatform(slug),
                                  availableCategories: _availableCategories,
                                  selectedCategories: _categoryDrafts[slug] ?? LiveGoSettings.categoriesFor(slug),
                                  onLanguage: (v) => _setLanguage(slug, v),
                                  onCategory: (v) => _toggleCategory(slug, v),
                                ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: const BoxDecoration(color: Color(0xF0050913), border: Border(top: BorderSide(color: Color(0xFF24344A)))),
        child: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _save, child: const Text('Simpan'))),
          ],
        ),
      ),
    );
  }

  String _sourceDescription(String slug) {
    final map = <String, String>{
      'shortmax': 'MP4 multi-quality. Bahasa ID/EN.',
      'netshort': 'Direct CDN + subtitle VTT. Bahasa default IN.',
      'pinedrama': 'Direct MP4. Kategori genre dari API.',
      'dramabox': 'HLS signed + subtitle. Ada Latest, VIP, Dub Indo.',
      'flickreels': 'HLS signed. Banyak bahasa termasuk ID.',
      'melolo': 'Catalog jalan. Video CENC belum dipasang native.',
    };
    return map[slug] ?? 'Source LiveGo siap dikoneksikan ke API.';
  }
}

class _SourceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool home;
  final bool selected;
  final Color statusColor;
  final String language;
  final int categoryCount;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleHome;

  const _SourceCard({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.home,
    required this.selected,
    required this.statusColor,
    required this.language,
    required this.categoryCount,
    required this.onTap,
    required this.onToggleActive,
    required this.onToggleHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF06272C) : const Color(0xFF071B1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppTheme.cyan.withOpacity(.7) : AppTheme.cyan.withOpacity(.28)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(width: 11, height: 11, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: statusColor.withOpacity(.45), blurRadius: 12)])),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
                      Text(language, style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12)),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onToggleHome,
                        child: Text(home ? 'Tampil di Home' : 'Tambahkan ke Home', style: TextStyle(color: home ? AppTheme.cyan : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                      Text('• $categoryCount kategori', style: const TextStyle(color: AppTheme.textSoft, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ]),
              ),
              Switch(value: active, onChanged: (_) => onToggleActive(), activeColor: AppTheme.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourcePlatformEditor extends StatelessWidget {
  final String slug;
  final List<String> languages;
  final String selectedLanguage;
  final List<String> availableCategories;
  final List<String> selectedCategories;
  final ValueChanged<String> onLanguage;
  final ValueChanged<String> onCategory;

  const _SourcePlatformEditor({
    required this.slug,
    required this.languages,
    required this.selectedLanguage,
    required this.availableCategories,
    required this.selectedCategories,
    required this.onLanguage,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bahasa ${LiveGoCatalog.label(slug)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final lang in languages)
              _ChoiceButton(text: lang.toUpperCase(), active: selectedLanguage == lang, onTap: () => onLanguage(lang)),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF24344A), height: 1),
        const SizedBox(height: 14),
        Text('Kategori Home ${LiveGoCatalog.label(slug)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Kategori aktif saja yang dipanggil dan tampil di Home HP.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12, height: 1.35)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final c in availableCategories)
              _ChoiceButton(text: c, active: selectedCategories.contains(c), onTap: () => onCategory(c)),
          ],
        ),
      ],
    );
  }
}

class _GridSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _GridSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('$value', style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppTheme.cyan,
            inactiveTrackColor: const Color(0xFF24344A),
            thumbColor: Colors.white,
            overlayColor: AppTheme.cyan.withOpacity(.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _ChoiceButton({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
          color: active ? null : const Color(0xFF172131),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.transparent : const Color(0xFF31445F)),
        ),
        child: Text(text, style: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  const _SmallPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF111B2A), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white10)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}
