import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/search_filter.dart';
import '../../shared/widgets/poster_card.dart';
import '../mobile_player_entry.dart';

class MobileSearchScreen extends StatefulWidget {
  const MobileSearchScreen({super.key});

  @override
  State<MobileSearchScreen> createState() => _MobileSearchScreenState();
}

class _MobileSearchScreenState extends State<MobileSearchScreen> {
  final _controller = TextEditingController();
  String query = '';
  int platform = -1;
  bool loading = false;
  List<ContentItem> results = [];

  /// Filter milik provider yang dipilih (null = Semua Source = tanpa filter).
  /// Kosong = "Semua" (tanpa filter). Filter BUKAN untuk mencari —
  /// genre memfilter hasil yang sudah ada.
  final Set<String> _selectedGenres = {};

  /// Slug provider yang dipilih, null kalau "Semua Source".
  String? get _selectedSlug =>
      platform < 0 ? null : LiveGoCatalog.platforms[platform];

  /// Hasil yang tampil = results difilter milik provider yang dipilih.
  List<ContentItem> get _displayed =>
      SearchFilter.filter(_selectedSlug, results, _selectedGenres);

  void _toggleGenre(String label) {
    setState(() {
      if (!_selectedGenres.remove(label)) _selectedGenres.add(label);
    });
  }

  void _selectPlatform(int next) {
    setState(() {
      platform = next;
      // Label filter ganti per provider -> seleksi lama tidak berlaku.
      _selectedGenres.clear();
    });
    if (query.isNotEmpty) _search(query);
  }

  Future<void> _search(String value) async {
    query = value.trim();
    if (query.isEmpty) {
      setState(() => results = []);
      return;
    }
    setState(() => loading = true);
    final items = platform < 0
        ? await LiveGoCatalog.searchAll(query)
        : await LiveGoCatalog.search(query, platform: LiveGoCatalog.platforms[platform]);
    if (!mounted) return;
    setState(() {
      results = items;
      loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        const Text('Pencarian', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Cari semua sumber aktif atau pilih platform tertentu.', style: TextStyle(color: AppTheme.textSoft)),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Cari drama, CEO, cinta, balas dendam...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
          ),
          onSubmitted: _search,
          onChanged: (v) {
            query = v;
            if (v.trim().isEmpty) _search(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: platform < 0,
                  label: const Text('Semua Source'),
                  onSelected: (_) => _selectPlatform(-1),
                ),
              ),
              ...List.generate(LiveGoCatalog.platformLabels.length, (i) {
                final selected = platform == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(LiveGoCatalog.platformLabels[i]),
                    onSelected: (_) => _selectPlatform(i),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Filter milik provider yang dipilih (FreeReels / MovieBox).
        // Provider lain & Semua Source tidak punya filter -> row disembunyikan.
        // Memfilter hasil, BUKAN mencari. "Semua" = tanpa filter.
        // Tap = pilih manual (multi-select).
        if (SearchFilter.labelsFor(_selectedSlug).isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Filter', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Semua', style: TextStyle(fontSize: 12)),
                selected: _selectedGenres.isEmpty,
                onSelected: (_) => setState(() => _selectedGenres.clear()),
              ),
              ...SearchFilter.labelsFor(_selectedSlug).map((label) {
                final selected = _selectedGenres.contains(label);
                return FilterChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => _toggleGenre(label),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 70),
            child: Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
          )
        else if (_displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.travel_explore_rounded, color: Colors.white.withOpacity(0.25), size: 70),
                  const SizedBox(height: 14),
                  const Text('Cari dari source aktif LiveGo', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _displayed.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 265,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            itemBuilder: (_, i) {
              final item = _displayed[i];
              return PosterCard(
                item: item,
                onTap: () => MobilePlayerEntry.open(context, item: item),
              );
            },
          ),
      ],
    );
  }
}
